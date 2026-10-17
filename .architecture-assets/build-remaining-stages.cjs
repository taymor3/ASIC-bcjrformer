const {projectFile}=require('../scripts/project-paths.cjs');
// Stages 3--5: editable hierarchical draw.io diagrams; no RTL is generated.
const fs=require('fs'),path=require('path');
const {root,pages,page,box,edge,shell,note,xml,svg}=require('./build-stage1-hierarchy.cjs');
let group=3;
function create(id,name,file){const p=page(id,name,file);p.group=group;return p;}
function flow(id,name,file,labels,notes,access='Memory access: inputs / parameters / temporary results / output'){
 const p=create(id,name,file);shell(p,name);
 const base=name.split(' — ')[0];p.nodes.find(n=>n.id==='ctrl').label=/controller$/i.test(base)?base:base+' controller';
 const w=Math.min(220,Math.floor(1000/labels.length)-25),gap=(1050-labels.length*w)/(labels.length-1||1);
 labels.forEach((label,i)=>box(p,'b'+i,225+i*(w+gap),290,w,95,label,'unit'));
 box(p,'input',20,300,145,75,'Stored input');box(p,'output',1320,300,160,75,'Stored output');
 edge(p,'input','input','b0',[165,337],[225,337]);
 labels.forEach((_,i)=>{const n=p.nodes.find(n=>n.id==='b'+i),x=n.x+w/2;
  edge(p,'ctrl'+i,'ctrl',n.id,[x,175],[x,290],[],'control',true);
  if(i){const prev=p.nodes.find(n=>n.id==='b'+(i-1));edge(p,'data'+i,prev.id,n.id,[prev.x+w,337],[n.x,337]);}
 });
 const last=p.nodes.find(n=>n.id==='b'+(labels.length-1));edge(p,'out',last.id,'output',[last.x+w,337],[1320,337]);
 box(p,'access',260,480,950,65,access);edge(p,'accessctrl','ctrl','access',[1230,175],[1210,512],[[1260,175],[1260,512]],'control',true);
 labels.forEach((_,i)=>{const n=p.nodes.find(n=>n.id==='b'+i),x=n.x+w/2;edge(p,'access'+i,n.id,'access',[x,385],[x,480],[],'data',true);});
 note(p,notes);return p;
}
function fsm(id,name,file,labels,notes,loops=[]){
 const p=create(id,name,file);box(p,'title',30,15,1440,35,name,'frame','text');
 const coords=[];
 labels.forEach((label,i)=>{const row=Math.floor(i/6),col=row%2?5-i%6:i%6,x=90+col*230,y=85+row*185;coords.push([x,y]);
  const wrapped=label.split('\n').flatMap(line=>{const out=[];let current='';for(const word of line.split(' ')){if(current&&(current+' '+word).length>11){out.push(current);current=word;}else current+=(current?' ':'')+word;}out.push(current);return out;}).join('\n');
  box(p,'s'+i,x,y,105,105,wrapped,'control','circle');});
 for(let i=0;i<labels.length-1;i++){const [x,y]=coords[i],[nx,ny]=coords[i+1];const same=y===ny,right=nx>x;
  edge(p,'seq'+i,'s'+i,'s'+(i+1),same?[x+(right?105:0),y+52]:[x+52,y+105],same?[nx+(right?0:105),ny+52]:[nx+52,ny],[],'control');}
 loops.forEach(([from,to,label],i)=>{const [x,y]=coords[from],[nx,ny]=coords[to],lane=200+Math.floor(from/6)*185+i*8;
  const crossRow=y!==ny;
  edge(p,'loop'+i,'s'+from,'s'+to,[x+52,y+105],crossRow?[nx+52,ny]:[nx+52,ny+105],crossRow?[[x+52,lane],[40+i*6,lane],[40+i*6,ny-25],[nx+52,ny-25]]:[[x+52,lane],[nx+52,lane]],'control',false,label,[crossRow?60:Math.min(x,nx)+80,lane+17]);});
 note(p,notes+'\nA Read / Write state uses the shared transaction FSM. A Run state waits for child completion. Stalls never advance an index.');return p;
}
const p3=flow('s3-top','Stage 3 — Encoder layers','Stage3_datapath',['One encoder layer\nRepeated K times\nLayer diagram'],
 'Input X⁽⁰⁾ [L,D]; output X⁽ᴷ⁾ [L,D]. K is the number of layers, not a trained weight.\nOne hardware layer is reused with distinct parameter sets. k advances only after the whole layer finishes.\nThe mask remains available for every layer. Child controllers run one at a time; fatal errors block Stage 4.',
 'Memory access: working X / padding mask / selected layer parameters / layer temporary results');
