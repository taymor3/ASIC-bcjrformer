// Integration faults and reset recovery using the actual single-element core.
const fs=require('fs'),assert=require('assert'),{CycleSimulator}=require('./cycle_simulator.cjs');
const fixture=JSON.parse(fs.readFileSync('rtl/tests/core-single-reference.json'));
const sim=new CycleSimulator('rtl/tests/core-single-netlist.json');
const get=n=>Number(sim.get(n));let results=[];
function step(x={}){sim.set(x);sim.evaluate();sim.tick();}
function wait(test,x={},limit=10000){for(let i=0;i<limit;i++){sim.set(x);sim.evaluate();if(test())return;step(x);}throw Error('Timeout');}
function reset(){
  sim.set(Object.fromEntries(Object.keys(sim.inputs).map(n=>[n,0])));
  step({rst:1});step({rst:0,param_rsp_ready:1,logit_ready:1,completion_ready:1});
  assert.strictEqual(get('frame_ready'),0);assert.strictEqual(get('completion_valid'),0);
}
function load(){for(let i=0;i<fixture.parameters.length;i++){
  wait(()=>get('param_ready'),{param_valid:1,param_addr:i,param_data:fixture.parameters[i]});step({param_valid:1});sim.set({param_valid:0});
  wait(()=>get('param_rsp_valid'));assert.strictEqual(get('param_rsp_error'),0);step();
}step({parameter_commit:1});step({parameter_commit:0});assert.strictEqual(get('frame_ready'),1);}
function start(){wait(()=>get('frame_ready'),{frame_valid:1});step();sim.set({frame_valid:0});}
function data(maskBit=0){wait(()=>get('feature_ready'),{feature_valid:1,feature_data:fixture.features[0],feature_last:1});step();sim.set({feature_valid:0});
  wait(()=>get('mask_ready'),{mask_valid:1,mask_bit:maskBit,mask_last:1});step();sim.set({mask_valid:0});}
function fatalCompletion(){
  sim.set({completion_ready:0});let outputs=0;
  wait(()=>get('completion_valid'),{});assert.strictEqual(get('logit_valid'),outputs);
  assert.strictEqual(get('completion_code'),2);assert.strictEqual(get('completion_error'),1);
  const report=['completion_code','completion_position','completion_error','status'].map(get);
  for(let i=0;i<5;i++){step();assert.deepStrictEqual(['completion_code','completion_position','completion_error','status'].map(get),report);}
  step({completion_ready:1});assert.strictEqual(get('frame_ready'),0);assert.strictEqual(get('param_ready'),0);assert.strictEqual(get('busy'),1);
  for(let i=0;i<5;i++)step();assert.strictEqual(get('completion_valid'),0);
}
reset();load();start();
wait(()=>get('feature_ready'),{feature_valid:1,feature_data:123,feature_last:0});step();sim.set({feature_valid:0});fatalCompletion();
results.push({name:'bad feature last: fatal held report and reset lock',passed:true});
reset();load();start();data();
// Embedding is executing with real memory/normalization services.
for(let i=0;i<37;i++)step();step({parameter_commit:1});step({parameter_commit:0});fatalCompletion();
results.push({name:'illegal commit during computation: drain then fatal lock',passed:true});
reset();load();start();data();for(let i=0;i<80;i++)step();reset();
for(let i=0;i<20;i++)step();assert.strictEqual(get('completion_valid'),0);assert.strictEqual(get('frame_ready'),0);
load();start();data();wait(()=>get('logit_valid'));
assert.strictEqual(get('logit_data'),fixture.frames[0].outputs[0]&65535);step();wait(()=>get('completion_valid'));
assert.strictEqual(get('completion_code'),0);step();assert.strictEqual(get('frame_ready'),1);
results.push({name:'reset during computation: image invalidation, reload and successful frame',passed:true});
start();data(1);wait(()=>get('completion_valid'));
assert.strictEqual(get('logit_valid'),0);assert.strictEqual(get('completion_code'),1);
assert.strictEqual(get('completion_error'),1);assert.strictEqual(get('status')&12,0);step();assert.strictEqual(get('frame_ready'),1);
// Recover without reset or reloading the image, then finish a successful frame.
start();data();wait(()=>get('logit_valid'));assert.strictEqual(get('logit_data'),fixture.frames[0].outputs[0]&65535);
step();wait(()=>get('completion_valid'));assert.strictEqual(get('completion_code'),0);step();assert.strictEqual(get('frame_ready'),1);
results.push({name:'EMPTY_POSITION then successful inference, without reset or parameter reload',passed:true});
const report={passed:true,method:'actual integrated RTL cycle simulation',cycles:sim.cycles,results};
fs.writeFileSync('rtl/tests/core-fault-results.json',JSON.stringify(report,null,2)+'\n');console.log(report);
