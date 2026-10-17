// Small architecture checks, not RTL or trained-model verification.
const assert=require('assert');
for(const M of [1,2,3])for(const N of [1,2,5])for(const D of [1,2,7]){
 let m=0,n=0,j=0,x=101,p=701,e=1201,row=1201,count=0;
 while(true){
  assert.equal(x,101+(m*N+n)*D+j);
  assert.equal(p,701+n*D+j);
  assert.equal(e,1201+m*D+j);count++;
  if(m===M-1&&n===N-1&&j===D-1)break;
  if(j<D-1){j++;x++;p++;e++;}
  else{j=0;if(n<N-1){n++;x++;p++;e=row;}
   else{n=0;m++;x++;p=701;row+=D;e=row;}}
 }
 assert.equal(count,M*N*D);
}
for(let k=0;k<=6;k++)for(let raw=-1000;raw<=1000;raw++){
 const v=BigInt(raw),shift=BigInt(k),q=v>>shift;
 const guard=k?Number((v>>(shift-1n))&1n):0;
 const sticky=k>1&&Boolean(v&((1n<<(shift-1n))-1n));
 const inc=guard&&Boolean(sticky||Boolean(q&1n));
 const result=Number(q+(inc?1n:0n));
 const real=raw/2**k,lower=Math.floor(real),fraction=real-lower;
 const expected=fraction<.5?lower:fraction>.5?lower+1:lower%2===0?lower:lower+1;
 assert.equal(result,expected,'nearest-even mismatch');
 const clipped=Math.max(-128,Math.min(127,result));
 assert(clipped>=-128&&clipped<=127);
}
const diagram=require('./build-stage1-hierarchy.cjs');
assert.equal(diagram.pages.length,0,'import must not build/overwrite Stage 1');
console.log('27 index configurations, 14007 signed rounding cases, and shared renderer import passed.');
