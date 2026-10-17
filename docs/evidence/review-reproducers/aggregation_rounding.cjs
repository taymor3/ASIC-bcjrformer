const {CycleSimulator}=require('../../../rtl/tests/cycle_simulator.cjs');
const assert=require('assert'),fs=require('fs');
const sim=new CycleSimulator('rtl/tests/tmp/post-fix-critical-review/aggregation.json','agg_tie_top');
sim.set({clk:0,rst:1,start:0,finish_ready:0,mem_ready:0,mem_valid:0,mem_error:0,mem_data:0});sim.tick();
let sent=false,pending=null,written=[];
for(let c=0;c<500;c++){
  sim.set({rst:0,start:sent?0:1,finish_ready:1,mem_ready:pending?0:1,
    mem_valid:pending?1:0,mem_data:pending?.data||0});sim.evaluate();
  const n=k=>Number(sim.get(k));
  if(!sent&&n('ready'))sent=true;
  const consume=pending&&n('memory_response');let next=null;
  if(n('memory_request')&&n('mem_ready')){
    const bank=n('bank'),address=n('address'),write=n('write');
    if(write){assert.strictEqual(bank,17);assert.strictEqual(address,0);written.push(n('wdata'));}
    else assert(bank===2||bank===16);
    next={data:write||bank===2?0:(address<3?1:0)};
  }
  if(n('done')){
    assert(!n('error'));assert.deepStrictEqual(written,[1]);assert(!pending);
    const report={actual_raw:written[0],exact_rne_mean_raw:0,inputs_raw:[1,1,1,0,0,0],
      cycles:sim.cycles,classification:'declared reciprocal/product rounding approximation'};
    fs.writeFileSync('rtl/tests/tmp/post-fix-critical-review/aggregation-result.json',JSON.stringify(report,null,2)+'\n');
    console.log(report);process.exit(0);
  }
  sim.tick();if(consume)pending=null;if(next)pending=next;
}
throw Error('timeout');
