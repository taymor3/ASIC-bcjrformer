const fs=require('fs'),assert=require('assert');
const {CycleSimulator,signed}=require('./cycle_simulator.cjs');
const shape=process.argv[2]||'multi',fixture=JSON.parse(fs.readFileSync(`rtl/tests/core-${shape}-reference.json`));
const sim=new CycleSimulator(`rtl/tests/core-${shape}-netlist.json`);
const start=Date.now();let commits=0,frame=null,eventIndex=0,outputIndex=0,preciseGeluWrites=0;
const ready=()=>({param_rsp_ready:sim.cycles%5!==0,logit_ready:sim.cycles%4!==0,completion_ready:sim.cycles%3!==0});
const get=n=>Number(sim.get(n));
let held={};
function step(inputs={}){
  sim.set({...ready(),...inputs});sim.evaluate();
  for(const [name,valid,accept,payload] of [
    ['output','logit_valid','logit_ready',['logit_data','logit_index','logit_last']],
    ['completion','completion_valid','completion_ready',['completion_code','completion_position','completion_error','status']],
    ['parameter','param_rsp_valid','param_rsp_ready',['param_rsp_error']]]){
    if(held[name])assert.deepStrictEqual([get(valid),...payload.map(get)],held[name],`${name} changed during stall`);
    held[name]=get(valid)&&!get(accept) ? [1,...payload.map(get)]:null;
  }
  if(frame && get('scratch_write')){
    const req=sim.get('scratch_request'); // packed write, bank, address, format, wdata
    const bank=Number((req>>131n)&31n),address=Number((req>>99n)&0xffffffffn);
    const width=bank===13 ? 48n:bank===11 ? 32n:bank===14||bank===15 ? 24n:16n;
    // The adapter promotes first-linear F10 writes into native hidden F22.
    const raw=req&((1n<<width)-1n);
    const value=bank===11 && ((req>>96n)&7n)===0n ?
      BigInt.asUintN(32,BigInt.asIntN(16,raw)<<12n):raw;
    if(bank!==1 && bank!==2){
      const event=[bank,address,Number(value)];
      assert.deepStrictEqual(event,frame.events[eventIndex],`write mismatch at event ${eventIndex}, cycle ${sim.cycles}`);
      if(shape==='precision' && bank===11 && ((req>>96n)&7n)===4n){
        assert.strictEqual(value,3528856n,'Stored GELU(1) lost its F22 fraction');preciseGeluWrites++;
      }
      eventIndex++;commits++;
    }
  }
  if(frame && get('logit_valid') && get('logit_ready')){
    assert.strictEqual(get('logit_index'),outputIndex);assert.strictEqual(get('logit_last'),Number(outputIndex===frame.outputs.length-1));
    assert.strictEqual(Number(signed(sim.get('logit_data'),16)),frame.outputs[outputIndex]);outputIndex++;
  }
  if(frame && get('completion_valid') && get('completion_ready')){
    assert.strictEqual(get('completion_error'),Number(frame.code!==0));assert.strictEqual(get('completion_code'),frame.code);
    assert.strictEqual(get('status')&12,0,'recoverable input error must not become fatal');
    assert.strictEqual(get('completion_position'),frame.position);
    assert.strictEqual(eventIndex,frame.events.length);assert.strictEqual(outputIndex,frame.outputs.length);
  }
  sim.tick();
}
function until(test,inputs={},limit=100000){
  for(let i=0;i<limit;i++){sim.set({...ready(),...inputs});sim.evaluate();if(test())return;step(inputs);}
  throw Error('Timeout at cycle '+sim.cycles);
}
sim.set(Object.fromEntries(Object.keys(sim.inputs).map(n=>[n,0])));step({rst:1});step({rst:1});step({rst:0});
for(let i=0;i<fixture.parameters.length;i++){
  until(()=>get('param_ready'),{param_valid:1,param_addr:i,param_data:fixture.parameters[i]});
  step({param_valid:1});sim.set({param_valid:0});
  until(()=>get('param_rsp_valid')&&get('param_rsp_ready'));assert.strictEqual(get('param_rsp_error'),0);step();
}
step({parameter_commit:1});step({parameter_commit:0});
let results=[];
for(let f=0;f<fixture.frames.length;f++){
  frame=fixture.frames[f];eventIndex=0;outputIndex=0;
  until(()=>get('frame_ready'),{frame_valid:1});step({frame_valid:1});sim.set({frame_valid:0});
  for(let i=0;i<fixture.features.length;i++){
    const data={feature_valid:1,feature_data:fixture.features[i],feature_last:Number(i===fixture.features.length-1)};
    until(()=>get('feature_ready'),data);step(data);sim.set({feature_valid:0});
  }
  for(let i=0;i<frame.mask.length;i++){
    const data={mask_valid:1,mask_bit:frame.mask[i],mask_last:Number(i===frame.mask.length-1)};
    until(()=>get('mask_ready'),data);step(data);sim.set({mask_valid:0});
  }
  until(()=>get('completion_valid')&&get('completion_ready'));step();
  results.push({frame:f,code:frame.code,position:frame.position,writes:eventIndex,outputs:outputIndex,cycle:sim.cycles,passed:true});
  console.log(`${shape} frame ${f}: PASS, ${eventIndex} checked writes, ${outputIndex} outputs, cycle ${sim.cycles}`);
  frame=null;
}
if(shape==='precision')assert.strictEqual(preciseGeluWrites,fixture.frames.length*4*fixture.shape[3]);
const report={shape,method:'cycle simulation of lowered actual RTL, independent Python integer write-stream reference',
  cycles:sim.cycles,checkedWrites:commits,seconds:(Date.now()-start)/1000,results};
fs.writeFileSync(`rtl/tests/complete-${shape}-results.json`,JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({shape,cycles:sim.cycles,checkedWrites:commits,seconds:report.seconds}));
