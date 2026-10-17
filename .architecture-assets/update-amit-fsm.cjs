const fs=require('fs'),path=require('path');
const {graphs,tikz:rawTikz}=require('./amit-fsms.cjs');
const tikz=g=>rawTikz(g).replace('x=0.01cm,y=-0.01cm','x=0.02cm,y=-0.02cm').replace(/minimum size=0.66cm/g,'minimum size=1.32cm');
const file=path.join(__dirname,'..','docs/latex/BCJRFormer_design_review_Amit.tex');
let tex=fs.readFileSync(file,'utf8');
tex=tex.replace(/\n% BEGIN FSM DIAGRAMS[\s\S]*?% END FSM DIAGRAMS\n/,'\n');
if(!tex.includes('% BEGIN FSM DIAGRAMS')){
 tex=tex.replace('array,tikz}','array,tikz,graphicx}');
 tex=tex.replace(/\\textbf\{(?:FSM|Layer FSM|Score FSM|Softmax FSM|Weighted-value FSM|Attention schedule):\}[\s\S]*?\. /g,'');
 const groups=[['core','embed','position'],['encoder','layer','norm'],['attention','softmax','ffn'],['dot','linear','residual'],['scoreweighted','projection','aggregate']];
 const common='Circles denote states; double circles denote held completion. Enter the first state on accepted command. Unlabeled forward arrows require the current operation to finish. A blocked request, response or write remains in its state until accepted. Read and block-operation states contain request/wait substates. All controllers hold DONE until response acceptance, then return to idle. Fatal errors drain accepted work and report error; reset is required before retry.';
 let appendix='\n% BEGIN FSM DIAGRAMS\n';
 groups.forEach((ids,i)=>{appendix+='\\newpage\n\\section*{'+(5+i)+'\\quad '+['Frame and input control','Encoder and normalization control','Attention and FFN control','Shared arithmetic control','Output control'][i]+'}\n\n';if(i===0)appendix+=common+'\n\n';for(const id of ids){const g=graphs.find(x=>x.id===id);appendix+='\\subsection*{'+g.title+'}\n% FSM '+id+'\n'+tikz(g)+'\n\n'+g.note.replace(/&/g,'\\&').replace(/_/g,'\\_').replace(/</g,'$<$').replace(/>/g,'$>$')+'\n\n';}});
 appendix+='% END FSM DIAGRAMS\n';tex=tex.replace('\\end{document}',appendix+'\\end{document}');fs.writeFileSync(file,tex);
}
