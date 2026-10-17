// Deterministic fault injection and bounded periodic stalls; not a liveness proof.
const assert=require('assert'),fs=require('fs');
const {CycleSimulator}=require('./cycle_simulator.cjs');
const cases=[
 [0,'embedding-second-norm-error',{normFault:2}],
 [0,'embedding-reset-linear',{reset:'linear'}],
 [0,'embedding-reset-second-norm',{reset:'second-norm'}],
 [0,'embedding-reset-final-copy',{reset:'copy'}],
 [0,'embedding-reset-held-response',{reset:'held'}],
 [0,'embedding-held-response',{}],
 [1,'final-early-linear-error',{linearFault:1}],
 [1,'final-late-linear-error',{linearFault:3}],
 [1,'final-unclassified-error',{linearFault:1,unclassified:true}],
 [1,'final-reset-linear',{reset:'linear'}],
 [1,'final-reset-held-response',{reset:'held'}],
 [1,'final-held-response',{}],
 [2,'aggregation-reciprocal-error',{recipFault:'error'}],
 [2,'aggregation-reciprocal-unclassified-error',{recipFault:'unclassified'}],
 [2,'aggregation-reciprocal-bad-tag',{recipFault:'tag'}],
 [2,'aggregation-reciprocal-zero',{recipFault:'zero'}],
 [2,'aggregation-write-error-after-commit',{writeFault:true}],
 [2,'aggregation-reset-memory',{reset:'memory'}],
 [2,'aggregation-reset-reciprocal',{reset:'reciprocal'}],
 [2,'aggregation-reset-write',{reset:'write'}],
 [2,'aggregation-reset-held-response',{reset:'held'}],
 [2,'aggregation-delayed-held-response',{}],
];
const results=[];
for(const [mode,name,options] of cases){
 const sim=new CycleSimulator(`rtl/tests/controller-fault-${mode}-netlist.json`,'controller_fault_sim_top');
 const get=n=>sim.get(n),num=n=>Number(get(n));
 sim.set({clk:0,rst:1,start:0,finish_ready:0,mem_ready:0,mem_valid:0,mem_error:0,mem_data:0,
  norm_ready:0,norm_valid:0,norm_error:0,norm_status:0,linear_ready:0,linear_valid:0,linear_error:0,linear_status:0,
  recip_ready:0,recip_valid:0,recip_error:0,recip_status:0,recip_data:0,recip_tag:0});sim.tick();
 let queues={},counts={},writes=[],sent=false,resetDone=false,held=0,previous=null,completed=false,stalls=0;
 const fault=!!(options.normFault||options.linearFault||options.recipFault||options.writeFault);
 const snapshot=()=>({memory:[get('memory_request'),get('write'),get('bank'),get('address'),get('format'),get('wdata')],
  norm:[get('norm_request'),get('norm_length')],linear:[get('linear_request'),get('linear_inputs'),get('linear_outputs'),get('linear_src'),get('linear_dst')],
  reciprocal:[get('reciprocal_request'),get('reciprocal_input')],completion:[get('done'),get('error'),get('status'),get('result')]});
 for(let cycle=0;cycle<3000;cycle++){
  const go=cycle%5!==0,reply=kind=>queues[kind]&&cycle>=queues[kind].due;
  sim.set({rst:0,start:!sent?1:0,finish_ready:0,
   mem_ready:go&&!queues.memory?1:0,mem_valid:reply('memory')?1:0,mem_error:queues.memory?.error||0,mem_data:queues.memory?.data||0,
   norm_ready:go&&!queues.norm?1:0,norm_valid:reply('norm')?1:0,norm_error:queues.norm?.error||0,norm_status:queues.norm?.status||0,
   linear_ready:go&&!queues.linear?1:0,linear_valid:reply('linear')?1:0,linear_error:queues.linear?.error||0,linear_status:queues.linear?.status||0,
   recip_ready:go&&!queues.reciprocal?1:0,recip_valid:reply('reciprocal')?1:0,recip_error:queues.reciprocal?.error||0,
   recip_status:queues.reciprocal?.status||0,recip_data:queues.reciprocal?.data||0,recip_tag:queues.reciprocal?.tag||0});
  sim.evaluate();if(num('done'))held++;
  sim.set({finish_ready:held>=5&&cycle%3!==0?1:0});sim.evaluate();
  const resetTarget=!resetDone&&options.reset&&(
   options.reset==='linear'&&queues.linear || options.reset==='second-norm'&&queues.norm&&counts.norm===2 ||
   options.reset==='copy'&&queues.memory?.write&&queues.memory.bank===3 ||
   options.reset==='memory'&&queues.memory || options.reset==='reciprocal'&&queues.reciprocal ||
   options.reset==='write'&&queues.memory?.write || options.reset==='held'&&held===2);
  if(resetTarget){
   sim.set({rst:1});sim.evaluate();
   for(const signal of ['ready','done','memory_request','memory_response','norm_request','norm_response','linear_request','linear_response','reciprocal_request','reciprocal_response'])
    assert.strictEqual(get(signal),0n,`${name}: reset did not suppress ${signal}`);
   sim.tick();queues={};counts={};writes=[];sent=false;held=0;previous=null;resetDone=true;continue;
  }
  const current=snapshot();
  if(previous)for(const kind of Object.keys(current))if(previous.held[kind])
   assert.deepStrictEqual(current[kind],previous.values[kind],`${name}: stalled ${kind} changed`);
  const heldNow={memory:num('memory_request')&&!num('mem_ready'),norm:num('norm_request')&&!num('norm_ready'),
   linear:num('linear_request')&&!num('linear_ready'),reciprocal:num('reciprocal_request')&&!num('recip_ready'),
   completion:num('done')&&!num('finish_ready')};
  stalls+=Object.values(heldNow).filter(Boolean).length;previous={held:heldNow,values:current};
  if(!sent&&num('ready'))sent=true;
  // Responses are counted only on handshakes; a response may be delayed several cycles.
  for(const [kind,readyName] of [['memory','memory_response'],['norm','norm_response'],['linear','linear_response'],['reciprocal','reciprocal_response']]){
   if(reply(kind)&&num(readyName)){
    const q=queues[kind];
    if(kind==='memory'&&q.write&&!q.error)writes.push({bank:q.bank,address:q.address,data:q.dataWritten});
    delete queues[kind];
   }
  }
  if(num('memory_request')&&num('mem_ready')){
   assert(!queues.memory);counts.memory=(counts.memory||0)+1;
   const bank=num('bank'),address=num('address'),write=!!num('write');
   assert.strictEqual(num('format'),bank===2?1:0);
   // Read requests may retain low write-data bits; the adapter ignores them.
   let data=mode===2?(bank===2?0:20+address):(bank===12?100+address:10+address);
   if(write&&mode===2){assert.strictEqual(bank,17);assert.strictEqual(Number(get('wdata')),21+address);}
   queues.memory={due:cycle+3+(counts.memory%3),write,bank,address,data,error:options.writeFault&&write&&address===1?1:0,dataWritten:get('wdata')};
  }
  for(const kind of ['norm','linear','reciprocal']){
   const request=kind==='reciprocal'?'reciprocal_request':kind+'_request',ready=kind==='reciprocal'?'recip_ready':kind+'_ready';
   if(!num(request)||!num(ready))continue;
   assert(!queues[kind]);counts[kind]=(counts[kind]||0)+1;const count=counts[kind];
   let error=0,status=3,tag=0,data=1n<<31n;
   if(kind==='norm'){
    assert.strictEqual(num('norm_length'),count%2?2:3);
    if(options.normFault===count){error=1;status=4;}
   }
   if(kind==='linear'){
    assert.strictEqual(num('linear_inputs'),2);assert.strictEqual(num('linear_outputs'),mode===0?3:1);
    if(mode===1){assert.strictEqual(num('linear_src'),(count-1)*2);assert.strictEqual(num('linear_dst'),count-1);}
    if(options.linearFault===count){error=1;status=options.unclassified?0:4;}
   }
   if(kind==='reciprocal'){
    assert.strictEqual(get('reciprocal_input'),2n<<22n);
    if(options.recipFault==='error'){error=1;status=4;}
    if(options.recipFault==='unclassified'){error=1;status=0;}
    if(options.recipFault==='tag')tag=1;
    if(options.recipFault==='zero')data=0n;
   }
   queues[kind]={due:cycle+4+(count%3),error,status,tag,data};
  }
  if(num('done')){
   assert.strictEqual(Object.keys(queues).length,0,`${name}: completion before all service responses`);
   assert.strictEqual(num('error'),fault?1:0,`${name}: wrong completion error`);
   if(fault)assert(num('status')&12,`${name}: missing fatal classification`);
   if(options.normFault || options.linearFault&&!options.unclassified || options.recipFault==='error' || options.recipFault==='zero')
    assert(num('status')&4,`${name}: missing numeric error`);
   if(options.unclassified || options.recipFault==='unclassified' || options.recipFault==='tag' || options.writeFault)
    assert(num('status')&8,`${name}: missing protocol error`);
   if(mode===2)assert.strictEqual(Number(get('result')>>16n),fault?2:0);
   if(!fault){
    assert.strictEqual(num('status')&3,3,`${name}: nonfatal child flags lost`);
    if(mode===0){assert.strictEqual(counts.norm,4);assert.strictEqual(counts.linear,2);assert.strictEqual(writes.filter(w=>w.bank===3).length,6);}
    if(mode===1)assert.strictEqual(counts.linear,3);
    if(mode===2)assert.deepStrictEqual(writes.map(w=>[w.address,Number(w.data)]),[[0,21],[1,22]]);
   }
   if(options.normFault){assert.strictEqual(counts.norm,2);assert.strictEqual(counts.linear,1);assert.strictEqual(writes.filter(w=>w.bank===3).length,0);}
   if(options.linearFault)assert.strictEqual(counts.linear,options.linearFault);
   if(options.recipFault){assert.strictEqual(writes.length,0);assert.strictEqual(counts.reciprocal,1);}
   if(options.writeFault)assert.deepStrictEqual(writes.map(w=>w.address),[0]);
  }
  if(num('done')&&num('finish_ready')){sim.tick();completed=true;break;}
  sim.tick();
 }
 assert(completed,`${name}: completion timeout`);assert(held>=5,`${name}: completion not held`);assert(stalls>0);
 if(options.reset)assert(resetDone,`${name}: reset target never reached`);
 sim.set({start:1,mem_valid:0,norm_valid:0,linear_valid:0,recip_valid:0});sim.evaluate();
 assert.strictEqual(get('ready'),fault?0n:1n,`${name}: wrong post-completion readiness`);
 if(fault)for(let lockCycle=0;lockCycle<3;lockCycle++){
  for(const signal of ['ready','memory_request','norm_request','linear_request','reciprocal_request'])
   assert.strictEqual(get(signal),0n,`${name}: fatal controller issued work before reset`);
  sim.tick();
 }
 results.push({name,mode,passed:true,cycles:sim.cycles,stalled_observations:stalls,reset_exercised:resetDone,counts});
 console.log(`${name}: PASS (${sim.cycles} cycles)`);
}
fs.writeFileSync('rtl/tests/controller-fault-results.json',JSON.stringify({scope:'Actual controllers with modeled child services; deterministic completion and reset assertions under bounded periodic stalls, not arbitrary-delay liveness',results},null,2)+'\n');
console.log(`${results.length} targeted controller scenarios passed`);
