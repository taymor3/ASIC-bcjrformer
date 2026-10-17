const fs=require('fs'),assert=require('assert'),{CycleSimulator}=require('./cycle_simulator.cjs');
const sim=new CycleSimulator('rtl/tests/arithmetic-netlist.json','arithmetic_sim_top');
const vectors=JSON.parse(fs.readFileSync('rtl/tests/arithmetic-vectors.json'));
sim.set({clk:0,rst:1,req_valid:0,rsp_ready:0,mode:0,req:0,tag:0});sim.tick();sim.set({rst:0});
const start=Date.now();let counts={};
for(let i=0;i<vectors.length;i++){
  const v=vectors[i],tag=i%256;
  sim.set({mode:v.mode,req:BigInt(v.req),tag,req_valid:1,rsp_ready:0});sim.evaluate();
  assert.strictEqual(sim.get('req_ready'),1n);sim.tick();sim.set({req_valid:0});sim.evaluate();
  for(let latency=0;sim.get('rsp_valid')===0n;latency++){
    assert(latency<1024,'arithmetic operation exceeded its bound');
    assert.strictEqual(sim.get('req_ready'),0n);sim.tick();
  }
  assert.strictEqual(sim.get('rsp_tag'),BigInt(tag));assert.strictEqual(sim.get('rsp_error'),BigInt(v.error),`error vector ${i}`);
  if(!v.error)assert.strictEqual(sim.get('rsp'),BigInt(v.rsp),`result vector ${i}`);
  if(v.flags!==null)assert.strictEqual(sim.get('status'),BigInt(v.flags),`flags vector ${i}`);
  const held=['rsp','rsp_tag','rsp_error','status'].map(n=>sim.get(n));
  sim.set({req:BigInt(v.req)^0xffffn,tag:255-tag});sim.tick();sim.tick();
  assert.deepStrictEqual(['rsp','rsp_tag','rsp_error','status'].map(n=>sim.get(n)),held,'held arithmetic response changed');
  assert.strictEqual(sim.get('req_ready'),0n);sim.set({rsp_ready:1});sim.tick();sim.set({rsp_ready:0});sim.evaluate();
  assert.strictEqual(sim.get('rsp_valid'),0n);counts[v.mode]=(counts[v.mode]||0)+1;
}
// Reset must discard an outstanding operation and suppress both handshakes.
sim.set({mode:4,req:1024,req_valid:1});sim.evaluate();sim.tick();sim.set({rst:1});sim.evaluate();
assert.strictEqual(sim.get('rsp_valid'),0n);assert.strictEqual(sim.get('req_ready'),0n);sim.tick();
sim.set({rst:0,req_valid:0});sim.evaluate();assert.strictEqual(sim.get('rsp_valid'),0n);
const report={passed:true,vectors:vectors.length,counts,cycles:sim.cycles,seconds:(Date.now()-start)/1000,
 method:'actual arithmetic RTL lowered to vector netlist; integer/Taylor golden vectors and held-response/reset checks'};
fs.writeFileSync('rtl/tests/arithmetic-results.json',JSON.stringify(report,null,2)+'\n');console.log(report);