p3.nodes.find(n=>n.id==='input').label='Stage 2 values\nX⁽⁰⁾ [L,D]';p3.nodes.find(n=>n.id==='output').label='Stage 4 input\nX⁽ᴷ⁾ [L,D]';
fsm('s3-top-fsm','Stage 3 controller — layer loop','Stage3_fsm',['Idle','k = 0','Run layer','Next layer','Done'],
 'Run one layer with parameter bases selected by k. After K complete layers, hold completion until accepted. Reset/error rules are shared.',[[3,2,'more layers; k = k + 1']]);
const layer=flow('s3-layer','Encoder layer — reused for every k','Stage3_layer',[
 'Normalization 1\nShared unit\nStage 1 detail','Self-attention\nOwn controller','Residual add 1\nShared unit','Normalization 2\nShared unit\nStage 1 detail','FFN\nOwn controller','Residual add 2\nShared unit'],
 'U = LN1(X); O = Attention(U); R = QACT(X + O); V = LN2(R); F = FFN(V); next X = QACT(R + F).\nLN1 and LN2 reuse one engine with different learned gamma/beta. Residual additions reuse one element-wise controller.\nOriginal X is preserved through attention; R is preserved through FFN. No inference dropout.',
 'Memory access: X / U / Q,K,V / row scratch / Z,O / FFN scratch / weights / mask');
// Logical skip connections are routed above the block row and below the access row.
edge(layer,'skip1','input','b2',[165,325],[layer.nodes.find(n=>n.id==='b2').x+40,290],[[185,325],[185,245],[layer.nodes.find(n=>n.id==='b2').x+40,245]]);
edge(layer,'skip2','b2','b5',[layer.nodes.find(n=>n.id==='b2').x+60,385],[layer.nodes.find(n=>n.id==='b5').x+60,385],[[layer.nodes.find(n=>n.id==='b2').x+60,430],[layer.nodes.find(n=>n.id==='b5').x+60,430]]);
fsm('s3-layer-fsm','Encoder layer controller','Stage3_layer_fsm',['Idle','Init token','Run LN1','Next token','Run attention','Init token','Run residual 1','Next token','Init token','Run LN2','Next token','Init token','Run FFN','Run residual 2','Next token','Done'],
 'LN1 stores all U before attention. First residual stores all R before LN2. LN2 stores all V before FFN/residual 2 token loop.\nLN1: X→U; LN2: X(R)→U(V). Residual 1 writes X=R; residual 2 writes X=next layer output.',[[3,2,'more tokens'],[7,6,'more tokens'],[10,9,'more tokens'],[14,12,'more tokens']]);
flow('s3-attn','Self-attention — own controller','Stage3_attention',[
 'Q / K / V\nprojections','Score row\nDot + scale','Softmax row\nOwn controller','Weighted values\nShared dot','Output projection\nShared linear'],
 'Input U [L,D]; Q/K/V [L,D] are calculated, not stored trained parameters. H heads; d = D/H.\nFinish all Q, K, V first. For each head/query: score → softmax → weighted values. Then project all joined Z tokens to O.\nOne score/probability row is reused only after its d weighted-value results are stored. Head joining is address layout, not copying.',
 'Memory access: U / Q,K,V / scores[L] / exponentials[L] / probabilities[L] / Z,O / mask / weights');
