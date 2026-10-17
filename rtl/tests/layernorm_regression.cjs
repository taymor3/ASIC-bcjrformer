// Numerical oracle uses exact BigInt division, not a rounded reciprocal.
const fs=require('fs'),assert=require('assert');
const {CycleSimulator,signed}=require('./cycle_simulator.cjs');
const sim=new CycleSimulator('tmp/layernorm-regression/netlist.json','layernorm_regression');
const get=n=>sim.get(n),yes=n=>get(n)!==0n;
const rne=(x,d)=>{const negative=x<0n,a=negative?-x:x,q=a/d,r=a%d;
  const rounded=q+BigInt(2n*r>d || (2n*r===d && (q&1n)!==0n));return negative?-rounded:rounded;};
const clip=x=>x < -32768n ? -32768n:x > 32767n ? 32767n:x;
function isqrt(n){if(n<2n)return n;let x=1n<<BigInt(Math.ceil(n.toString(2).length/2));
  for(;;){const y=(x+n/x)>>1n;if(y>=x)return x;x=y;}}
function reference(input,gamma,beta){
  const length=BigInt(input.length),mean=rne(input.reduce((s,x)=>s+x,0n)<<10n,length);
  const squares=input.reduce((s,x)=>s+((x<<10n)-mean)**2n,0n);
  const variance=rne(squares,length<<8n)+42950n;
  let root=isqrt((1n<<72n)/variance);
  const midpoint=variance*(2n*root+1n)**2n;
  if(midpoint<(1n<<74n) || (midpoint===(1n<<74n) && (root&1n)))root++;
  const output=input.map((x,i)=>clip(rne(rne(((x<<10n)-mean)*root,1n<<20n)*gamma[i]+(beta[i]<<20n),1n<<20n)));
  return {mean,variance,output};
}
let pending=null,words=[],gamma=[],beta=[],writes=0,heldRequest=null,heldResponse=null;
function step(extra={}){
  const reqReady=!pending && sim.cycles%7!==0;
  const response=!!pending && sim.cycles>=pending.due;
  sim.set({mem_req_ready:Number(reqReady),mem_rsp_valid:Number(response),mem_rsp_error:0,
    mem_rsp_rdata:response ? pending.data:0n,...extra});sim.evaluate();
  if(heldRequest!==null)assert(yes('mem_req_valid') && get('mem_req')===heldRequest,'request changed while stalled');
  heldRequest=yes('mem_req_valid')&&!reqReady ? get('mem_req'):null;
  if(heldResponse!==null)assert(yes('rsp_valid') && [get('rsp_error'),get('status')].join()===heldResponse,'completion changed while stalled');
  heldResponse=yes('rsp_valid') && !yes('rsp_ready') ? [get('rsp_error'),get('status')].join():null;
  if(response && yes('mem_rsp_ready')){
    if(pending.write){words[pending.address]=signed(pending.data&65535n,16);writes++;}
    pending=null;
  }
  if(yes('mem_req_valid') && reqReady){
    assert.strictEqual(pending,null);const req=get('mem_req');
    const packedWidth=BigInt(sim.design.ports.mem_req.bits.length);
    const write=Boolean(req>>(packedWidth-1n)),bank=Number((req>>(packedWidth-6n))&31n),address=Number((req>>(packedWidth-38n))&0xffffffffn);
    assert.strictEqual(Number((req>>96n)&7n),0);
    let data;
    if(write){assert.strictEqual(bank,10);assert(address<words.length);assert.strictEqual((req&((1n<<96n)-1n))>>16n,0n);data=req&65535n;}
    else if(bank===10){assert(address<words.length);data=BigInt.asUintN(16,words[address]);}
    else {assert.strictEqual(bank,0);data=address>=131072 ? beta[address-131072]:gamma[address-65536];
      assert.notStrictEqual(data,undefined);data=BigInt.asUintN(16,data);}
    pending={write,address,data,due:sim.cycles+2+(sim.cycles%3)};
  }
  sim.tick();
}
function until(test,limit=500000){for(let i=0;i<limit;i++){sim.evaluate();if(test())return;step();}throw Error('LayerNorm timed out');}
sim.set(Object.fromEntries(Object.keys(sim.inputs).map(n=>[n,0])));step({rst:1});step({rst:0});
const cases=[];
for(const length of [1,2,3,7,64,767,768,769]){
  for(const value of [-32768,-1024,0,1024,32767])cases.push({name:`constant-${length}-${value}`,input:Array(length).fill(BigInt(value))});
  cases.push({name:`varying-${length}`,input:Array.from({length},(_,i)=>BigInt(((i*197+31)%8192)-4096))});
}
for(const value of [1,3,-1,-3])cases.push({name:`mean-tie-2048-${value}`,input:[BigInt(value),...Array(2047).fill(0n)]});
cases.push({name:'affine-odd-9',input:[-32000n,-4000n,-9n,-1n,0n,1n,17n,7000n,31000n],affine:true});
const results=[];
for(const fixture of cases){
  words=fixture.input.slice();gamma=words.map((_,i)=>fixture.affine ? BigInt(700+i*53):1024n);
  beta=words.map((_,i)=>fixture.affine ? BigInt(i*31-100):0n);writes=0;
  const expected=reference(words,gamma,beta),length=words.length,start=sim.cycles;
  until(()=>yes('cmd_ready'));step({cmd_valid:1,length,rsp_ready:0});sim.set({cmd_valid:0});
  until(()=>yes('rsp_valid'));
  assert.strictEqual(get('rsp_error'),0n,fixture.name+' unexpected fatal');
  assert.strictEqual(get('status')&12n,0n,fixture.name+' fatal status');
  assert.strictEqual(writes,length,fixture.name+' completion preceded committed writes');assert.strictEqual(pending,null);
  assert.deepStrictEqual(words,expected.output,fixture.name+' output mismatch');
  assert.strictEqual(signed(get('mean'),32),expected.mean,fixture.name+' mean mismatch');
  assert.strictEqual(get('variance'),expected.variance,fixture.name+' variance mismatch');
  const realInput=fixture.input.map(x=>Number(x)/1024),realMean=realInput.reduce((a,b)=>a+b,0)/length;
  const realVariance=realInput.reduce((s,x)=>s+(x-realMean)**2,0)/length;
  const floatOutput=realInput.map((x,i)=>Math.min(32767/1024,Math.max(-32,
    (x-realMean)/Math.sqrt(realVariance+42950/2**32)*(Number(gamma[i])/1024)+Number(beta[i])/1024)));
  const maxFloatError=Math.max(...words.map((x,i)=>Math.abs(Number(x)/1024-floatOutput[i])));
  assert(maxFloatError<=2/1024,fixture.name+' exceeded two stored-output LSBs against floating LayerNorm');
  if(fixture.name.startsWith('constant-'))assert(words.every(v=>v===0n),fixture.name+' nonzero constant-row result');
  for(let i=0;i<4;i++)step();step({rsp_ready:1});sim.set({rsp_ready:0});
  results.push({name:fixture.name,length,cycles:sim.cycles-start,maxFloatError,passed:true});
  console.log(fixture.name+': PASS');
}
fs.writeFileSync('tmp/layernorm-regression/results.json',JSON.stringify({passed:true,
  method:'actual LayerNorm and RSQRT RTL, exact BigInt division oracle, in-place memory with stalls and delayed write acknowledgments',
  cases:results.length,cycles:sim.cycles,results},null,2)+'\n');
console.log(`${results.length} LayerNorm cases passed; ${sim.cycles} actual RTL cycles`);
