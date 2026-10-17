// Review-draft extension. No arithmetic implementation is claimed by these diagrams.
function control(id,title,states,description,note,loops=[]) {
 sketch(id,title,description,'Command descriptor; memory and unit responses','Committed results; completion response','Draft FSM · review baseline');
 graph(id,states.map(([label,sub],i)=>n('s'+i,null,2,i+1,label,sub,'current')),
 states.slice(1).map((_,i)=>e('s'+i,'s'+(i+1))).concat(loops.map(([a,b])=>e('s'+a,'s'+b))));
 pages[id].note=note+' All requests wait for ready; all results wait for completion. Counters advance only on accepted work. Error and reset behavior follow the RTL specification.';
}
function linkControl(id,fsm,label='Controller / FSM') {pages[id].nodes ??= [n('input',null,2,1,'Input',pages[id].input,'port'),n('operation',null,2,2,pages[id].title,'Logical operation','current'),n('output',null,2,3,'Output',pages[id].output,'port')];pages[id].edges ??= [e('input','operation'),e('operation','output')];pages[id].nodes.push(n('controller',fsm,3,1,label,'Open draft states'));}
sketch('mha','Self-attention · sequential datapath','Build Q, K and V for every token. Process one head/query row at a time, then project the joined head results. One matrix engine is shared.','Normalized U [L,D]; mask [1,1,L,1] for B=1','Attention update O [L,D] → first residual addition');
graph('mha',[n('in',null,2,1,'LayerNorm 1 tokens U','[L,D]','port'),n('qkv','qkv',2,2,'Q / K / V projections','Distinct weights and biases'),n('scores','scores',2,3,'QKᵀ and scale','One query row [L]'),n('mask',null,1,4,'Padding / optional static mask','Source-compatibility policy','mask'),n('sm','softmax',2,4,'Mask and softmax','Probability row [L]'),n('v',null,3,3,'Stored V','[L,D] · bypasses scores','port'),n('wv','weighted',2,5,'Weighted values','One head output [d]'),n('join',null,2,6,'Write joined heads Z','Address map [L,D]','current'),n('proj','linear',2,7,'Output projection','D → D with bias'),n('out',null,2,8,'Attention output','O [L,D]','port')],[e('in','qkv'),e('qkv','scores'),e('qkv','v'),e('scores','sm'),e('mask','sm','mask'),e('sm','wv'),e('v','wv'),e('wv','join'),e('join','proj'),e('proj','out')]);
pages.mha.note='Source padding masks QUERY ROWS. Padded queries get uniform probability rows; valid queries still see padded keys. Correcting to key masking requires explicit approval and a changed reference.';
sketch('qkv','Q / K / V projections','Run three linear(D,D) operations per token, with independent W and b. Store all tokens before computing attention scores.','U [L,D]; WQ,bQ,WK,bK,WV,bV','Q,K,V [L,D]; head address = t*D+a*d+r');
graph('qkv',[n('in',null,2,1,'Normalized U','Shared input token','port'),n('q','linear',1,2,'Q projection','WQ,bQ'),n('k','linear',2,2,'K projection','WK,bK'),n('v','linear',3,2,'V projection','WV,bV'),n('qo',null,1,3,'Q memory','To score dot product','port'),n('ko',null,2,3,'K memory','To score dot product','port'),n('vo',null,3,3,'V memory','To weighted values','port')],[e('in','q'),e('in','k'),e('in','v'),e('q','qo'),e('k','ko'),e('v','vo')]);
sketch('scores','Query–key scores and scaling','For head a and query i, loop over key j. Dot Q[i,a,:] with K[j,a,:] over d terms, then multiply by 1/sqrt(d).','Q/K banks; head a, query i, key j','One widened score row S[L]');
linkControl('scores','dotfsm','Shared dot engine');
sketch('weighted','Attention-weighted values','For each head component r, accumulate probability[j]*V[j,a,r] over all L keys. Write Z[i,a*d+r].','Probability row [L]; V bank','One head output [d], then joined Z [L,D]');
linkControl('weighted','dotfsm','Shared dot engine');
sketch('softmax','Mask and row softmax','Subtract the row maximum, exponentiate, sum and normalize. The source-compatible fully masked-row path writes 1/L directly.','Widened score row [L]; mask tags','Probability row [L]');
graph('softmax',[n('in',null,2,1,'Score row + mask tags','[L]','port'),n('max',null,2,2,'Row maximum','Reduce over key j','current'),n('exp','exp',2,3,'Subtract max and exp','Store exponentials'),n('sum',null,2,4,'Sum exponentials','Widened positive sum','current'),n('recip','reciprocal',2,5,'Reciprocal of sum','One request per row'),n('out',null,2,6,'Normalize and write','P[j] = exp[j] / sum','current')],[e('in','max'),e('max','exp'),e('exp','sum'),e('sum','recip'),e('recip','out')]);
pages.softmax.nodes.push(n('saved',null,3,4,'Saved exponentials','One row [L]','port'),n('uniform',null,1,5,'Uniform-row bypass','P[j] = stored 1/L','port'));
pages.softmax.edges.push(e('exp','saved'),e('saved','out'),e('in','uniform','mask'),e('uniform','out'));
pages.softmax.note='Normal path: NORMALIZE reads both the saved exponential and reciprocal. Fully sentinel-filled row: uniform bypass. Invalid sum raises error. Static-mask support is optional and must be agreed with the target configuration; do not silently implement key masking.';
sketch('linear','Shared linear controller','For output j: load bias, accumulate I products, round/saturate and write. Repeat for O outputs.','Vector [I], W[O,I], b[O]; bases and lengths','Vector [O]');
control('linearfsm','Linear · FSM',[['INIT_OUTPUT','j=0'],['READ_BIAS','Initialize accumulator'],['DOT_COMMAND','I products'],['DOT_WAIT','Wait for dot completion'],['ROUND_SATURATE','Declared destination format'],['WRITE','Commit output j'],['NEXT_OUTPUT','j+1<O: loop; else done'],['DONE','Hold completion until accepted']], 'One dot command at a time, with stored weights in W[out,in] order.','NEXT_OUTPUT returns to READ_BIAS while j+1<O.',[[6,1]]);
linkControl('linear','linearfsm');
control('dotfsm','Dot engine · FSM',[['INIT_ACC','Capture mode and initial sum'],['READ_A','Wait and capture operand A'],['READ_B','Wait and capture operand B'],['MAC_ISSUE','Issue one multiply-accumulate'],['MAC_WAIT','Wait for result'],['NEXT_TERM','i+1<I: loop'],['DONE','Return widened accumulator']], 'Sequential reads work with single-port memories. Operand registers survive arithmetic latency.','NEXT_TERM returns to READ_A while i+1<I. Signed16×signed16 and unsigned24×signed16 have separate binary-point modes.',[[5,1]]);
control('attnfsm','Self-attention · FSM',[['PROJ_Q_ALL','L tokens'],['PROJ_K_ALL','L tokens'],['PROJ_V_ALL','L tokens'],['INIT_HEAD_QUERY','a=0, i=0'],['SCORE_ROW','Loop j<L; each dot has d terms'],['SOFTMAX_ROW','Wait for complete probability row'],['WEIGHTED_VALUES','Loop r<d; each dot has L terms'],['NEXT_QUERY_HEAD','Increment i; wrap and increment a'],['OUTPUT_PROJECTION','L linear(D,D) commands'],['DONE','All output writes committed']], 'Finish all Q/K/V first. Store one score/probability row and all joined outputs.','NEXT_QUERY_HEAD returns to SCORE_ROW until every query in every head completes. Then run OUTPUT_PROJECTION.',[[7,4]]);
linkControl('mha','attnfsm');
control('softmaxfsm','Softmax · FSM',[['CHECK_MASK_ROW','Fully filled: uniform bypass'],['READ_ROW_MAX','Loop j<L'],['EXP_AND_SUM','Loop j<L; store exp'],['RECIPROCAL','Wait for positive-sum reciprocal'],['NORMALIZE_ROW','Loop j<L; write probabilities'],['DONE','Committed row']], 'Each scalar primitive uses request/response, with explicit widened buffers.','Fully masked CHECK_MASK_ROW writes the uniform row through NORMALIZE_ROW without max/exp/reciprocal. Zero or invalid sum follows the error path.',[[0,4]]);
linkControl('softmax','softmaxfsm');
control('corefsm','Core · frame FSM',[['IDLE','Committed parameters required'],['LOAD_FEATURES','L*F accepted values'],['LOAD_MASK','L accepted bits'],['EMBED','Wait for all L tokens'],['POSITION','Wait for L*D additions'],['ENCODER','Wait for K layers'],['FINAL','Produce L logits'],['AGGREGATE','Produce N logits'],['OUTPUT','Transfer N logits with ready/valid'],['COMPLETE','Hold status until accepted']], 'One frame is active at a time. Host packet counts and last markers are checked.','COMPLETE returns to IDLE after response acceptance. Reset invalidates frame and parameter-valid state.',[[9,0]]);
linkControl('core','corefsm');
control('encoderfsm','Encoder · layer-loop FSM',[['INIT_LAYER','k=0; parameter bases'],['RUN_LAYER','Issue one layer command'],['WAIT_LAYER','All outputs committed'],['NEXT_LAYER','k+1<K: update bases and repeat'],['DONE','Final X [L,D] ready']], 'Reuse one hardware layer engine across distinct learned parameter sets.','NEXT_LAYER returns to RUN_LAYER while k+1<K.',[[3,1]]);
linkControl('encoder','encoderfsm');
control('layerfsm','Layer · scheduling FSM',[['LN1_ALL_TOKENS','Preserve original X'],['ATTENTION','Compute all O tokens'],['RESIDUAL1_ALL','X becomes r after reads complete'],['LN2_TOKEN','Normalize r[t]'],['FFN_TOKEN','Preserve r[t]'],['RESIDUAL2_TOKEN','Write completed X[t]'],['NEXT_TOKEN','t+1<L: repeat'],['DONE','Whole layer committed']], 'Run first normalization and attention frame-wide, then the FFN branch token by token.','NEXT_TOKEN returns to LN2_TOKEN while t+1<L. Do not overwrite original X before attention residual operands are captured.',[[6,3]]);
linkControl('layer','layerfsm');
control('embedfsm','Input embedding · FSM',[['LOAD_TOKEN','t=0; F values'],['LN_F','First normalization parameters'],['LINEAR_F_TO_D','Projection weights and bias'],['LN_D','Second normalization parameters'],['WRITE_TOKEN','D values to X'],['NEXT_TOKEN','t+1<L: repeat'],['DONE','Stage 1 complete']], 'Subcommands complete before scratch reuse. Each normalization has its own gamma and beta.','NEXT_TOKEN returns to LOAD_TOKEN while t+1<L.',[[5,0]]);
linkControl('embed','embedfsm');
control('positionfsm','Position and sequence · FSM',[['INIT','t=0, i=0'],['READ_X','Capture token feature'],['READ_P','P[n,i], n=t mod N'],['ADD_P','Add and narrow'],['READ_E','E[m,i], m=floor(t/N)'],['ADD_E','Add and narrow'],['WRITE','Commit feature'],['NEXT_FEATURE_TOKEN','Advance i, then t'],['DONE','L*D writes complete']], 'Read trained embedding tables. Preserve the two software additions as separate quantized operations.','NEXT_FEATURE_TOKEN returns to READ_X until all L*D features are written.',[[7,1]]);
linkControl('position','positionfsm');
control('finalfsm','Final projection · FSM',[['INIT_TOKEN','t=0'],['LINEAR_D_TO_1','Final weights and bias'],['STORE_LOGIT','Commit z[t]'],['NEXT_TOKEN','t+1<L: repeat'],['DONE','L logits ready']], 'Binary target q=2 produces one score per token.','NEXT_TOKEN returns to LINEAR_D_TO_1 while t+1<L.',[[3,1]]);
linkControl('final','finalfsm');
control('aggregatefsm','Aggregation · FSM',[['SELECT_PATH','M=1: copy logits directly'],['COUNT_VALID_SLOTS','C counts fully unpadded slots'],['CHECK_COUNT','C=0: error'],['INIT_POSITION','n=0'],['SUM_READS','Loop m<M; skip masked entries'],['DIVIDE','Scale by 1/C'],['WRITE','Commit output[n]'],['NEXT_POSITION','n+1<N: repeat'],['DONE','N outputs committed']], 'M>1 follows the software numerator and denominator. M=1 bypasses masking/averaging.','SELECT_PATH with M=1 copies all N values then DONE. NEXT_POSITION returns to SUM_READS while n+1<N. Partial padding policy is a review decision.',[[7,4],[0,8]]);
linkControl('aggregate','aggregatefsm');
control('residualfsm','Residual add · FSM',[['READ_LEFT','Capture saved residual'],['READ_RIGHT','Capture branch result'],['ADD_WIDEN','Preserve range'],['ROUND_SATURATE','Destination format'],['WRITE','Commit feature'],['NEXT_INDEX','i+1<D: repeat'],['DONE','D sums committed']], 'Only overwrite a residual address after both operands are captured.','NEXT_INDEX returns to READ_LEFT while i+1<D.',[[5,0]]);
linkControl('res1','residualfsm');linkControl('res2','residualfsm');
const contracts={
 exp:['Exponential primitive','Input <=0. On [-16,0], proposed absolute error <=2^-20; below -16 return zero. exp(0)=1.','Signed48/20 scalar','Unsigned24/22 result'],
 reciprocal:['Reciprocal primitive','Positive denominator [1,65535]. Proposed relative error <=2^-12 plus one output LSB. Zero is an error.','Unsigned64/22 denominator','Unsigned40/32 result'],
 invsqrt:['Inverse-square-root primitive','Domain [quantized 1e-5,4096]. Proposed relative error <=2^-12. Invalid input raises error.','Unsigned48/32 variance + epsilon','Unsigned32/20 result'],
 gelu:['GELU primitive','Signed16/10 input. Proposed absolute error <=2^-9; tails below -8 return zero and above 8 return input.','Signed16/10 scalar','Signed16/10 result']
};
for(const [id,[title,why,input,output]] of Object.entries(contracts)){sketch(id,title,why,input,output,'Bounded contract · implementation open');pages[id].note='Proposed acceptance target, not a measured guarantee. One request outstanding; result held until accepted. Optional 1024-cycle watchdog excludes output backpressure. See RTL draft for formats and errors.';}
pages.mac.why='One physical dot engine with 64-bit accumulation supports standard signed16 products and unsigned24 probability × signed16 value products. Mode-specific formats, rounding and overflow checks are defined in the RTL draft.';
linkControl('mac','dotfsm');
pages.buffers.why='Separate banks hold X, U, Q/K/V, Z, attention outputs, token scratch, FFN hidden values and one score/exp/probability row. Single-port adapters serialize reads; residual lifetimes are preserved.';
pages.weights.why='Sequential host loading and a parameter manifest define row-major W[out,in], biases, embedding tables and per-layer normalization parameters. Only the active controller owns reads.';
pages.lnfsm.note='Issue/wait substates use ready/valid, one outstanding request and stable stalled payloads. Loop V=F or D. The widened variance path preserves epsilon. See the RTL draft for exact formats and completion rules.';
pages.ffnfsm.note='Complete 4D first-linear/GELU values before second linear. Loop j<4D and k<D; every read, MAC, primitive and write waits for acceptance/completion. Saved residual r is outside shared scratch.';
pages.layer.nodes.find(node=>node.id==='attn').sub='Open sequential datapath';
pages.encoder.note='One physical layer engine is proposed for N_dec sequential layers with distinct parameter bases. This is a draft choice for review.';
pages.ffn.note='Two logical linear boxes share one physical dot engine. The layer controller waits for the complete FFN token, then launches residual addition. Each response follows committed writes; cycle latency depends on the selected units.';
pages.qkv.note='The three branches show logical dependencies, not parallel hardware. Schedule all Q tokens, then all K tokens, then all V tokens with the shared engine.';
pages.core.nodes.find(node=>node.id==='enc').sub='Open layer, attention, normalization and FFN';

