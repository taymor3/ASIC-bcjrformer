const fs=require('fs'),assert=require('assert');
const {CycleSimulator}=require('../../../rtl/tests/cycle_simulator.cjs');
const out='rtl/tests/tmp/post-fix-critical-review';
const vectors=JSON.parse(fs.readFileSync(`${out}/function-golden.json`));
const sim=new CycleSimulator('rtl/tests/arithmetic-netlist.json','arithmetic_sim_top');
sim.set({clk:0,rst:1,req_valid:0,rsp_ready:0,mode:0,req:0,tag:0});sim.tick();sim.set({rst:0});
const maximum={1:{error:0},4:{error:0}},start=Date.now();let counts={1:0,4:0};
for(let i=0;i<vectors.length;i++){
  const [mode,raw,exact]=vectors[i],tag=i%256;
  sim.set({mode,req:BigInt.asUintN(128,BigInt(raw)),tag,req_valid:1,rsp_ready:0});sim.evaluate();
  assert.strictEqual(sim.get('req_ready'),1n);sim.tick();sim.set({req_valid:0});sim.evaluate();
  for(let latency=0;sim.get('rsp_valid')===0n;latency++){assert(latency<70);sim.tick();}
  assert.strictEqual(sim.get('rsp_error'),0n);assert.strictEqual(sim.get('rsp_tag'),BigInt(tag));
  const observed=Number(mode===4?BigInt.asIntN(32,sim.get('rsp')):sim.get('rsp'))/2**22;
  const error=Math.abs(observed-exact);
  assert(error<1e-5,JSON.stringify({mode,raw,observed,exact,error}));
  if(error>maximum[mode].error)maximum[mode]={error,raw,observed,exact};counts[mode]++;
  sim.set({rsp_ready:1});sim.tick();sim.set({rsp_ready:0});
  if((i+1)%8192===0)console.log('checked',i+1,'cycles',sim.cycles);
}
assert.strictEqual(counts[4],65536);assert.strictEqual(counts[1],12289);
const report={passed:true,counts,maximum,cycles:sim.cycles,seconds:(Date.now()-start)/1000,
  method:'freshly lowered actual arithmetic RTL; independent math.erf/math.exp function comparison for every represented GELU input and sampled EXP inputs'};
fs.writeFileSync(`${out}/function-results.json`,JSON.stringify(report,null,2)+'\n');console.log(report);
