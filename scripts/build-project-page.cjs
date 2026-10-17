const fs=require('fs');
const path=require('path');
const katex=require('../.architecture-assets/katex.cjs');
const target=path.join(require('path').resolve(__dirname,'..'),'web/bcjrformer-architecture.html');
const base=path.join(require('path').resolve(__dirname,'..'),'.architecture-assets','architecture-original.html');
if(!fs.existsSync(base))fs.copyFileSync(target,base);
let html=fs.readFileSync(base,'utf8');
html=html.replace('Read positional memory using n and sequence memory using m; add both vectors. The mask bypasses these additions.', 'P and E are learned model parameters stored in the checkpoint. Load them into parameter memories before inference. Read P[n] and E[m] using the position and read-slot indices, then add both vectors to the token. Inference does not recompute the table values. The mask bypasses these additions.');
require('../.architecture-assets/compose-paper.cjs');
const tex=fs.readFileSync(path.join(require('path').resolve(__dirname,'..'),'docs/latex/bcjrformer_asic_architecture_v5.tex'),'utf8');
const esc=s=>s.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const held=[];const hold=s=>'@@BLOCK'+(held.push(s)-1)+'@@';
const restore=s=>s.replace(/@@BLOCK(\d+)@@/g,(_,i)=>held[i]);
const toc=[];let mathCount=0;
function math(s,displayMode){mathCount++;return katex.renderToString(s,{displayMode,throwOnError:true,strict:'ignore',output:'htmlAndMathml'});}
function prose(s){
 s=s.replace(/\\textbackslash\{\}/g,'BACKSLASHPLACEHOLDER').replace(/\\textasciicircum\{\}/g,'^').replace(/\\textasciitilde\{\}/g,'~').replace(/\\([{}#$])/g,'$1');
 s=s.replace(/\\url\{([^}]+)\}/g,(_,url)=>hold('<a target="_blank" rel="noopener" href="'+esc(url)+'">'+esc(url)+'</a>'));
 s=s.replace(/(?<!\\)\$([^$]+)(?<!\\)\$/g,(_,m)=>hold(math(m,false)));
 s=s.replace(/\\(texttt|textbf|textnormal|emph)\{([^{}]*)\}/g,(_,cmd,t)=>hold((cmd==='texttt'?'<code>':cmd==='textbf'?'<strong>':cmd==='emph'?'<em>':'<span>')+esc(t.replace(/\\_/g,'_'))+(cmd==='texttt'?'</code>':cmd==='textbf'?'</strong>':cmd==='emph'?'</em>':'</span>')));
 return restore(esc(s.replace(/\\_/g,'_').replace(/\\&/g,'&').replace(/\\%/g,'%').replace(/\\centering/g,'').replace(/\\textnormal\{([^}]+)\}/g,'$1').replace(/\s+/g,' ').trim()));
}
let body=tex.split('\\begin{document}')[1].split('\\end{document}')[0].replace('\\maketitle','').replace(/^%.*$/gm,'');
body=body.replace(/\\begin\{verbatim\}([\s\S]*?)\\end\{verbatim\}/g,(_,s)=>'\n\n'+hold('<pre class="doc-code"><code>'+esc(s.trim())+'</code></pre>')+'\n\n');
let figure=0;
const figs=[
 '<div class="paper-figure"><div class="figure-port">y · window features<br>padding_mask</div><div class="figure-arrow">↓</div><div class="figure-core">BCJRFormer<br><small>Neural-network core</small></div><div class="figure-arrow">↓</div><div class="figure-port">logits</div></div>',
 '<div class="paper-figure">'+['Input embedding','Position + sequence embedding','Transformer encoder · N_dec layers','Final linear projection','Sequence aggregation'].map((s,i)=>'<div class="figure-block">'+s+(i===2||i===4?'<small> ← padding_mask</small>':'')+'</div>').join('<div class="figure-arrow">↓</div>')+'<div class="figure-arrow">↓ logits</div></div>',
 `<div class="paper-figure"><svg viewBox="0 0 700 690" role="img" aria-labelledby="residual-title residual-desc" style="display:block;width:100%;max-width:700px;margin:auto">
 <title id="residual-title">One pre-normalization self-attention layer</title>
 <desc id="residual-desc">Input x splits into LayerNorm then attention, and an unchanged bypass into the first addition. The first sum r splits into LayerNorm then feed-forward, and an unchanged bypass into the second addition, producing the output.</desc>
 <defs><marker id="residual-arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M 0 0 L 10 5 L 0 10 z" fill="#315c8d"/></marker></defs>
 <g fill="none" stroke="#315c8d" stroke-width="2.5" marker-end="url(#residual-arrow)">
 <path d="M 280 55 V 90"/><path d="M 280 145 V 175"/><path d="M 280 235 V 277"/>
 <path d="M 280 70 H 580 V 300 H 303"/>
 <path d="M 280 323 V 385"/><path d="M 280 440 V 470"/><path d="M 280 530 V 572"/>
 <path d="M 280 350 H 580 V 595 H 303"/><path d="M 280 618 V 650"/>
 </g>
 <g fill="#fff" stroke="#7084a3" stroke-width="1.5">
 <rect x="100" y="90" width="360" height="55" rx="7"/><rect x="100" y="175" width="360" height="60" rx="7"/>
 <circle cx="280" cy="300" r="23"/><rect x="100" y="385" width="360" height="55" rx="7"/>
 <rect x="100" y="470" width="360" height="60" rx="7"/><circle cx="280" cy="595" r="23"/>
 </g>
 <g fill="#315c8d"><circle cx="280" cy="70" r="4"/><circle cx="280" cy="350" r="4"/></g>
 <g fill="#202c42" font-family="Arial,sans-serif" font-size="21" text-anchor="middle">
 <text x="280" y="42">Input x</text><text x="280" y="125">LayerNorm 1</text><text x="280" y="213">Multi-head self-attention</text>
 <text x="280" y="308" font-size="28">+</text><text x="280" y="420">LayerNorm 2</text><text x="280" y="508">Feed-forward network</text>
 <text x="280" y="603" font-size="28">+</text><text x="280" y="678">Output</text>
 <text x="594" y="175" text-anchor="start">x</text><text x="594" y="483" text-anchor="start">r</text>
 <text x="260" y="361" text-anchor="end">r</text>
 </g></svg><div style="font-size:15px">r = x + Attention(LayerNorm 1(x))<br>Output = r + FFN(LayerNorm 2(r))</div></div>`
];
figs.push(...require('../.architecture-assets/sketch-figures.cjs'));
// The paper introduces the shared normalization engine in Stage 1 (J=F or D).
figs[4]=figs[4].replace(/\bD\b/g,'J').replace('aria-label="LayerNorm 1"','aria-label="Shared LayerNorm, J features"');
const paperFigures=[0,1,4,3,2,6,5].map(i=>figs[i]);
body=body.replace(/\\begin\{center\}\s*\\begin\{tikzpicture\}[\s\S]*?\\end\{tikzpicture\}\s*\\end\{center\}/g,()=>{const index=figure++;if(!paperFigures[index])throw Error('Missing figure '+index);return '\n\n'+hold('<figure>'+paperFigures[index]+'<figcaption>Figure '+(index+1)+' · Block connections. TikZ diagram included in the LaTeX source.</figcaption></figure>')+'\n\n';});
body=body.replace(/\\\[([\s\S]*?)\\\]/g,(_,s)=>'\n\n'+hold('<div class="doc-equation">'+math(s,true)+'</div>')+'\n\n');
body=body.replace(/\\begin\{table\}(?:\[[^\]]*\])?([\s\S]*?)\\end\{table\}/g,(_,s)=>{
 s=s.slice(s.indexOf('\\toprule')+8,s.indexOf('\\bottomrule')).replace(/\\midrule/g,'');
 const rows=s.split('\\\\').map(r=>r.trim()).filter(Boolean);
 return '\n\n'+hold('<div class="doc-table"><table>'+rows.map((row,i)=>'<tr>'+row.split('&').map(cell=>'<'+(i?'td':'th')+'>'+prose(cell)+'</'+(i?'td':'th')+'>').join('')+'</tr>').join('')+'</table></div>')+'\n\n';
});
body=body.replace(/\\begin\{(enumerate|itemize)\}(?:\[[^\]]*\])?([\s\S]*?)\\end\{\1\}/g,(_,type,s)=>'\n\n'+hold('<'+(type==='enumerate'?'ol':'ul')+'>'+s.split('\\item').slice(1).map(item=>'<li>'+prose(item)+'</li>').join('')+'</'+(type==='enumerate'?'ol':'ul')+'>')+'\n\n');
body=body.replace(/\\(section|subsection)\{((?:[^{}]|\{[^{}]*\})*)\}/g,(_,level,title)=>{const id='doc-section-'+toc.length;const name=prose(title);toc.push({id,name,level});return '\n\n'+hold('<'+(level==='section'?'h2':'h3')+' id="'+id+'">'+name+'</'+(level==='section'?'h2':'h3')+'>')+'\n\n';});
const content=body.split(/\n\s*\n/).map(s=>s.trim()).filter(Boolean).map(s=>/^@@BLOCK\d+@@$/.test(s)?restore(s):'<p>'+prose(s)+'</p>').join('\n');
if(/\\(?:begin|end|section|subsection|textbf|texttt)\b/.test(content.replace(/<annotation[\s\S]*?<\/annotation>/g,'').replace(/<[^>]+>/g,'')))throw Error('Unconverted LaTeX structure remains');
const css=`
.paper{overflow-wrap:anywhere}.paper .doc-code{overflow-wrap:normal}.paper .katex-display{max-width:100%}
[hidden]{display:none!important}body{background:radial-gradient(ellipse at 5% 0%,#112652 0%,transparent 45%),radial-gradient(ellipse at 95% 10%,#29194c 0%,transparent 45%),#0a1020}.project-nav{padding:16px 4vw;display:flex;justify-content:space-between;align-items:center;gap:15px;border-bottom:1px solid #314567;flex-wrap:wrap;background:#0a1020e8}.project-brand{color:#eff6ff;font-weight:650;text-decoration:none;font-size:17px}.project-nav div{display:flex;gap:18px;flex-wrap:wrap}.project-nav a{font-size:14px;text-decoration:none}.home{max-width:1250px;padding:74px 5vw 65px;margin:auto}.home h1{font-size:clamp(42px,7vw,86px);line-height:1.03;letter-spacing:-.05em;max-width:950px;margin:22px 0 30px}.gradient-word{color:#83d7ff}.home .abstract{max-width:740px;font-size:20px;line-height:1.65;color:#c1cee2}.authors{display:flex;flex-wrap:wrap;gap:12px 30px;margin:28px 0 45px;font-size:19px}.authors span{border-left:3px solid #b494ff;padding-left:13px}.home-links{display:grid;grid-template-columns:1fr 1fr;gap:24px}.home-card{display:block;position:relative;border:1px solid #5479ae;background:linear-gradient(125deg,#152e4e,#16223e);padding:30px;border-radius:18px;color:#f0f5ff;text-decoration:none;transition:transform .15s,border-color .15s}.home-card:nth-child(2){border-color:#7b65b5;background:linear-gradient(125deg,#2a2049,#17223e)}.home-card:hover{transform:translateY(-4px);border-color:#9de5ff}.home-card .number{font:14px ui-monospace,monospace;color:#8edcff}.home-card h2{font-size:26px;margin:15px 0}.home-card p{color:#c1cfe2;margin:0 0 28px}.home-card .action{color:#96e9df}.home-note{color:#b4c6df;margin:30px 0;font-size:14px}.workspace-title{padding:24px 4vw 16px}.diagram-panel{border-color:#4e75aa;box-shadow:0 10px 45px #0003;background:linear-gradient(160deg,#13253c,#141b31)}.diagram-heading h2{color:#9ee9ff}.node.clickable{background:linear-gradient(135deg,#153b5e,#253154);border-color:#669ad0;border-top-color:#71d9ff;box-shadow:0 3px 18px #04122244}.node.clickable:hover{background:linear-gradient(135deg,#23557d,#3d3770);box-shadow:0 0 22px #67cfff28}.node.core-block{min-height:190px;background:linear-gradient(135deg,#214a75,#473277);border:2px solid #97cfff;box-shadow:0 0 36px #795bff30}.node.core-block strong{font-size:27px;line-height:1.25}.node.core-block small{font-size:15px;color:#deebff;margin-top:12px}.graph.boundary-graph{grid-template-columns:1fr 2fr 1fr}.node[data-key="encoder"],.node[data-key="mha"]{background:linear-gradient(135deg,#343668,#254f69);border-color:#b296ff}.flow-controls{display:flex;align-items:center;gap:12px;padding:10px 22px;flex-wrap:wrap;border-bottom:1px solid #344b70}.flow-controls button{padding:7px 13px;border:1px solid #6b87b5;background:#1d3453;border-radius:7px;font-size:14px}.flow-controls p{font-size:13px;color:#bfd2ee;margin:0}.wires path[data-from]{transition:opacity .15s,stroke-width .15s}.wires path.focus-edge{stroke-width:3.5}.node.signal-dim{opacity:.45}.graph.tracing .wires path[data-from]{stroke-dasharray:8 7;animation:signal-flow .8s linear infinite}.graph.tracing .wires path[data-kind="mask"]{animation:none;stroke-dasharray:5 4}@keyframes signal-flow{to{stroke-dashoffset:-30}}.doc-shell{max-width:1420px;margin:auto;padding:40px 4vw}.doc-header h1{font-size:clamp(30px,4vw,46px);margin:10px 0}.doc-header p{max-width:850px;color:#bdcce2}.doc-actions{display:flex;gap:12px;flex-wrap:wrap;margin:22px 0}.doc-actions button{padding:10px 15px;border:1px solid #896fba;border-radius:8px;background:#292544;font-size:14px}.doc-layout{display:grid;grid-template-columns:250px minmax(0,1fr);gap:36px;align-items:start}.doc-toc{position:sticky;top:18px;max-height:85vh;overflow:auto;padding-right:12px}.doc-toc a{display:block;padding:7px 0;color:#c5d3eb;font-size:14px;text-decoration:none}.doc-toc a:hover{color:#90e1ff}.paper{background:#f8faff;color:#202c42;border-radius:13px;padding:clamp(22px,4vw,56px);min-width:0;font-size:17px;line-height:1.8}.paper h2{font-size:26px;line-height:1.35;margin:45px 0 20px;color:#183d76;scroll-margin-top:20px}.paper h2:first-child{margin-top:0}.paper h3{font-size:21px;color:#294b70;margin:32px 0 15px;scroll-margin-top:20px}.paper a{color:#125db0;overflow-wrap:anywhere}.paper p{margin:15px 0}.paper code{font-size:.9em;overflow-wrap:anywhere;color:#2d3977}.paper li{margin:9px 0}.doc-code{background:#e8eff8;padding:16px;border-radius:6px;overflow:auto;font-size:14px}.doc-equation{overflow-x:auto;overflow-y:hidden;padding:5px 0;margin:18px 0}.doc-equation .katex-display{margin:.5em 0}.paper .katex{font-size:1.08em}.doc-table{overflow:auto}.doc-table table{border-collapse:collapse;width:100%;font-size:15px}.doc-table td,.doc-table th{text-align:left;border-bottom:1px solid #c5d1e2;padding:12px;vertical-align:top}.paper figure{margin:28px 0}.paper-figure{text-align:center;padding:20px;background:#edf3fc;border-radius:8px}.figure-block,.figure-core{max-width:390px;margin:auto;border:1px solid #7084a3;padding:14px;border-radius:7px;background:#fff}.figure-core{padding:26px;color:#fff;background:#244572;font-size:22px}.figure-core small{color:#d7e8ff}.figure-block small{display:block;color:#775529}.figure-arrow{color:#315c8d;font-size:22px}.figure-port{font-size:15px}.paper figcaption{font-size:13px;color:#52647d;margin-top:12px}.source-code{white-space:pre-wrap;overflow-wrap:anywhere;background:#101c30;color:#dce9fd;padding:20px;border-radius:10px;font-size:13px;line-height:1.6}.doc-warning{border-left:3px solid #dfb56e;padding-left:15px;font-size:14px;color:#e5c99f;max-width:950px;margin-bottom:28px}.paper strong{font-weight:650}
@media(max-width:850px){.doc-layout{grid-template-columns:1fr}.doc-toc{position:static;max-height:240px;border-bottom:1px solid #344b70;padding-bottom:18px}.home{padding-top:45px}.home-links{grid-template-columns:1fr}.home .abstract{font-size:18px}}
@media(max-width:560px){.project-nav{padding:14px 20px}.graph.boundary-graph{grid-template-columns:1fr}.home-card{padding:24px}.doc-shell{padding:25px 16px}.paper{padding:20px}.node.core-block{min-height:160px}.doc-equation{font-size:14px}.home h1{font-size:43px}.home{padding:35px 20px}.authors{font-size:17px}.paper{font-size:16px}}
@media(prefers-reduced-motion:reduce){.graph.tracing .wires path[data-from]{animation:none}.home-card{transition:none}}
@media print{body{background:white}.project-nav,.doc-actions,.doc-toc,.doc-warning{display:none}.doc-layout{display:block}.doc-shell{padding:0}.paper{padding:0;background:white;color:black}.paper h2,.paper h3{break-after:avoid}.doc-equation,figure{break-inside:avoid}.doc-header p{color:black}.doc-header{color:black}.doc-code{white-space:pre-wrap}}
`;
const home=`<section id="home-view" class="home"><div class="eyebrow">Project 2 · DNA storage & ASIC design</div><h1>From noisy DNA reads<br>to a <span class="gradient-word">decoder architecture.</span></h1><div class="authors"><span>Taimor Sabek</span><span>Haiel Bader</span></div><p class="abstract">Exploring BCJRFormer for DNA-storage decoding: understand the algorithm, reproduce its software results, and develop the architecture and microarchitecture of an inference ASIC.</p><div class="home-links"><a class="home-card" href="#architecture" target="_blank" rel="noopener"><span class="number">01 / EXPLORE</span><h2>Interactive architecture ↗</h2><p>Enter the transformer core, follow its inputs and outputs, and open each block to understand what it computes and why it is there.</p><span class="action">Open architecture in a new tab →</span></a><a class="home-card" href="#document" target="_blank" rel="noopener"><span class="number">02 / READ</span><h2>Complete architecture document ↗</h2><p>The full v5 LaTeX description, including equations, block diagrams, interface definitions, and the initial FSM discussions.</p><span class="action">Open complete document in a new tab →</span></a></div><p class="home-note">A working academic project. Software reproduction and the ASIC implementation remain in progress.</p></section>`;
const documentView=`<section id="document-view" class="doc-shell" hidden><div class="doc-header"><div class="eyebrow">Full document · LaTeX v5</div><h1>BCJRFormer ASIC Architecture</h1><p>Stage 1: Neural-Network Black-Box Definition<br>Taimor Sabek & Haiel Bader</p><p>Every section of <code>bcjrformer_asic_architecture_v5.tex</code>, presented as a readable document. The original source is embedded below and can be downloaded for Overleaf.</p><div class="doc-actions"><button id="download-tex" type="button">Download original .tex</button><button id="toggle-source" type="button" aria-expanded="false" aria-controls="source-panel">Show LaTeX source</button><button id="print-doc" type="button">Print / save PDF</button></div></div><div class="doc-warning">Saved draft, preserved as written. The explorer adds later code-review notes about projection biases and attention-mask behavior. Those findings have not been silently applied to this document. The title and stage numbering are also preserved from the original.</div><div id="source-panel" hidden><pre class="source-code">${esc(tex)}</pre></div><div class="doc-layout"><aside class="doc-toc" aria-label="Document contents"><div class="eyebrow">Contents</div>${toc.filter(x=>x.level==='section').map(x=>'<a href="#document/'+x.id+'">'+x.name+'</a>').join('')}</aside><article class="paper">${content}</article></div></section>`;
const nav='<div class="project-nav"><a class="project-brand" href="#home">BCJRFormer / Project 2</a><div><a href="#home">Home</a><a href="#architecture">Architecture</a><a href="#document">Full document</a></div></div>';
html=html.replace('</style>','\n'+css+'\nbody{min-height:100vh;background-attachment:fixed}\n</style>\n<style>'+fs.readFileSync('.architecture-assets/math.css','utf8')+'</style>');
if(fs.existsSync('.architecture-assets/KATEX-LICENSE.txt'))html=html.replace('</head>','<!-- Math rendering / font license:\n'+fs.readFileSync('.architecture-assets/KATEX-LICENSE.txt','utf8')+'\n-->\n</head>');
html=html.replace('<body>','<body>\n'+nav+'\n'+home+'\n<section id="architecture-view" hidden>');
html=html.replace('</main>','</main>\n</section>\n'+documentView);
const rtlSection=toc.find(x=>x.name==='RTL Specification and Implementation Constraints');
const decisionsSection=toc.find(x=>x.name==='Design Review Decisions');
if(!rtlSection||!decisionsSection)throw Error('Missing review draft sections');
html=html.replace('<a href="#document">Full document</a>','<a href="#document">Full document</a><a href="#document/'+rtlSection.id+'">RTL specification</a><a href="#document/'+decisionsSection.id+'">Review decisions</a>');
html=html.replace('Saved draft, preserved as written.', 'Working draft updated during review.');
html=html.replace('Those findings have not been silently applied to this document.', 'Projection and masking details still require review in this document.');
html=html.replace('Stage 1: Neural-Network Black-Box Definition','Sequential Datapath and Control Specification');
html=html.replace(/<div class="doc-warning">[\s\S]*?<\/div>/,'<div class="doc-warning">Design-review specification: five stages with integrated mathematics, FSMs and architectural rationale. Numerical formats, nonlinear implementations and physical feasibility remain subject to validation.</div>');
html=html.replace('the initial FSM discussions','stage-by-stage FSMs and architectural rationale');
html=html.replace('<title>BCJRFormer · Architecture explorer</title>','<title>BCJRFormer · Taimor Sabek & Haiel Bader</title>');
html=html.replace('<div class="graph" id="graph"></div>','<div class="flow-controls"><button id="trace-flow" type="button" aria-pressed="false">Animate data flow</button><p>Hover or focus a block to highlight its connections.</p></div><div class="graph" id="graph"></div>');
html=html.replace("const graphEl=document.getElementById('graph');",`page('system','Transformer core · inputs & outputs','Defines the boundary between the precomputed received-sequence features and the learned neural-network decoder. Open the large core to see all five internal stages.','BCJRFormer(y, padding_mask) → raw logits','y [B,M,N,W,S]; padding_mask [B,M,N]','Binary logits [B,N]','The first ASIC target uses B=1 and q=2. Window generation and binary hard decisions remain outside this neural-network boundary.','bcjrformer.py',{intro:'The large box is the complete BCJRFormer neural-network core, including its transformer encoder.'});
graph('system',[n('input',null,1,1,'Window features y','[B,M,N,W,S]','port'),n('core','core',2,2,'BCJRFormer','Neural-network / transformer core'),n('mask',null,1,3,'padding_mask','[B,M,N] · Boolean','mask'),n('output',null,3,2,'Raw logits','[B,N] · q = 2','port')],[e('input','core'),e('mask','core','mask'),e('core','output')]);
const graphEl=document.getElementById('graph');`);
html=html.replace("let trail=['core'];","let trail=['system'];");
html=html.replace("const graphEl=document.getElementById('graph');",fs.readFileSync('.architecture-assets/concise-explorer.js','utf8')+"\nconst graphEl=document.getElementById('graph');");
html=html.replace("const graphEl=document.getElementById('graph');",fs.readFileSync('.architecture-assets/encoder-sketch.js','utf8')+"\nconst graphEl=document.getElementById('graph');");
html=html.replace("const graphEl=document.getElementById('graph');",fs.readFileSync('.architecture-assets/rtl-draft.js','utf8')+"\nconst graphEl=document.getElementById('graph');");
html=html.replace(/ details\.innerHTML=.*;\r?\n/,` details.innerHTML='<span class="tag">'+(key==='encoder'?'Black box':'Block overview')+'</span><h2>'+escape(p.title)+'</h2><p>'+escape(p.why)+'</p><h3>Connections</h3><dl class="io"><dt>Input</dt><dd>'+escape(p.input)+'</dd><dt>Output</dt><dd>'+escape(p.output)+'</dd></dl>'+(p.note?'<p class="caution">'+escape(p.note)+'</p>':'')+'<p style="margin-top:24px"><a href="#document">Full explanation in the architecture document →</a></p>';\n`);
html=html.replace("(key==='encoder'?'Black box':'Block overview')","(p.status||'Block overview')");
html=html.replace('Click a block to go inside. Follow the arrows to see how information moves.','Architecture and RTL review draft: explore each datapath and its controller. Numerical choices remain proposals.');
html=html.replace('<b>D, h, dₖ</b> — model width, head count, and D/h features per head.','<b>D</b> — model width.');
html=html.replace(/<p>The checked-in example configuration[\s\S]*?<\/p>/,'');
html=html.replace('The explorer adds later code-review notes about projection biases and attention-mask behavior. Projection and masking details still require review in this document.','The complete RTL review draft below defines proposed controllers, interfaces, memory ownership and numeric contracts for all stages. Numerical calibration and implementation remain unverified.');
html=html.replace("index===0?'Core':pages[id].title","index===0?'Boundary':pages[id].title");
html=html.replace("graphEl.replaceChildren();","graphEl.replaceChildren();graphEl.classList.toggle('boundary-graph',key==='system');");
html=html.replace("el.id='node-'+v.id;","el.id='node-'+v.id;el.dataset.key=v.key||'';");
html=html.replace("el.style.gridColumn=v.col;","if(v.key==='core')el.classList.add('core-block');el.style.gridColumn=v.col;");
html=html.replace("graphEl.append(el);","el.addEventListener('pointerenter',()=>highlight(v.id));el.addEventListener('pointerleave',()=>highlight(null));el.addEventListener('focus',()=>highlight(v.id));el.addEventListener('blur',()=>highlight(null));graphEl.append(el);");
html=html.replace("path.setAttribute('d',d);path.setAttribute('fill','none');","path.dataset.from=edge.a;path.dataset.to=edge.b;path.dataset.kind=edge.type;path.setAttribute('d',d);path.setAttribute('fill','none');");
html=html.replace("if(Math.abs(a.x-b.x)<2){if(","if(Math.abs(a.x-b.x)<2){if(b.y<a.y){d=`M ${a.x+a.w/2} ${a.y} V ${b.y+b.h+3}`;}else if(");
html=html.replace("const path=document.createElementNS(ns,'path');path.dataset.from",`if(b.y<a.y){const lane=Math.max(a.x+a.w,b.x+b.w)+8+(index%3)*6;d=\`M \${a.x+a.w} \${a.y+a.h/2} H \${lane} V \${b.y+b.h/2} H \${b.x+b.w}\`;}
 if(['ln1','ln2'].includes(graphEl.dataset.page)&&edge.a==='sub'&&edge.b==='norm'){const lane=a.x+a.w+16;d=\`M \${a.x+a.w} \${a.y+a.h/2} H \${lane} V \${b.y+b.h/2} H \${b.x+b.w}\`;}
 const path=document.createElementNS(ns,'path');path.dataset.from`);