// Joint review, 24 September: explicit transaction states and controller hierarchy.
control('dotfsm','Dot engine · FSM',[
 ['IDLE','Accept one immutable descriptor'],['INIT_ACC','term=0; aligned bias or zero'],
 ['READ_INPUT_REQ','Hold request until accepted'],['READ_INPUT_WAIT','Capture operand A on response'],
 ['READ_WEIGHT_REQ','Hold request until accepted'],['READ_WEIGHT_WAIT','Capture operand B on response'],
 ['ISSUE_MAC','Request accumulator + A × B'],['WAIT_MAC','Capture updated accumulator'],
 ['NEXT_TERM','More terms: increment and loop'],['DONE','Hold widened result until accepted']
], 'One multiply-accumulate at a time. READ_WEIGHT names operand B: it can be a weight, K feature, or V feature.','NEXT_TERM loops to READ_INPUT_REQ while term+1<length; otherwise DONE. DONE returns to IDLE only on result acceptance. No request is issued twice.',[[8,2],[9,0]]);
control('linearfsm','Linear · FSM',[
 ['IDLE','Accept token and parameter bases'],['INIT_OUTPUT','j=0'],['READ_BIAS_REQ','Wait for request acceptance'],
 ['READ_BIAS_WAIT','Capture bias; align binary point'],['DOT_COMMAND','Length I; source and weight row'],
 ['DOT_WAIT','Capture widened result'],['ROUND_SATURATE','Observe before/after and flags'],
 ['WRITE_REQ','Hold output address/data'],['WRITE_WAIT','Wait for committed write'],
 ['NEXT_OUTPUT','j+1<O: increment and loop'],['DONE','Hold token completion']
], 'The input vector survives all output dot products. The linear controller owns rounding and destination writes.','NEXT_OUTPUT loops to READ_BIAS_REQ while j+1<O. DONE returns to IDLE on response acceptance.',[[9,2],[10,0]]);
control('qkvfsm','Q/K/V projection · FSM',[
 ['IDLE','All LayerNorm 1 tokens stored'],['INIT','projection=Q; t=0'],
 ['ISSUE_LINEAR','D→D; selected parameters and bank'],['WAIT_LINEAR','All D token writes committed'],
 ['NEXT_TOKEN','t+1<L: increment and repeat'],['NEXT_PROJECTION','Q→K→V; reset t=0'],['DONE','Last V write committed']
], 'One outer controller selects projection and token; linear selects output feature; dot selects input term.','NEXT_TOKEN loops to ISSUE_LINEAR while more tokens remain. NEXT_PROJECTION selects K or V and loops to ISSUE_LINEAR; after V it enters DONE. DONE holds completion until accepted.',[[4,2],[5,2],[6,0]]);
linkControl('qkv','qkvfsm');
control('scorefsm','Score row · FSM',[
 ['IDLE','Latch head a and query i'],['INIT_KEY','j=0'],['ISSUE_DOT','Length d; initial sum zero'],
 ['WAIT_DOT','Capture QK sum'],['ISSUE_SCALE','Multiply by stored 1/sqrt(d)'],
 ['WAIT_SCALE','Capture scaled result'],['WRITE_SCORE','Convert; request and await commit'],
 ['NEXT_KEY','j+1<L: increment and repeat'],['DONE','Complete score row stored']
], 'Reuse the dot engine over contiguous head slices, then use widened scalar scaling.','NEXT_KEY loops to ISSUE_DOT until all L keys complete. Scaling is a precomputed constant, not a runtime square root. WRITE_SCORE contains request/wait substates. DONE holds completion until accepted.',[[7,2],[8,0]]);
pages.scores.nodes.find(v=>v.id==='controller').key='scorefsm';
pages.scores.nodes.find(v=>v.id==='controller').label='Score-row FSM';
pages.scores.nodes.push(n('dot','dotfsm',1,2,'Shared dot engine','Length d; zero initial sum'));
pages.scores.note='Q base = Q_base+iD+ad; K base = K_base+jD+ad; both strides 1. Store scores wide. The same head/query remains selected through softmax and weighted values.';
control('weightedfsm','Weighted values · FSM',[
 ['IDLE','Latch head a and query i'],['INIT_FEATURE','r=0'],['ISSUE_DOT','Length L; initial sum zero'],
 ['WAIT_DOT','Capture probability × V sum'],['ROUND_SATURATE','Convert and expose trace flags'],
 ['WRITE_RESULT','Request write; wait for commitment'],['NEXT_FEATURE','r+1<d: increment and repeat'],['DONE','One query/head complete']
], 'Probability operand stride 1; V operand stride D. Use unsigned-probability × signed-value mode.','NEXT_FEATURE loops to ISSUE_DOT until d outputs commit. Keep the probability row unchanged throughout. Destination = Z_base+iD+ad+r. No bias or additional scale.',[[6,2],[7,0]]);
pages.weighted.nodes.find(v=>v.id==='controller').key='weightedfsm';
pages.weighted.nodes.find(v=>v.id==='controller').label='Weighted-value FSM';
pages.weighted.nodes.push(n('dot','dotfsm',1,2,'Shared dot engine','Strides 1 and D'));
pages.weighted.note='Input A = probability_base, stride 1. Input B = V_base+ad+r, stride D. Only after all d writes may attention advance the query and reuse row scratch.';
control('softmaxfsm','Softmax · FSM',[
 ['IDLE','Accept row and query-padding flag'],['CHECK_MASK','Select normal or uniform mode'],
 ['FIND_MAX','Normal mode: read all L scores'],['EXP_AND_SUM','Store exp values; accumulate sum'],
 ['RECIPROCAL','Wait for 1/sum'],['PREPARE_VALUE','normal: exp[j]/sum; uniform: 1/L'],
 ['WRITE_PROBABILITY','One shared request/wait write path'],['NEXT_ENTRY','j+1<L: increment and repeat'],['DONE','L probability writes committed']
], 'Uniform mode bypasses maximum, exponential and reciprocal calculation. It is not a second write pass.','CHECK_MASK goes directly to PREPARE_VALUE for a padded query, with j=0 and uniform mode. Normal mode enters PREPARE_VALUE with j=0 after RECIPROCAL. NEXT_ENTRY loops to PREPARE_VALUE. Scalar requests wait for acceptance/results; nonpositive sum is an error.',[[1,5],[7,5],[8,0]]);
pages.softmax.nodes.find(v=>v.id==='out').label='Select value and write';
pages.softmax.nodes.find(v=>v.id==='out').sub='Normal probability OR stored 1/L';
sketch('outproj','Attention output projection','Mix joined head features using learned WO and bO. Reuse the shared linear controller for every token.','Joined Z [L,D]; WO[D,D], bO[D]','O [L,D] → add saved original X');
graph('outproj',[n('in',null,2,1,'Joined Z','No physical head-copy stage','port'),n('linear','linear',2,2,'Shared D→D linear','WO and bO'),n('out',null,2,3,'Attention update O','All L tokens stored','port'),n('res','res1',2,4,'First residual addition','Original X + O, not U + O')],[e('in','linear'),e('linear','out'),e('out','res')]);
control('outprojfsm','Attention output projection · FSM',[
 ['IDLE','All heads/queries stored in Z'],['INIT_TOKEN','i=0'],['ISSUE_LINEAR','Z token → O token; WO,bO'],
 ['WAIT_LINEAR','Wait for D committed writes'],['NEXT_TOKEN','i+1<L: increment and repeat'],['DONE','Full attention output committed']
], 'No dropout in inference. One physical linear/dot engine is reused.','NEXT_TOKEN loops to ISSUE_LINEAR until all L tokens complete. DONE holds response until accepted; only then may the layer start its first residual pass.',[[4,2],[5,0]]);
linkControl('outproj','outprojfsm');pages.mha.nodes.find(v=>v.id==='proj').key='outproj';
sketch('numerictrace','Numeric snapshots · verification plan','Observe existing conversion events without adding computation states. Compare float Python, the wide fixed-point intermediate, and the stored fixed-point result.','Before/after values, formats, location and valid event','Simulation trace; rounding/saturation/overflow flags','Agreed observation plan · not implemented');
pages.numerictrace.note='Wide fixed-point results are not the float reference: earlier quantization may already differ. Capture once per accepted event, never repeatedly during a stall. Optional on-chip capture needs bounded storage and a readout interface; it must not stall compute in the baseline. No wide-result bypass is assumed.';
pages.linear.nodes.push(n('trace','numerictrace',1,1,'Numeric snapshots','Observe, do not alter results'));
pages.weighted.nodes.push(n('trace','numerictrace',1,3,'Numeric snapshots','Before/after conversion'));
pages.buffers.note='Logical banks are not a floorplan or a promise of one SRAM macro each. Q/K/V alone require 3LDw bits. Confirm target library/macros, total capacity, ports, bandwidth and rough locality before freezing hardware. Precision and physical feasibility remain provisional.';

