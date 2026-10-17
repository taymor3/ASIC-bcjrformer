// Review reproducer: report the mathematical invariant, rather than bless an implementation value.
const assert=require('assert'),fs=require('fs');
const {CycleSimulator,signed}=require('../../../rtl/tests/cycle_simulator.cjs');
const sim=new CycleSimulator('rtl/tests/review-layernorm-constant-netlist.json','layernorm_review_top');
sim.set({clk:0,rst:1,start:0});sim.evaluate();sim.tick();
sim.set({rst:0,start:1});sim.evaluate();assert.strictEqual(Number(sim.get('ready')),1);sim.tick();sim.set({start:0});
for(let i=0;i<30000 && !Number(sim.get('write_seen'));i++){sim.evaluate();sim.tick();}
sim.evaluate();assert.strictEqual(Number(sim.get('write_seen')),1,'No output write observed');
assert.strictEqual(Number(sim.get('status'))&12,0,'Unexpected fatal status');
const actual=Number(signed(sim.get('first_value'),16));
const result={method:'fresh actual layernorm_ctrl and rsqrt_unit; constant-value test memory responder',
 length:768,input_raw_Q10:32767,gamma_raw_Q10:1024,beta_raw_Q10:0,first_stored_raw_Q10:actual,
 first_stored_real:actual/1024,exact_mathematical_output:0,cycles:sim.cycles,
 mathematical_invariant_holds:actual===0,counterexample_reproduced:actual!==0};
fs.writeFileSync('rtl/tests/review-layernorm-constant-results.json',JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify(result,null,2));