fsm('s3-attn-fsm','Self-attention controller','Stage3_attention_fsm',['Idle','Run Q/K/V','Init head /\nquery','Run score row','Run softmax','Run weighted\nvalues','Next query /\nhead','Run output\nprojection','Done'],
 'Query i advances within head h; after the last query, advance h and reset i. After all H heads, project every Z token.\nFor a padded query the softmax child writes uniform probabilities; the baseline does not mask key columns.',[[6,3,'more queries / heads']]);
flow('s3-qkv','Q / K / V projection controller','Stage3_qkv',['Select Q, K, V\nparameter bases','Shared linear\nD → D\nStage 1 detail'],
 'For each selected projection A: A[t,j] = QACT(bA[j] + Σ U[t,f] WA[j,f]). Q first, then K, then V.\nOutput bank changes with the selected projection. Shared linear owns all result writes; this controller must not duplicate them.\nMatrix rows are stored output-major. No mask, GELU or softmax inside these projections.');
fsm('s3-qkv-fsm','Q / K / V controller','Stage3_qkv_fsm',['Idle','Select Q\nt = 0','Run linear','Next token','Next projection','Done'],
 'Repeat L D→D linear commands for Q, then K, then V. Next projection resets t and selects distinct weights/biases.\nOutput projection uses the same token-loop controller with WO/bO and Z→O; it is not a fourth Q/K/V pass.',[[3,2,'more tokens'],[4,2,'select K, then V; t = 0']]);
pages[pages.length-1].edges.find(e=>e.id==='loop1').labelAt=[850,245];
flow('s3-score','Score-row controller','Stage3_score',['Shared dot\nQ × K\nlength d','Scalar multiply\nby 1/√d\nSCORE conversion','Score register\nand write'],
 's[h,i,j] = QScore(Σᵣ Q[i,h·d+r] K[j,h·d+r] × c), with c = stored 1/√d.\nDot uses two contiguous d-element slices, initial sum zero. Scale uses a scalar multiplier, not a runtime square root.\nLoop keys j=0..L−1 for one head h and query i. Keep wide score format; do not narrow to ACT.',
 'Memory access: Q / K / scale constant / current score row');
fsm('s3-score-fsm','Score-row controller','Stage3_score_fsm',['Idle','j = 0','Run dot','Run scale','Write score','Next key','Done'],
 'Dot returns a wide sum; the scalar multiply converts to SCORE format. Write includes waiting for confirmation.\nQuery/head context stays fixed; key index advances only after its score write.',[[5,2,'more keys']]);
const soft=flow('s3-soft','Softmax-row controller','Stage3_softmax',['Compare / select\nrow maximum','Subtract max\nEXP black box','Add exp values\nRECIP black box','Multiply by 1/sum\nConvert / write'],
 'Normal row: vmax = max(s[j]); b[j] = EXP(s[j]−vmax); T = Σ b[j]; p[j] = QPROB(b[j] × RECIP(T)).\nMaximum starts from the first score, not zero. Padded query: p[j] = stored 1/L instead; no exp / reciprocal work.\nEXP and RECIP remain black boxes until range, method and error targets are chosen. T must be positive.',
 'Memory access: score row / saved exponentials / probability row / query mask / 1/L constant');
box(soft,'uniform',300,405,270,50,'Uniform selector: 1/L or normal p','select');
edge(soft,'uniform_path','uniform','b3',[570,430],[soft.nodes.find(n=>n.id==='b3').x+100,385],[[1180,430]]);
fsm('s3-soft-fsm','Softmax controller','Stage3_softmax_fsm',['Idle','Check query\nmask','Find max','Exp / store /\nsum loop','Run reciprocal','Init j = 0','Prepare normal\nor uniform p','Write p','Next entry','Done'],
 'Masked query jumps from Check mask to Init j, selecting uniform mode. Otherwise use the normal row path.\nPrepare/Write is the only probability write path. Exp sum ≤ 0 or invalid primitive response is fatal.',[[8,6,'more entries']]);
