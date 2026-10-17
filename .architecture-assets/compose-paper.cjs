const fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'..'),file=path.join(root,'docs/latex/bcjrformer_asic_architecture_v5.tex');
const archive=path.join(__dirname,'pre-paper-architecture.tex');
if(!fs.existsSync(archive))fs.copyFileSync(file,archive);
const old=fs.readFileSync(archive,'utf8');
const figs=[...old.matchAll(/\\begin\{center\}\s*\\begin\{tikzpicture\}[\s\S]*?\\end\{tikzpicture\}\s*\\end\{center\}/g)].map(m=>m[0]);
if(figs.length!==7)throw Error('Expected seven original diagrams');
const math=fs.readFileSync(path.join(__dirname,'reviewed-math.tex'),'utf8');
const parts=new Map([...math.matchAll(/\\subsection\{([^}]+)\}([\s\S]*?)(?=\\subsection\{|$)/g)].map(m=>[m[1],m[2].trim()]));
function part(t){if(!parts.has(t))throw Error('Missing math '+t);return parts.get(t);}
const spec=fs.readFileSync(path.join(root,'docs/rtl/RTL-specification.md'),'utf8');
const sp=new Map([...spec.matchAll(/^##+ ([^\r\n]+)\r?\n([\s\S]*?)(?=^##+ |$(?![\s\S]))/gm)].map(m=>[m[1],m[2].trim()]));
const esc=s=>s.replace(/`/g,'').replace(/[\\{}_$%&#^~]/g,c=>({'\\':'\\textbackslash{}','{':'\\{','}':'\\}','_':'\\_','$':'\\$','%':'\\%','&':'\\&','#':'\\#','^':'\\textasciicircum{}','~':'\\textasciitilde{}'}[c]));
function convert(text){let table=false;const out=[];for(const line of text.split(/\r?\n/)){if(/^\|[-| ]+\|$/.test(line))continue;if(line.startsWith('|')){if(!table){out.push('\\begin{itemize}');table=true;}out.push('\\item '+line.split('|').slice(1,-1).map(v=>esc(v.trim())).join(' -- '));continue;}if(table){out.push('\\end{itemize}\n');table=false;}out.push(esc(line));}if(table)out.push('\\end{itemize}');return out.join('\n');}
const sub=(t,b)=>'\\subsection{'+t+'}\n'+b;
const sec=(t,b)=>'\\section{'+t+'}\n'+b;
const rationale=t=>sub('Architectural rationale',t);
const fsm=rows=>sub('Control sequence and completion','\\begin{itemize}\n'+rows.map(([s,b])=>'\\item \\texttt{'+esc(s)+'}: '+b).join('\n')+'\n\\end{itemize}');
function contract(t){if(!sp.has(t))throw Error('Missing contract '+t);return sub(t,convert(sp.get(t)));}
const blocks=[];
blocks.push(String.raw`\documentclass[11pt,a4paper]{article}
\usepackage[margin=1in]{geometry}
\usepackage[T1]{fontenc}
\usepackage{amsmath,amssymb,booktabs,array,tikz,xcolor,enumitem}
\usepackage[hidelinks]{hyperref}
\title{\textbf{BCJRFormer Inference ASIC Architecture}\\\large Sequential Datapath and Control Specification}
\author{Taimor Sabek \and Haiel Bader}
\date{}
\begin{document}
\maketitle`);
blocks.push(fs.readFileSync(path.join(__dirname,'paper-intro.tex'),'utf8'));
blocks.push(sub('Dimensions and frame ownership',part('Dimensions, parameters and frame ownership')));
blocks.push(sec('High-Level Architecture and Stage Interfaces','This section describes functional blocks, connections and scheduling independently of register widths and arithmetic implementation. The detailed mathematical and RTL specification follows the complete five-stage overview.'),figs[0],figs[1]);
blocks.push(fs.readFileSync(path.join(__dirname,'high-level-architecture.tex'),'utf8'));
blocks.push(sec('Detailed Architecture, Mathematics and RTL Mapping','The following five sections refine the preceding architectural overview. Each specifies the stage equations, controller operations, completion conditions and design rationale. Shared-engine protocols and implementation constraints follow the stage descriptions.'));
blocks.push(sec('Stage 1: Input Embedding',[
 sub('Interface and mathematical definition',String.raw`Input: $L$ vectors of length $F$. Output: $e[L,D]$. The two normalizations have independent learned affine parameters.`+'\n\n'+part('Stage 1: input embedding')),
 fsm([['IDLE / INIT','Latch bases and set token index $t=0$.'],['LOAD_TOKEN','Capture $F$ input features in token scratch.'],['LN_F','Issue normalization of length $F$; wait for all normalized features.'],['LINEAR_F_TO_D','Issue $D$ biased dot products of length $F$; wait for committed outputs.'],['LN_D','Normalize the projected D-vector using the second gamma/beta pair.'],['WRITE_TOKEN','Commit all $D$ features into the X bank.'],['NEXT_TOKEN / DONE','If $t<L-1$, increment $t$ and return to LOAD\_TOKEN; otherwise hold completion until accepted.']]),
 sub('Normalization mathematics and internal FSM',part('Layer normalization: common engine for F or D features')),figs[4],
 rationale(String.raw`The first normalization conditions window features and the second normalizes the learned embedding, preserving the reference model. One length-configurable normalization engine serves both operations. Sharing the dot engine reduces arithmetic replication at the cost of latency. Projection input and output scratch must be separate because every output depends on the entire normalized input. In-place normalization is safe only after both statistics passes. Stage 2 starts after all $L$ embedded tokens are committed.`)
].join('\n\n')));
blocks.push(sec('Stage 2: Position and Read Embedding',[
 sub('Interface and mathematical definition',String.raw`Input: $e[L,D]$, position table $P[N,D]$ and read-identity table $E[M,D]$. Output: $X^{(0)}[L,D]$. Position $n$ locates a symbol within a read; $m$ distinguishes received reads of the same frame.`+'\n\n'+part('Stage 2: trained position and read embeddings')),
 fsm([['INIT','Set exact integer counters $m=n=j=0$.'],['READ_X / READ_P','Capture $e_{mN+n,j}$ and trained $P_{n,j}$ through memory request/wait transactions.'],['ADD_P','Compute and convert $a=e_{mN+n,j}+P_{n,j}$.'],['READ_E / ADD_E','Read $E_{m,j}$, then compute and convert $X^{(0)}_{mN+n,j}=a+E_{m,j}$.'],['WRITE','Commit the feature at $X_{base}+(mN+n)D+j$.'],['NEXT_INDEX / DONE','Advance j, then n, then m by terminal comparisons. Repeat READ\_X until the final feature commits.']]),
 rationale(String.raw`P and E are learned during training and only read during inference; no sinusoidal generator or training datapath is required. Exact nested counters avoid runtime modulo/division and quantization errors in indexing. The two additions retain separate conversion boundaries. In-place updates require only the current feature and table values. The padding mask remains immutable and bypasses this stage.`)
].join('\n\n')));
blocks.push(sec('Stage 3: Transformer Encoder',[
 sub('Interface and layer equations',part('Stage 3: one physical layer repeated K times')),figs[3],figs[2],
 fsm([['INIT_LAYER / RUN_LAYER / WAIT_LAYER','Select $k=0$ and layer-specific parameter bases; issue the layer and wait for its final residual write.'],['NEXT_LAYER / DONE','For $k<K-1$, increment k and update parameter bases; otherwise release $X^{(K)}[L,D]$.'],['LN1_ALL_TOKENS','Normalize every D-feature token using the Stage-1 normalization machinery and layer-specific LN1 parameters; preserve X.'],['ATTENTION / RESIDUAL1_ALL','Produce all attention outputs, then commit $R=X+O$.'],['LN2_TOKEN / FFN_TOKEN / RESIDUAL2_TOKEN','Normalize one R token, compute its FFN and commit $X^{next}=R+G$.'],['NEXT_TOKEN / LAYER_DONE','Repeat the LN2/FFN/residual2 sequence for each token; complete the layer only after its last write.']]),
 rationale(String.raw`A single physical layer engine executes all $K$ logical layers with distinct weights, trading throughput for reduced replication. Frame-wide Q/K/V storage ensures every key and value is available before a query starts. Row-wise attention requires score/probability scratch proportional to L rather than $L^2$. Original X survives until residual 1; token-wise FFN then limits hidden storage to $4D$. Logical bank separation simplifies lifetime verification; physical aliasing requires proof of non-overlapping use.`),
 sub('Q/K/V projections and scaled score mathematics',part('Attention projections, head slices and score rows')),figs[6],
 sub('Projection and score FSMs',String.raw`QKV follows IDLE, INIT, ISSUE\_LINEAR, WAIT\_LINEAR, NEXT\_TOKEN, NEXT\_PROJECTION, DONE. INIT selects Q and $t=0$. Complete all L tokens before switching Q to K to V, resetting t on each switch. WAIT\_LINEAR means D committed writes. The final V token releases row processing.

The score-row FSM is IDLE, INIT\_KEY, ISSUE\_DOT, WAIT\_DOT, ISSUE\_SCALE, WAIT\_SCALE, WRITE\_SCORE, NEXT\_KEY, DONE. It retains head/query indices while j advances. Each score write commits before the key index changes. Precomputing $1/\sqrt d$ removes a runtime square-root operation from this path.`),
 sub('Mask and softmax',part('Mask and softmax')),
 sub('Softmax FSM and rationale',String.raw`The controller is IDLE, CHECK\_MASK, FIND\_MAX, EXP\_AND\_SUM, RECIPROCAL, PREPARE\_VALUE, WRITE\_PROBABILITY, NEXT\_ENTRY, DONE. Padded queries jump directly from CHECK\_MASK to PREPARE\_VALUE with uniform mode and j=0. Normal and uniform branches share the writer. Storing exponentials avoids recomputation; maximum subtraction controls the exponential range without changing real-arithmetic softmax. Scalar request/wait substates accommodate implementation-dependent latency. SOURCE\_COMPAT query masking separates hardware approximation error from algorithm changes.`),
 sub('Weighted values and output projection',part('Weighted values and output projection')),
 sub('Weighted-value and output-projection FSMs',String.raw`Weighted-value control follows IDLE, INIT\_FEATURE, ISSUE\_DOT, WAIT\_DOT, ROUND\_SATURATE, WRITE\_RESULT, NEXT\_FEATURE, DONE. Reset r=0 per query/head; keep the probability row through all d results. Then advance query i; after its last value reset i=0 and advance head a. Output projection starts only after all heads finish.

Projection follows IDLE, INIT\_TOKEN, ISSUE\_LINEAR, WAIT\_LINEAR, NEXT\_TOKEN, DONE, waiting for D committed outputs per token. Different descriptors reuse the same dot engine for projections, QK scores and weighted values. Strided access selects the correct operand without a transpose copy. Joined-head addressing removes a separate concatenation operation.`),
 sub('LN2, FFN and residual mathematics',part('FFN and residual additions')),figs[5],
 sub('FFN and residual FSMs',String.raw`FFN control issues LINEAR1 and waits for its 4D outputs; GELU\_REQ, GELU\_WAIT and GELU\_WRITE then iterate over the hidden vector. LINEAR2 starts only after every activated hidden value is stored; its last committed output permits FFN\_DONE. Preserve all 4D values because every second-layer output depends on the whole hidden vector.

Each residual uses READ\_LEFT, READ\_RIGHT, ADD\_WIDEN, ROUND\_SATURATE, WRITE, NEXT\_INDEX, DONE. Its per-feature operation is the corresponding residual equation above. Both operands are captured before an in-place write; indices advance after commitment. LN2 uses the Stage-1 normalization schedule at length D with independent affine parameters. No second GELU or inference dropout is inserted.`)
].join('\n\n')));
const final=part('Stage 4: final projection and aggregation'),idx=final.indexOf('Let $p^{mask}');if(idx<0)throw Error('Missing aggregation');
blocks.push(sec('Stage 4: Final Linear Projection',[
 sub('Interface and mathematical definition',String.raw`Input: $X^{(K)}[L,D]$. Output: one unrestricted signed logit per token, $z[L]$, for the binary target.`+'\n\n'+final.slice(0,idx)),
 fsm([['INIT_TOKEN','Set t=0 and select the final weight vector and scalar bias.'],['ISSUE_LINEAR / WAIT_LINEAR','Run a D-to-1 linear command on token t; wait for its destination write to $z_t$.'],['NEXT_TOKEN / DONE','Increment t and repeat while $t<L-1$; release all L logits after the last write.']]),
 rationale(String.raw`The shared biased dot product implements this projection without another arithmetic engine. The linear controller already owns conversion and writing; a second STORE\_LOGIT would duplicate work. Preserve raw logits through aggregation: averaging probabilities or making hard decisions first would change the algorithm.`)
].join('\n\n')));
blocks.push(sec('Stage 5: Read Aggregation and Output',[
 sub('Interface and mathematical definition',String.raw`Input: per-read logits $z[M,N]$ and original padding mask. Output: one length-N logit vector for the frame.`+'\n\n'+final.slice(idx)),
 fsm([['SELECT_PATH','For M=1, COPY\_SINGLE commits N logits directly, ignoring the mask. Otherwise count valid read slots.'],['COUNT_VALID_SLOTS','Clear C; initialize each read-valid flag to one and AND it with all N inverted padding bits, then add the flag to C.'],['CHECK_COUNT / RECIPROCAL','For C=0 report error; otherwise calculate and retain 1/C once per frame.'],['INIT_POSITION / SUM_READS','Set n=0; for each position clear its widened numerator and sum the M unmasked logits.'],['SCALE / WRITE','Multiply the numerator by the saved reciprocal, convert and commit $y_n$.'],['NEXT_POSITION / DONE','Advance n and repeat SUM\_READS; DONE follows N stored outputs.'],['OUTPUT / COMPLETE (core)','Hold output and index stable while stalled. Successful frame completion requires all N accepted transfers.']]),
 rationale(String.raw`A frame-wide denominator permits one reciprocal calculation for all positions. Wide summation followed by a final conversion avoids repeated rounding of partial sums. Preserving the M=1 branch and partial-padding behavior maintains source compatibility; the C=0 guard explicitly reports undefined output. An optional downstream sign comparison supplies hard decisions without a sigmoid unit.`)
].join('\n\n')));
blocks.push(sec('Shared Arithmetic and Transaction Protocol',part('Shared dot and linear engines')));
blocks.push(sub('Frame-level controller',String.raw`The core follows IDLE, LOAD\_FEATURES, LOAD\_MASK, EMBED, POSITION, ENCODER, FINAL, AGGREGATE, OUTPUT, COMPLETE. Each compute state issues one stage command and waits for completion. Input counters advance only on accepted transfers and validate the final-element marker. Parameters must be committed before accepting a frame. OUTPUT drains all N stored logits under ready/valid backpressure; COMPLETE holds the result status until accepted, then returns to IDLE. Parameter storage persists between successful frames. Reset invalidates configuration and frame state. A latched error stops new work, drains accepted transactions and returns an error completion rather than a successful result.`));
blocks.push(sub('Dot and linear state transitions',convert(sp.get('Joint review: shared projection and dot controllers').split(/\r?\n\r?\n/).filter(p=>p.startsWith('Dot FSM:')||p.startsWith('Linear FSM:')).join('\n\n'))));
blocks.push(sec('RTL Specification and Implementation Constraints',['Proposed configuration','Scalar arithmetic and constants','Top-level ports and load order','Module hierarchy and contracts','Memory ownership and lifetime','FSM conventions','Arithmetic black-box contracts','Verification and implementation gates'].map(contract).join('\n\n')));
blocks.push(sub('Numerical observations',part('Numerical observations and remaining implementation boundaries')));
blocks.push(sub('Snapshot records and physical feasibility',convert(['Numerical snapshots and comparison plan','Physical feasibility before RTL freeze'].map(t=>sp.get(t)).join('\n\n').replace('Agreed baseline:','The verification architecture requires').replace('User agreement to the sequential structure is not proof of physical feasibility.','The sequential schedule does not establish physical feasibility.').replace('approved baseline','proposed baseline'))));
blocks.push(String.raw`\section{Design Review Decisions}
This architecture specifies proposed behavior, not completed RTL or measured silicon. The following decisions are required before implementation freeze.
\begin{itemize}
\item Confirm configuration and usable checkpoint, binary output, query-row masking, static-mask exclusion, partial-padding policy and C=0 guard.
\item Accept the sequential shared-engine baseline and define latency, throughput, clock, area and power objectives.
\item Select target technology, available SRAM macros and physical-design scope; verify total storage and access requirements.
\item Agree numerical tolerances, decoding-performance criteria and held-out datasets before choosing formats and nonlinear implementations.
\item Confirm required RTL, verification, synthesis and reporting deliverables. Arithmetic placeholders do not count as completed computation.
\end{itemize}
\section{Source References}
The software mapping is based on repository revision \texttt{c7cf84e218730f4583e79af6dd876b04384d33f5}. Revalidate the mapping if the selected software reference changes.
\begin{itemize}
\item Model boundary, embedding and aggregation: \url{https://github.com/streit-julian/BCJRFormer/blob/c7cf84e218730f4583e79af6dd876b04384d33f5/bcjrformer/models/bcjrformer.py}
\item Encoder primitives: \url{https://github.com/streit-julian/BCJRFormer/blob/c7cf84e218730f4583e79af6dd876b04384d33f5/bcjrformer/models/modules.py}
\end{itemize}`);
blocks.push(fs.readFileSync(path.join(__dirname,'numerical-research.tex'),'utf8').replace('These findings support choosing implementations; they do not establish that the current BCJRFormer quantization contracts pass. No new bit-accurate implementation, BER experiment or synthesis result is claimed in this document.','The following literature and course-material analysis motivates candidate arithmetic implementations. Published results concern the cited systems; the BCJRFormer numerical contracts require independent validation.').replace('The next deliverable for these black boxes is a measured comparison of candidate implementations, not an assumption that every operation must be expanded into a new top-level FSM stage. Keep the reviewed handshake boundaries and refine internal substates once the arithmetic implementation is selected.','Candidate implementations shall be compared under the specified handshake boundaries. Internal substates and latency bounds shall be refined after arithmetic selection without changing the five-stage decomposition.'));
blocks.push('\\end{document}\n');
const tex=blocks.join('\n\n');
if(/25 September|24 September|Joint review|Target review draft|\\today/.test(tex))throw Error('Progress-log language remains');
fs.writeFileSync(file,tex);
console.log('Assembled five-stage paper with integrated mathematics, FSMs and rationale');
