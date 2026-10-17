// Planning only: no checkpoint loading, numerical simulation or RTL timing claim.
const fs = require('fs');
const path = require('path');
function featureCount(N, pi=.05, pd=.05, std=3.5, q=2, nv=1, imax=2) {
  const avg=(pi-pd)/(1-pi), variance=(1-pd)*(pd+pi)/(1-pi)**2;
  const range=std*Math.sqrt(variance*N*nv);
  let lo=0, hi=0;
  for(let t=1;t<=N;t++) {
    lo=Math.max(lo,Math.abs(Math.trunc(Math.max(t*nv*avg-range,-t*nv))));
    hi=Math.max(hi,Math.abs(Math.trunc(Math.min(t*nv*avg+range,t*nv*imax))));
  }
  return {F:(lo+hi+1)*(q**nv-1),window:lo+hi+1,states:q**nv-1,driftRange:range};
}
function parameterLayout({F,N,M,D,K}) {
  const tensors=[]; let offset=0;
  function add(name,shape) { const words=shape.reduce((a,b)=>a*b,1); tensors.push({name,shape,base:offset,words}); offset+=words; }
  for(const p of ['weight','bias']) add(`to_patch_embedding.0.${p}`,[F]);
  add('to_patch_embedding.1.weight',[D,F]); add('to_patch_embedding.1.bias',[D]);
  for(const p of ['weight','bias']) add(`to_patch_embedding.2.${p}`,[D]);
  add('pos_embed',[N,D]); add('seq_embed.weight',[M,D]);
  for(let k=0;k<K;k++) {
    const root=`decoder.layers.${k}`;
    for(const n of ['pre_norm_attn','pre_norm_ff']) for(const p of ['weight','bias']) add(`${root}.${n}.norm.${p}`,[D]);
    for(const n of ['to_q','to_k','to_v','to_out.0']) { add(`${root}.attn.${n}.weight`,[D,D]); add(`${root}.attn.${n}.bias`,[D]); }
    add(`${root}.ff.net.0.weight`,[4*D,D]); add(`${root}.ff.net.0.bias`,[4*D]);
    add(`${root}.ff.net.3.weight`,[D,4*D]); add(`${root}.ff.net.3.bias`,[D]);
  }
  add('oned_final_embed.0.weight',[1,D]); add('oned_final_embed.0.bias',[1]);
  const expected=2*F+D*F+3*D+N*D+M*D+K*(12*D*D+13*D)+D+1;
  if(offset!==expected) throw Error('Parameter layout/count mismatch');
  return {words:offset,tensors,order:'proposed contiguous output-row-first layout; validate against real checkpoint; no values/checksums exported'};
}
function budget(config) {
  const {F,N,M,D,H,K}=config, L=M*N;
  if(![F,N,M,D,H,K].every(x=>Number.isSafeInteger(x)&&x>0)||D%H||Math.max(F,L,4*D,K)>65535) throw Error('Invalid dimensions');
  const manifest=parameterLayout(config), banks=[];
  function add(name,elements,width) { banks.push({name,elements,width,bits:elements*width}); }
  add('PARAM',manifest.words,16); add('FEATURE',L*F,16); add('MASK',L,1);
  for(const n of ['X','U','Q','KEY','VALUE','Z','ATTN_OUT']) add(n,L*D,16);
  add('TOKEN',Math.max(F,D),16); add('FFN_HIDDEN',4*D,16); add('VECTOR',Math.max(D,4*D),16);
  add('SCORE',L,48); add('EXP',L,24); add('PROB',L,24); add('LOGIT',L,16); add('OUTPUT',N,16);
  const macs={embedding:L*D*F,encoderLinear:K*12*L*D*D,score:K*L*L*D,weighted:K*L*L*D,final:L*D};
  const terms=Object.values(macs).reduce((a,b)=>a+b,0), bits=banks.reduce((a,b)=>a+b.bits,0);
  if(banks.some(b=>!Number.isSafeInteger(b.bits))) throw Error('Capacity arithmetic overflow');
  return {config:{...config,L,d:D/H},manifest,banks,totalBits:bits,totalKiB:bits/8192,macs,totalDotTerms:terms,
    operandReads:2*terms,minimumHostTransfers:L*F+L+N,
    primitives:{layernormCalls:L*(2+2*K),gelu:4*K*L*D,expWorstCase:K*H*L*L,reciprocalWorstCase:K*H*L+N},
    dotServiceIllustration:{readTransactionCycles:2,macTransactionCycles:2,cycles:6*terms,at100MHzMs:6*terms/1e5}};
}
const N=96+Math.floor(96/6)*3;
const derived=featureCount(N);
const cases=[{name:'local-example',F:derived.F,N,M:1,D:16,H:2,K:1},
  {name:'four-read-sensitivity',F:derived.F,N,M:4,D:16,H:2,K:1},
  {name:'two-layer-sensitivity',F:derived.F,N,M:1,D:16,H:2,K:2}].map(budget);
const result={status:'PROVISIONAL; not checkpoint-validated; candidate widths only',derivedFeatureEvidence:derived,cases};
fs.writeFileSync(path.join(require('path').resolve(__dirname,'..'),'docs/planning/ARCHITECTURE-BUDGET.json'),JSON.stringify(result,null,2)+'\n');
for(const c of cases) console.log(JSON.stringify({case:c.config.name,N:c.config.N,F:c.config.F,L:c.config.L,parameterWords:c.manifest.words,KiB:c.totalKiB,dotTerms:c.totalDotTerms,dotServiceMs:c.dotServiceIllustration.at100MHzMs}));