edge(pages[pages.length-1],'uniform_branch','s1','s5',[372,85],[1292,85],[[372,65],[1292,65]],'control',false,'padded: select uniform',[640,60]);
flow('s3-weighted','Weighted-value controller','Stage3_weighted',['Shared dot\nprobability × V','ACT conversion\nand write Z'],
 'Z[i,h·d+r] = QACT(Σⱼ p[j] V[j,h·d+r]), for r=0..d−1. No bias or extra scaling.\nDot operand A: probability base, stride 1. Operand B: V base + h·d+r, stride D. Length L, initial sum zero.\nProbability is unsigned and V is signed: zero-extend probability, sign-extend V; keep a widened signed accumulator.',
 'Memory access: immutable probability row / V / joined output Z');
fsm('s3-weighted-fsm','Weighted-value controller','Stage3_weighted_fsm',['Idle','r = 0','Run dot','Convert ACT','Write Z','Next feature','Done'],
 'Keep probability row unchanged until all d output features for this query/head are stored.\nZ layout already joins the heads at contiguous feature addresses; no concatenation copy is needed.',[[5,2,'more head features']]);
flow('s3-ffn','Feed-forward network — FFN controller','Stage3_ffn',['Shared linear\nD → 4D','GELU black box\neach element','Shared linear\n4D → D'],
 'A = QACT(W1·V[t] + b1); G = GELU(A); F[t] = QACT(W2·G + b2). D is token width; 4D is hidden width.\nPython nn.GELU() targets x·Φ(x), with Φ(x) = ½[1+erf(x/√2)]. Method, range and accuracy are still open.\nNo inference dropout. Residual R is not stored in FFN scratch and cannot be overwritten by these calculations.',
 'Memory access: normalized token U / A[4D] / G[4D] / F[D] / W1,b1,W2,b2');
fsm('s3-ffn-fsm','FFN controller — one token','Stage3_ffn_fsm',['Idle','Run linear 1','Init feature','Read A','Run GELU','Write G','Next feature','Run linear 2','Done'],
 'Store all 4D linear-1 values, then overwrite each A location with its GELU result after reading it.\nOnly after all 4D GELU writes finish, start linear 2 into a separate D-result scratch. Both linear commands own their writes.',[[6,3,'more hidden features']]);
flow('s3-residual','Shared residual controller','Stage3_residual',['Read left / right\noperand registers','Shared addition\nACT + ACT','Write result\nthen next index'],
 'Residual 1: R[t,j] = QACT(X[t,j] + O[t,j]). Residual 2: next X[t,j] = QACT(R[t,j] + F[t,j]).\nReuse the Stage 2 addition block with both inputs in ACT format. Read both operands before replacing the left value.\nSame controller, different source descriptors. No normalization or dot product inside residual addition.',
 'Memory access: X and O (first residual) / X holding R and FFN scratch (second residual)');
fsm('s3-residual-fsm','Residual-add controller','Stage3_residual_fsm',['Idle','Init feature','Read left','Read right','Run add','Write result','Next feature','Done'],
 'Operate on one D-element token. The owning layer controller handles its token loop and chooses first or second residual.\nAddition child holds result/flags until accepted. Write confirmation precedes the feature increment.',[[6,2,'more features']]);
flow('shared-scalar','Shared scalar arithmetic controller','Shared_scalar_datapath',['Operand registers\nA / B','Select operation\nadd/sub or multiply','Full-width result\nregister','Format conversion\nresult / flags'],
 'Scalar work includes score scaling, softmax subtract/sum/normalize, LayerNorm statistics and Stage 5 scaling.\nA descriptor selects operation, signedness and result format. Operation ownership is exclusive; no hidden parallel work.\nACT, SCORE, EXP, PROB, SUM and RECIP are distinct formats. Conversion logic is the Stage 2 Round/saturate detail.',
 'Access supplied by caller: this child has no memory writes or index loop');
