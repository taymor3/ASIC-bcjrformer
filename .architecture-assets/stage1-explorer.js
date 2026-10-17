// Stage 1 refinement. Content is supplied from RTL-specification.md by the updater.
function s1page(id,title,why,input,output,section='overview') {
 page(id,title,why,'',input,output,'','bcjrformer.py',{
  status:'Stage 1 · architecture refinement',stage1:true,detailHtml:stage1Sections[section]||'',
  intro:'Open the blocks below. Dimensions and bit widths remain symbolic.'
 });
}
function s1edge(a,b,label='',type='data'){return {...e(a,b,type),label};}
const s1links=[['embed','Overview'],['s1arith','Arithmetic'],['s1memory','Memory banks'],['s1control','Control paths'],['embedfsm','FSMs'],['s1formats','Number formats']];
s1page('embed','1 · Input embedding','Process one read-position window at a time: normalize F numbers, calculate D weighted sums, normalize D numbers, and store the embedding.','Prepared windows [B,M,N,W,S], B=1; trained Stage 1 parameters','Embedded tokens e[L,D], stored in X for Stage 2');
pages.embed.note='Token = one target position in one read. F=W×S is the number of window values; L=M×N is the number of tokens; D is the model width. The mask stays stored for later stages; Stage 1 processes padded tokens too.';
graph('embed',[
 n('input','reshape',2,1,'Window for token t','F numbers; values unchanged'),
 n('normF','lnf',2,2,'1 · Normalize F','Mean, variance, scale and offset'),
 n('linear','inproj',2,3,'2 · Linear F → D','D weighted sums, each with a bias'),
 n('normD','lnd',2,4,'3 · Normalize D','Same engine, different parameters'),
 n('output',null,2,5,'Write embedding to X','D numbers; then next token','port'),
 n('arithmetic','s1arith',1,1,'Arithmetic view','Basic operations and shared engines'),
 n('memory','s1memory',1,3,'Memory banks','Contents, addresses and lifetimes'),
 n('control','s1control',3,2,'Control paths','Requests, selectors and responses'),
 n('fsm','embedfsm',3,3,'Stage 1 FSMs','Circles, transitions and waits'),
 n('formats','s1formats',3,4,'Number formats','Wide results, rounding, saturation')
],[e('input','normF'),e('normF','linear'),e('linear','normD'),e('normD','output')]);
s1page('reshape','Stage 1 · Window indexing','A token is a position in a read. Its W-by-S window contains F=W×S numbers; we index those same numbers as xₜ[f].','y[B,M,N,W,S], B=1','L=M×N tokens, with F=W×S numbers each');
pages.reshape.formula='t = m×N+n; f = w×S+s. Indexing does not calculate new values.';
s1page('s1arith','Stage 1 · Arithmetic','Three steps in time use a shared normalization engine and a shared dot-product engine.','One F-number window and trained parameters','One D-number embedding','arithmetic');
graph('s1arith',[
 n('input',null,2,1,'Current window x','F stored numbers','port'),
 n('nf','lnf',2,2,'Normalize F','Shared normalization engine'),
 n('lin','inproj',2,3,'Linear F → D','Shared dot/MAC engine'),
 n('nd','lnd',2,4,'Normalize D','Same normalization engine'),
 n('out',null,2,5,'Embedding e','D numbers to X','port'),
 n('params',null,1,3,'Trained parameters','Separate sets for each operation','port'),
 n('scalar','s1scalar',3,2,'Scalar arithmetic','One add/subtract unit + multiplier'),
 n('dot','s1dot',3,3,'Dot-product datapath','Multiply and running sum')
],[e('input','nf'),e('nf','lin'),e('lin','nd'),e('nd','out'),e('params','nf'),e('params','lin'),e('params','nd')]);
for(const [id,J,input,output] of [['lnf','F','Window x[F] in token scratch','Normalized u[F] in the same scratch'],['lnd','D','Linear v[D] in result scratch','Embedding e[D] in the same scratch']]){
 s1page(id,'Stage 1 · Normalize '+J,'Calculate this token’s statistics, then scale each centered value and apply learned gamma and beta.',input,output,'normalization');
 pages[id].note='J='+J+'. All input values stay available until the mean and variance passes finish. The final pass reads each value before overwriting it. The inverse square root remains a black box.';
 graph(id,[
  n('input',null,2,1,'Input token a','J='+J+' stored numbers','port'),
  n('sum','s1add',2,2,'Add inputs into sum','sum ← sum + aᵢ'),
  n('mean','s1multiply',2,3,'Multiply by 1/J','Save mean μ'),
  n('subtract','s1subtract',2,4,'Subtract mean','δᵢ = aᵢ − μ'),
  n('square','s1multiply',2,5,'Multiply δᵢ by itself','Full-width square'),
  n('squares','s1add',2,6,'Add squares into sum','Repeat for all J values'),
  n('variance','s1multiply',2,7,'Multiply by 1/J','Save variance'),
  n('epsilon','s1add',2,8,'Add epsilon','q = variance + ε'),
  n('rsqrt','s1rsqrt',2,9,'Inverse square root','scale = 1 / √q · black box'),
  n('center','s1subtract',2,10,'Read input; subtract mean','Recalculate aᵢ − μ'),
  n('scale','s1multiply',2,11,'Multiply by saved scale','Round to NORM format'),
  n('gamma','s1multiply',2,12,'Multiply by gamma[i]','Learned scale'),
  n('beta','s1add',2,13,'Add beta[i]','Learned offset'),
  n('convert','s1formats',2,14,'Round / saturate / write','Replace feature i; repeat J times'),
  n('constants','s1constants',1,3,'Fixed constants','1/J and epsilon'),
  n('parameters',null,1,12,'Parameter memory','gamma_'+J+', beta_'+J,'port'),
  n('fsm','s1normfsm',3,1,'Normalization FSM','Three vector passes')
 ],[e('input','sum'),e('sum','mean'),e('input','subtract'),e('mean','subtract'),e('subtract','square'),e('square','squares'),e('squares','variance'),e('variance','epsilon'),e('epsilon','rsqrt'),e('input','center'),e('mean','center'),e('rsqrt','scale'),e('center','scale'),e('scale','gamma'),e('gamma','beta'),e('beta','convert'),e('constants','mean'),e('constants','epsilon'),e('parameters','gamma'),e('parameters','beta')]);
}
s1page('inproj','Stage 1 · Linear F → D','For each output j, initialize from its bias, then add F input-times-weight products. Store each result separately from the input.','Normalized u[F]; W[D,F]; b[D]','Linear results v[D] in result scratch','linear');
pages.inproj.formula='v[j] = b[j] + Σ_f W[j,f] × u[f]';
graph('inproj',[
 n('input',null,1,1,'Token scratch u','Keep all F inputs','port'),
 n('parameters',null,3,1,'Parameter memory','W[D,F] and b[D]','port'),
 n('operands','s1registers',2,2,'Capture operand pair','u[f] and W[j,f]'),
 n('mul','s1multiply',2,3,'Multiply','Full product precision'),
 n('sum','s1add',2,4,'Add to running sum','Initially bias[j]; repeat F terms'),
 n('acc','s1registers',3,4,'Accumulator register','Retain result across MAC waits'),
 n('conversion','s1formats',2,5,'Round and saturate','Once per completed output'),
 n('output',null,2,6,'Write result scratch v[j]','Repeat for all D outputs','port'),
 n('fsm','s1linearfsm',3,6,'Linear FSM','Commands dot, converts and writes')
],[e('input','operands'),e('parameters','operands'),e('parameters','sum'),e('operands','mul'),e('mul','sum'),e('sum','acc'),e('acc','sum'),e('sum','conversion'),e('conversion','output')]);
s1page('s1memory','Stage 1 · Memory banks','Two reusable scratch banks hold the current token; X holds completed tokens for Stage 2.','Loaded windows and stable trained parameters','All L×D embeddings stored in X','memory');
graph('s1memory',[
 n('features',null,2,1,'Feature bank','L×F prepared window numbers','port'),
 n('token',null,2,2,'Token scratch','F values: raw x → normalized u','current'),
 n('result',null,2,3,'Result scratch','D values: linear v → normalized e','current'),
 n('x',null,2,4,'Working X bank','L×D finished embeddings','port'),
 n('params',null,1,2,'Parameter memory','D×F + 2F + 3D values','port'),
 n('mask',null,3,4,'Mask bank','L bits; unchanged by Stage 1','mask'),
 n('registers','s1registers',3,2,'Small registers','Statistics, operands and counters'),
 n('copy','s1copyfsm',1,4,'Copy FSM','Load window / store embedding')
],[e('features','token'),e('token','result'),e('result','x')]);
pages.s1memory.note='Arrows show storage handoffs over time. Banks hold values; calculation engines perform normalization and projection. F/D are the entries used here, not final allocations for scratch shared with later stages.';
s1page('s1control','Stage 1 · Control paths','The controller chooses one active helper, routes its memory requests and waits for completion before changing ownership.','Start command, memory responses and arithmetic responses','Memory/arithmetic commands and held completion','control');
graph('s1control',[
 n('parent',null,2,1,'Frame controller','Start / completion acceptance','port'),
 n('stage','embedfsm',2,2,'Stage 1 controller','Choose copy, normalization or linear'),
 n('copy','s1copyfsm',1,3,'Copy helper','Source → destination'),
 n('norm','s1normfsm',2,3,'Normalization helper','F or D; correct parameter bases'),
 n('linear','s1linearfsm',3,3,'Linear helper','F inputs; D outputs'),
 n('mux','s1selector',2,4,'Memory request selector','Bank, address, read/write and data'),
 n('banks','s1memory',2,5,'Memory banks','Response returns to its requester'),
 n('scalar','s1scalar',1,6,'Scalar operations','Add/subtract and multiply'),
 n('sqrt','s1rsqrt',2,6,'Inverse square root','Request / response black box'),
 n('dot','s1dot',3,6,'Dot engine','Linear commands; one MAC at a time')
],[e('parent','stage','mask'),e('stage','copy','mask'),e('stage','norm','mask'),e('stage','linear','mask'),e('copy','mux','mask'),e('norm','mux','mask'),e('linear','mux','mask'),e('mux','banks','mask'),e('norm','scalar','mask'),e('norm','sqrt','mask'),e('linear','dot','mask'),e('dot','mux','mask')]);
pages.s1control.note='Yellow dashed arrows are control/request paths. Responses travel back to the controller that issued the operation. Only one helper is active. ISSUE waits for acceptance; WAIT captures one response.';
function s1fsm(id,title,states,edges){
 s1page(id,title,'States issue work once, wait for completion, then advance the relevant counter.','Saved command and accepted responses','Held completion or fatal error','fsm');
 pages[id].fsmView=true;
 graph(id,states.map(([label,sub],i)=>n('s'+i,null,2,i+1,label,sub,'current')),edges.map(([a,b,label])=>s1edge('s'+a,'s'+b,label)));
}
s1fsm('embedfsm','Stage 1 · Main FSM',[
 ['IDLE','Accept start'],['INIT','t=0; initialize token pointers'],['LOAD_TOKEN','Copy F values into token scratch'],['NORMALIZE_F','Issue once; wait for completion'],['LINEAR','Issue F→D; wait for D writes'],['NORMALIZE_D','Issue once; wait for completion'],['STORE_TOKEN','Copy D values into X'],['CHECK_LAST_TOKEN','t compared with L−1'],['DONE','Hold completion until accepted']
],[[0,1,'start accepted'],[1,2],[2,3,'copy done'],[3,4,'normalization done'],[4,5,'linear done'],[5,6,'normalization done'],[6,7,'copy done'],[7,2,'more tokens: advance t'],[7,8,'last token'],[8,0,'completion accepted']]);
s1fsm('s1copyfsm','Stage 1 · Copy FSM',[
 ['IDLE','Accept source, destination and length'],['INIT_COPY','index=0'],['READ_ISSUE','Hold read until accepted'],['READ_WAIT','Capture returned value'],['WRITE_ISSUE','Hold write until accepted'],['WRITE_WAIT','Wait for confirmed write'],['CHECK_LAST','Compare index with length−1'],['DONE','Hold completion']
],[[0,1,'command accepted'],[1,2],[2,3,'request accepted'],[3,4,'response accepted'],[4,5,'request accepted'],[5,6,'write confirmed'],[6,2,'more: advance index'],[6,7,'last value'],[7,0,'completion accepted']]);
s1fsm('s1normfsm','Stage 1 · Normalization FSM',[
 ['IDLE','Accept J=F or D and parameter bases'],['INIT_NORM','Clear sum; i=0'],['SUM_PASS','Read, add; repeat J inputs'],['MEAN','sum × 1/J; clear square sum; i=0'],['VARIANCE_PASS','Read, subtract, square, add; repeat J'],['VARIANCE_SCALE','square sum × 1/J; add epsilon'],['RSQRT_ISSUE','Hold one request until accepted'],['RSQRT_WAIT','Capture scale; i=0'],['OUTPUT_PASS','Read, center, scale, gamma, beta, convert, write'],['DONE','J replacement writes confirmed']
],[[0,1,'command accepted'],[1,2],[2,2,'more inputs'],[2,3,'J inputs summed'],[3,4],[4,4,'more inputs'],[4,5,'J squares summed'],[5,6],[6,7,'request accepted'],[7,8,'response accepted'],[8,8,'more features'],[8,9,'last write confirmed'],[9,0,'completion accepted']]);
s1fsm('s1linearfsm','Stage 1 · Linear FSM',[
 ['IDLE','Accept I=F, O=D and bank bases'],['INIT_LINEAR','j=0; first weight row'],['READ_BIAS','Request/wait; align bias format'],['DOT_ISSUE','Length F; bias included once'],['DOT_WAIT','Capture widened sum'],['CONVERT','Nearest-even rounding; saturation'],['WRITE','Request/wait for result[j]'],['CHECK_LAST_OUTPUT','Compare j with D−1'],['DONE','D writes confirmed']
],[[0,1,'command accepted'],[1,2],[2,3,'bias received'],[3,4,'command accepted'],[4,5,'result accepted'],[5,6],[6,7,'write confirmed'],[7,2,'more outputs: advance j'],[7,8,'last output'],[8,0,'completion accepted']]);
s1fsm('s1dotfsm','Stage 1 · Dot FSM',[
 ['IDLE','Accept length, operands and initial sum'],['INIT_DOT','r=0; accumulator=bias'],['READ_A','Request/wait; capture input'],['READ_B','Request/wait; capture weight'],['MAC_ISSUE','Request accumulator + A×B'],['MAC_WAIT','Save returned accumulator'],['CHECK_LAST_TERM','Compare r with F−1'],['DONE','Hold widened sum']
],[[0,1,'command accepted'],[1,2],[2,3,'input received'],[3,4,'weight received'],[4,5,'request accepted'],[5,6,'response accepted'],[6,2,'more terms: advance r'],[6,7,'last term'],[7,0,'result accepted']]);
for(const id of ['embedfsm','s1copyfsm','s1normfsm','s1linearfsm','s1dotfsm']){
 pages[id].nodes.push(n('error',null,1,pages[id].nodes.length-1,'FATAL ERROR','Stop new work; finish accepted transactions; report failure; reset required','mask'));
 const responseState={embedfsm:3,s1copyfsm:3,s1normfsm:7,s1linearfsm:4,s1dotfsm:5}[id];
 pages[id].edges.push(s1edge('s'+responseState,'error','any failed response','mask'),s1edge('error','s0','reset','mask'));
 pages[id].note='Any failed memory/arithmetic response takes the fatal-error path. Partial frame results are invalid; Stage 2 cannot start. Helper pass states expand to request/wait steps listed in the table. Counters advance only after the required response/write confirmation.';
}
s1page('s1formats','Stage 1 · Number formats','Retain wide sums and products. Convert only at the defined boundaries; choose actual bit counts later.','Stored ACT/PAR values and wider intermediate results','Stored ACT results; rounded/saturated/error flags','formats');
graph('s1formats',[
 n('input',null,2,1,'Stored numbers','ACT_W/ACT_P; PAR_W/PAR_P','port'),
 n('wide',null,2,2,'Full products and wide sums','Keep fractional precision','current'),
 n('round',null,2,3,'Round to nearest, ties to even','At the defined conversion boundary','current'),
 n('sat',null,2,4,'Check output range','Clip stored activations if needed','current'),
 n('stored',null,2,5,'Store ACT-format result','Preserve separate flags','port'),
 n('overflow',null,3,2,'Intermediate overflow','Fatal numeric error; never wrap','mask')
],[e('input','wide'),e('wide','round'),e('round','sat'),e('sat','stored'),e('wide','overflow','mask')]);
const s1ops={
 s1add:['Adder','Add the selected operands. A running sum is cleared before its pass and updated only after the operation completes.','Two aligned numbers','Wider sum'],
 s1subtract:['Subtractor','Subtract the saved mean from the current input. Align fractional bits and retain room for the difference.','Current input and mean','Centered difference'],
 s1multiply:['Multiplier','Multiply two selected numbers. Keep the full product; rounding occurs only at an explicitly defined boundary.','Two operands','Full-width product'],
 s1selector:['Selector / multiplexer','Choose one request or operand source. Hold the selected source while its operation is pending.','Active-helper selection and candidate requests','One bank/address/read-write/data request'],
 s1rsqrt:['Inverse-square-root black box','Calculate scale=1/√q once per token. The method, bit counts, input range and error target remain to be selected.','q = variance + epsilon, VAR format','Scale, RSQRT format; completion/error'],
 s1constants:['Fixed constants','Prepare 1/F, 1/D and epsilon before inference. They are not trained weights. Reject a format that rounds any required constant to zero.','Selected dimensions and constant formats','Stored 1/F, 1/D and epsilon'],
 s1registers:['Registers','Hold the current operands, intermediate result, statistics, counters and pending request until their next accepted update.','Register load/clear controls and returned values','Saved values available across waits']
};
for(const [id,[title,why,input,output]] of Object.entries(s1ops))s1page(id,'Stage 1 · '+title,why,input,output,'arithmetic');
pages.s1rsqrt.status='Stage 1 · black box';pages.s1rsqrt.detailHtml=stage1Sections.formats;
pages.s1registers.detailHtml=stage1Sections.memory;
s1page('s1scalar','Stage 1 · Scalar datapath','Normalization reuses one add/subtract unit and one multiplier. A selector chooses operands and a register saves each accepted result.','Current input, mean, statistics, constants, scale, gamma/beta','Saved statistics and normalized feature','control');
graph('s1scalar',[n('operands',null,2,1,'Saved operands','Inputs, statistics, constants, parameters','port'),n('sel','s1selector',2,2,'Operand selectors','Controller chooses two numbers'),n('add','s1add',1,3,'Add / subtract','Controller selects operation'),n('mul','s1multiply',3,3,'Multiply','Full-width result'),n('reg','s1registers',2,4,'Result register','Load after accepted completion')],[e('operands','sel'),e('sel','add'),e('sel','mul'),e('add','reg'),e('mul','reg')]);
s1page('s1dot','Stage 1 · Dot-product datapath','The same engine accumulates each output’s F products. Bias initializes the sum once.','Input/weight operands and initial bias','Widened sum; no destination write','linear');
graph('s1dot',[n('operands','s1registers',2,1,'Operand registers A and B','Sequential memory reads'),n('mul','s1multiply',2,2,'Multiply A×B','Full product'),n('acc','s1registers',1,3,'Running sum','Initially aligned bias'),n('add','s1add',2,3,'Add product to running sum','Save after MAC completion'),n('out',null,2,4,'Return widened sum','After F terms','port'),n('fsm','s1dotfsm',3,1,'Dot FSM','Request / wait / next term')],[e('operands','mul'),e('mul','add'),e('acc','add'),e('add','acc'),e('add','out')]);
function renderStage1Details(p,key){
 if(!p.stage1)return;
 const actions=document.createElement('nav');actions.className='s1-actions';actions.setAttribute('aria-label','Stage 1 views');
 for(const [id,label] of s1links){const b=document.createElement('button');b.type='button';b.textContent=label;b.setAttribute('aria-current',String(key===id));b.onclick=()=>open(id);actions.append(b);}
 details.append(actions);
 if(p.formula){const formula=document.createElement('div');formula.className='formula';formula.textContent=p.formula;details.append(formula);}
 const explanation=document.createElement('div');explanation.className='s1-spec';explanation.innerHTML=p.detailHtml;details.append(explanation);
 const source=document.createElement('p');source.className='s1-source';source.textContent='Stage 1 detail source: RTL-specification.md. Other stages and the full-document view retain their earlier draft until reviewed.';details.append(source);
 // The current Stage 1 material is directly below; avoid directing readers to an older paper for it.
 for(const link of details.querySelectorAll('a[href="#document"]'))link.parentElement.remove();
}