html=html.replace("document.getElementById('back').onclick",`function highlight(id){
 const relevant=new Set(id?[id]:[]);
 graphEl.querySelectorAll('.wires path[data-from]').forEach(p=>{const hit=id&&(p.dataset.from===id||p.dataset.to===id);p.classList.toggle('focus-edge',!!hit);p.style.opacity=id&&!hit?'.2':'1';if(hit){relevant.add(p.dataset.from);relevant.add(p.dataset.to);}});
 graphEl.querySelectorAll('.node').forEach(n=>n.classList.toggle('signal-dim',!!id&&!relevant.has(n.id.slice(5))));
}
document.getElementById('trace-flow').onclick=()=>{const active=graphEl.classList.toggle('tracing');const b=document.getElementById('trace-flow');b.setAttribute('aria-pressed',String(active));b.textContent=active?'Pause data flow':'Animate data flow';};
document.getElementById('back').onclick`);
html=html.replace('render();\n})();',`render();
const texBase64='${Buffer.from(tex).toString('base64')}';
document.getElementById('download-tex').onclick=()=>{const bytes=Uint8Array.from(atob(texBase64),c=>c.charCodeAt(0));const url=URL.createObjectURL(new Blob([bytes],{type:'application/x-tex'}));const a=document.createElement('a');a.href=url;a.download='bcjrformer_asic_architecture_v5.tex';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);};
document.getElementById('toggle-source').onclick=()=>{const panel=document.getElementById('source-panel');panel.hidden=!panel.hidden;const b=document.getElementById('toggle-source');b.setAttribute('aria-expanded',String(!panel.hidden));b.textContent=panel.hidden?'Show LaTeX source':'Hide LaTeX source';};
document.getElementById('print-doc').onclick=()=>window.print();
function route(){const parts=location.hash.slice(1).split('/');const mode=['architecture','document'].includes(parts[0])?parts[0]:'home';['home','architecture','document'].forEach(id=>document.getElementById(id+'-view').hidden=id!==mode);document.title=mode==='home'?'BCJRFormer · Taimor Sabek & Haiel Bader':mode==='architecture'?'BCJRFormer · Interactive architecture':'BCJRFormer · Complete architecture document';if(mode==='architecture')requestAnimationFrame(drawWires);if(mode==='document'&&parts[1])requestAnimationFrame(()=>document.getElementById(parts[1])?.scrollIntoView());else window.scrollTo(0,0);}
window.addEventListener('hashchange',route);route();
})();`);
html=require('../.architecture-assets/update-stage1-explorer.cjs')(html);
fs.writeFileSync(target,html);
console.log(JSON.stringify({sections:toc.length,topLevelSections:toc.filter(x=>x.level==='section').length,mathExpressions:mathCount,figures:figure,bytes:Buffer.byteLength(html)}));