fsm('shared-scalar-fsm','Scalar arithmetic controller','Shared_scalar_fsm',['Idle /\ncapture','Align /\nprepare','Issue op','Wait op','Convert','Done /\nhold'],
 'Add/subtract aligns fractions with exact shifts and an extra carry bit. Multiply retains the full product before conversion.\nUnsigned operands are zero-extended, signed operands sign-extended. Intermediate overflow is fatal; ACT saturation is recorded.');
flow('shared-txn','Shared memory transaction controller','Shared_memory_access',['Latch address\ndata / read-write','Read or write\nrequest','Wait response\ncheck error','Return data\nor write done'],
 'Only one accepted transaction is outstanding. Hold request address/data until accepted; never reissue after acceptance.\nRead done carries data; write done means the bank confirms commitment, not simply that the request was accepted.\nArbitration selects the one active owner. Banks are external to this view.');
fsm('shared-txn-fsm','Memory transaction controller','Shared_memory_fsm',['Idle /\ncapture','Request','Wait response','Done /\nhold'],
 'Response is accepted only in Wait response. Keep result/error stable in Done until the caller accepts it.\nFatal errors stop new requests and drain accepted work; no timeout is assumed. Reset clears all pending interfaces.');
flow('shared-nonlinear','Numerical black boxes — still open','Shared_nonlinear_contracts',['RSQRT\n1 / √v','EXP\neˣ','RECIP\n1 / x','GELU\nx·Φ(x)'],
 'These four blocks are alternatives, not a chain. Each has its own request/result controller and is called only when needed.\nRSQRT input positive variance+epsilon; EXP input ≤ 0; RECIP input positive; GELU input signed activation.\nAlgorithms, ranges, coefficients, bit counts and error bounds remain to be designed before RTL; no Taylor method is frozen.',
 'Inputs / outputs passed by caller; coefficients/constants may be read through an external parameter-access port');
// Do not depict unrelated nonlinear primitives as a data chain.
const nonlinear=pages[pages.length-1];nonlinear.edges=nonlinear.edges.filter(e=>!/^data\d+$/.test(e.id)&&!['input','out'].includes(e.id));
nonlinear.nodes.find(n=>n.id==='input').label='Selected request';nonlinear.nodes.find(n=>n.id==='output').label='Selected result';
nonlinear.nodes.find(n=>n.id==='ctrl').label='Selected black-box controller — common interface, algorithm still open';
for(let i=0;i<4;i++){const n=nonlinear.nodes.find(n=>n.id==='b'+i),x=n.x+n.w/2;
 edge(nonlinear,'selected_in'+i,'input',n.id,[165,325],[x,290],[[185,325],[185,245],[x,245]]);
 edge(nonlinear,'selected_out'+i,n.id,'output',[x,385],[1320,337],[[x,445],[1295,445],[1295,337]]);
}
fsm('shared-nonlinear-fsm','Nonlinear wrapper — interface only, algorithm states still open','Shared_nonlinear_fsm',['Idle /\ncapture','Check domain','Start method\nblack box','Wait method','Check result','Done /\nhold'],
 'The method supplies its own internal controller once designed. This wrapper is not the arithmetic implementation.\nReturn domain/method error through the same held completion interface; fatal errors propagate to the frame controller.');

group=4;
const p4=flow('s4-top','Stage 4 — Final projection','Stage4_datapath',['Token / address\nselection','Shared linear\nD → 1\nStage 1 detail'],
 'For each token t: z[t] = QACT(bfinal + Σⱼ X⁽ᴷ⁾[t,j] Wfinal[j]). Output z is stored as [M,N], t=mN+n.\nOne score per token; positive favors bit 1, negative favors bit 0. Scores are not probabilities; no sigmoid or threshold is used.\nShared linear owns the logit write. Stage 5 starts only after all L writes finish.',
 'Memory access: final X[L,D] / final trained weights[D] and bias[1] / read logits[L]');
p4.nodes.find(n=>n.id==='input').label='Encoder output\nX⁽ᴷ⁾ [L,D]';p4.nodes.find(n=>n.id==='output').label='Read logits\nz [M,N]';
fsm('s4-fsm','Stage 4 controller','Stage4_fsm',['Idle','t = 0','Run D→1\nlinear','Next token','Done'],
 'Input base advances by D; logit destination advances by 1. Weight/bias bases remain fixed. No padding is skipped.\nAfter the last token, hold completion until accepted. Fatal errors block Stage 5 and require reset.',[[3,2,'more tokens']]);

