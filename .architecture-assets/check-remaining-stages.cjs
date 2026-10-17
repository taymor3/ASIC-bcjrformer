// Architecture-level index/math checks, not RTL or checkpoint simulation.
const assert=require('assert');
for(const L of [1,3,7])for(const H of [1,2,3])for(const d of [1,2,4]){
 const D=H*d,V=Array.from({length:L},(_,j)=>Array.from({length:D},(_,r)=>j*100+r-31));
 const flat=V.flat(),p=Array.from({length:L},(_,j)=>(j+1)/(L*(L+1)/2));
 for(let h=0;h<H;h++)for(let r=0;r<d;r++){
  let byStride=0;for(let j=0;j<L;j++)byStride+=p[j]*flat[h*d+r+j*D];
  const direct=V.reduce((a,row,j)=>a+p[j]*row[h*d+r],0);assert.equal(byStride,direct);
 }
 const visited=[];for(let h=0;h<H;h++)for(let i=0;i<L;i++)for(let r=0;r<d;r++)visited.push(i*D+h*d+r);
 assert.equal(new Set(visited).size,L*D);assert.equal(Math.max(...visited),L*D-1);
}
function aggregate(z,mask){
 const out=[],N=z[0].length;
 for(let n=0;n<N;n++){let sum=0,count=0;for(let m=0;m<z.length;m++)if(!mask[m][n]){sum+=z[m][n];count++;}
  if(!count)return {valid:false,index:n,out:[]};out.push(sum/count);}
 return {valid:true,out};
}
assert.deepEqual(aggregate([[2,10],[6,90]],[[false,false],[false,true]]),{valid:true,out:[4,10]});
assert.deepEqual(aggregate([[2,10]],[[false,true]]),{valid:false,index:1,out:[]});
assert.deepEqual(aggregate([[2,10]],[[false,false]]),{valid:true,out:[2,10]});
assert.deepEqual(aggregate([[2,10],[4,20]],[[false,true],[true,true]]),{valid:false,index:1,out:[]});
// Nonuniform negative-score row verifies max must not be initialized to zero.
const scores=[-1002,-1001,-1000],max=Math.max(...scores),e=scores.map(x=>Math.exp(x-max)),sum=e.reduce((a,b)=>a+b,0);
assert(sum>0);assert(Math.abs(e.reduce((a,b)=>a+b/sum,0)-1)<1e-12);
const frames=7;let n=0;const accepted=[];
for(let cycle=0;n<frames;cycle++){const ready=cycle%3!==0;if(ready)accepted.push(n++);}
assert.deepEqual(accepted,[0,1,2,3,4,5,6]);
console.log('27 head/stride configurations, corrected mask/count and empty-frame cases, softmax math and output-index schedule passed.');