// Consolidated joint review, 25 September. Overrides preserve existing navigation IDs.
control('embedfsm','Input embedding · FSM',[
 ['IDLE / INIT','Accept descriptor; initialize t=0 once'],['LOAD_TOKEN','Capture current F-feature token'],
 ['LN_F','Normalize F features; wait for completion'],['LINEAR_F_TO_D','D biased dot products; preserve source'],
 ['LN_D','Normalize D projected features'],['WRITE_TOKEN','Commit D results to X'],
 ['NEXT_TOKEN','More tokens: increment t and loop'],['DONE','All L embeddings committed']
], 'LayerNorm(F) → Linear(F,D) → LayerNorm(D), with separate affine parameters.', 'NEXT_TOKEN loops to LOAD_TOKEN, not initialization. Each subcommand waits for completion before scratch reuse. Stage 2 starts after the final token write.',[[6,1]]);
control('positionfsm','Position and sequence · FSM',[
 ['INIT','m=0, n=0, j=0; exact integer counters'],['READ_X','Capture X[m*N+n,j]'],
 ['READ_P','Capture trained P[n,j]'],['ADD_P','Widened add; destination conversion'],
 ['READ_E','Capture trained E[m,j]'],['ADD_E','Second add and conversion'],
 ['WRITE','Request and await committed feature'],['NEXT_INDEX','Advance j, then n, then m'],['DONE','All M*N*D features committed']
], 'Nested terminal comparisons implement token traversal; no runtime modulo or division.', 'NEXT_INDEX loops to READ_X until the final (m,n,j). At j=D-1 reset j and advance n; at n=N-1 reset n and advance m. Mask bypasses this stage.',[[7,1]]);
control('finalfsm','Final projection · FSM',[
 ['INIT_TOKEN','t=0'],['ISSUE_LINEAR','D→1; final weights and bias'],
 ['WAIT_LINEAR','Linear owns and commits z[t] write'],['NEXT_TOKEN','More tokens: increment t'],['DONE','All L logits stored']
], 'One logit per token; no duplicate STORE_LOGIT stage.', 'NEXT_TOKEN loops to ISSUE_LINEAR until L tokens complete. A logit is unrestricted, not a probability. Aggregation follows.',[[3,1]]);
control('aggregatefsm','Aggregation · FSM',[
 ['SELECT_PATH','M=1: go to COPY_SINGLE'],['COUNT_VALID_SLOTS','C counts wholly unpadded reads'],
 ['CHECK_COUNT','C=0: error, not normal completion'],['RECIPROCAL','Compute and retain 1/C once per frame'],
 ['INIT_POSITION','n=0'],['SUM_READS','Sum unmasked z[m*N+n] over m'],
 ['SCALE','Multiply sum by saved 1/C'],['WRITE','Commit output[n]'],
 ['NEXT_POSITION','More n: loop; otherwise DONE'],['DONE','All N output values stored'],
 ['COPY_SINGLE','M=1 only: copy N logits, ignore mask']
], 'Preserve the source numerator and denominator, including its partial-padding behavior.', 'SELECT_PATH chooses COUNT_VALID_SLOTS for M>1, COPY_SINGLE for M=1. COPY_SINGLE goes to DONE after N writes. NEXT_POSITION loops to SUM_READS. Stored-output completion precedes the core output handshakes.',[[8,5]]);
// Explicit conditional topology; DONE must not flow into the M=1 bypass.
pages.aggregatefsm.edges=[e('s0','s1'),e('s0','s10'),e('s1','s2'),e('s2','s3'),e('s3','s4'),e('s4','s5'),e('s5','s6'),e('s6','s7'),e('s7','s8'),e('s8','s5'),e('s8','s9'),e('s10','s9')];
for(const id of ['gelu','exp','reciprocal','invsqrt']){
 pages[id].note='HIGH NUMERICAL RISK — formats, approximation errors and the 1024-cycle watchdog are unvalidated candidates. Compare LUT/polynomial/iterative implementations in a bit-accurate model before freezing RTL. See the final Numerical Research Findings section in the full document. One request outstanding; hold result until accepted.';
}
pages.lnfsm.note='HIGH NUMERICAL RISK: widened mean/centered variance, representable epsilon, inverse square root and affine scaling. The vector length is F or D. Keep input until every pass completes. Use request/wait substates and advance counters only on accepted work; see reviewed mathematics and the final research plan.';