group=5;
const p5=flow('s5-top','Stage 5 — Read aggregation','Stage5_datapath',['Mask check\nSum / count','Check Cₙ\nRECIP black box','Multiply Sₙ / Cₙ\nConvert / store','Frame-valid check\nRelease output'],
 'For each position n: v[m,n] = NOT mask[m,n]; Sₙ = Σₘ v[m,n]·z[m,n]; Cₙ = Σₘ v[m,n].\nIf Cₙ > 0: logit[n] = QACT(Sₙ × RECIP(Cₙ)). Count and sum always use the SAME valid reads for that position.\nIf any Cₙ = 0: invalidate the whole output frame, report EMPTY_POSITION+n, then return to idle without reset.',
 'Memory access: read logits[M,N] / padding mask[M,N] / buffered final logits[N]');
p5.nodes.find(n=>n.id==='input').label='Read logits z\nand padding mask';p5.nodes.find(n=>n.id==='output').label='Final logits [N]\nonly if frame valid';
fsm('s5-fsm','Stage 5 controller','Stage5_fsm',['Idle','n = 0','Clear Sₙ,Cₙ\nm = 0','Read mask','Read / add z\nif valid','Next read','Check Cₙ','Run reciprocal','Run scale','Write buffered\nlogit','Next position','Mark frame\nvalid','Done'],
 'Masked position skips logit read/add/count. Cₙ=0 branches to Empty-position handling, never to reciprocal.\nNo output is released until all N logits are written and the frame is valid. M=1 uses the same mask-aware rule.',[[5,3,'more reads'],[10,2,'more positions']]);
const sf=pages[pages.length-1];box(sf,'empty',1170,495,260,65,'Cₙ = 0 → empty-frame handler','control');
edge(sf,'empty_branch','s6','empty',[1292,375],[1300,495],[[1445,375],[1445,465],[1300,465]],'control',false,'zero count',[1280,455]);
flow('s5-sum','Sum/count logic — owned by Stage 5','Stage5_sum_count',['NOT mask\nvalid bit','Select add or skip\nlogit / zero','Signed widened\nsum adder','Integer count\nadd valid bit'],
 'A valid position enables BOTH sum and count. A padded position enables neither; never count only wholly unpadded reads.\nSₙ starts at zero with enough signed width for M logits. Cₙ starts at zero and must represent 0..M exactly.\nNo feature quantization applies to count or addresses. The controller advances m after the selected contribution completes.',
 'Memory access: mask_base + mN+n / logit_base + mN+n; increment by N as m advances');
const sum=pages[pages.length-1];sum.edges=sum.edges.filter(e=>e.id!=='data3');
sum.nodes.find(n=>n.id==='b2').label='Signed sum adder\nSₙ ← Sₙ + z\nonly if valid';sum.nodes.find(n=>n.id==='b3').label='Integer count adder\nCₙ ← Cₙ + 1\nonly if valid';
edge(sum,'count_enable','b0','b3',[sum.nodes.find(n=>n.id==='b0').x+80,385],[sum.nodes.find(n=>n.id==='b3').x+80,385],[[sum.nodes.find(n=>n.id==='b0').x+80,435],[sum.nodes.find(n=>n.id==='b3').x+80,435]],'control');
flow('s5-output','Output transfer — owned by frame controller','Stage5_output',['Frame-valid\npermission','Read buffered\nlogit[n]','Output register\nhold value / index','Receiver accepts\nadvance index'],
 'External ready/valid transfer starts only after Stage 5 successful completion. Failure cannot leak earlier buffered positions.\nHold value/index/last stable while ready is low. Advance n only on valid AND ready. Do not discard or duplicate results.\nAfter N accepted logits, hold frame completion until accepted. Read-back stalls use the same transaction interface.',
 'Memory access: final buffered logits[N]; invalid frames have no readout permission');
fsm('s5-output-fsm','Output transfer controller','Stage5_output_fsm',['Idle','Check valid\nn = 0','Read logit','Hold output','Next position','Report frame\ncompletion','Done'],
 'Hold output waits for receiver acceptance; last is true only for n=N−1. Completion follows the last accepted output.\nNo new frame may replace the output bank while readout or completion is pending.',[[4,2,'more positions']]);
fsm('s5-empty-fsm','Stage 5 — recoverable empty-position error','Stage5_empty_fsm',['Empty Cₙ\ndetected','Stop / drain','Invalidate\nwhole frame','Hold error','Idle'],
 'Report EMPTY_POSITION and save the failing n. Do not divide by zero, output zeros, or emit partial logits.\nDo not erase memory: clear its frame-valid flag. After error acceptance the next frame may start without hard reset.\nOther hardware/protocol errors still follow the fatal stop/drain/report/reset policy.');

group=0;
const frame=flow('frame-top','Complete inference core','Architecture_overview',['Stage 1\nInput embedding','Stage 2\nPosition / read','Stage 3\nEncoder × K','Stage 4\nFinal projection','Stage 5\nRead aggregation'],
 'Prepared features + mask → Stage 1 → Stage 2 → Stage 3 → Stage 4 → Stage 5 → buffered valid logits → output transfer.\nEach stage has its own controller and starts only after the previous stage commits its writes. One frame at a time, B = 1.\nShared child diagrams are on their own tabs. Nonlinear arithmetic methods remain black boxes pending review.',
 'Memory access: feature input / learned parameters / working values / saved mask / final output buffer');
frame.nodes.find(n=>n.id==='ctrl').label='Frame controller';frame.nodes.find(n=>n.id==='input').label='Window features\nand padding mask';frame.nodes.find(n=>n.id==='output').label='N final logits\nready / valid';
fsm('frame-fsm','Frame controller','Frame_fsm',['Idle','Load frame\nfeatures /\nmask','Run Stage 1','Run Stage 2','Run Stage 3','Run Stage 4','Run Stage 5','Transfer\nN logits','Hold frame\ncompletion','Done'],
 'Parameters/configuration must be committed before frame acceptance. A failed stage blocks every later stage.\nEmpty position reports a recoverable frame error; other fatal errors drain and require reset. No partial output.');
for(const g of [0,3,4,5])fs.writeFileSync(projectFile(g?`Stage${g}_datapath.drawio`:'Frame_controller.drawio'),'<?xml version="1.0" encoding="UTF-8"?>\n<mxfile host="app.diagrams.net" type="device">'+pages.filter(p=>p.group===g).map(xml).join('\n')+'</mxfile>\n');
for(const p of pages)fs.writeFileSync(projectFile(p.file+'.svg'),svg(p));
const earlier=[1,2].map(g=>fs.readFileSync(projectFile(`Stage${g}_datapath.drawio`),'utf8').match(/<diagram\b[\s\S]*?<\/diagram>/g).join('\n'));
// Earlier numbered references apply within each stage file, not the combined tab order.
const qualifiedEarlier=earlier.map((s,i)=>s.replace(/Page ([2-7])/g,'Stage '+(i+1)+' detail $1'));
fs.writeFileSync(path.join(root,'diagrams/drawio/BCJRFormer_all_stages.drawio'),'<?xml version="1.0" encoding="UTF-8"?>\n<mxfile host="app.diagrams.net" type="device">'+pages.filter(p=>p.group===0).map(xml).join('\n')+'\n'+qualifiedEarlier.join('\n')+'\n'+pages.filter(p=>p.group!==0).map(xml).join('\n')+'</mxfile>\n');
console.log(JSON.stringify({newPages:pages.length,files:['diagrams/drawio/Stage3_datapath.drawio','diagrams/drawio/Stage4_datapath.drawio','diagrams/drawio/Stage5_datapath.drawio','diagrams/drawio/BCJRFormer_all_stages.drawio']}));
