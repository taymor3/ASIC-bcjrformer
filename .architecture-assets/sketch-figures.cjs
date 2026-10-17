const fs=require('fs');
const vm=require('vm');
const escape=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const pages={core:{nodes:[{id:'enc'}]},embed:{},position:{},final:{},aggregate:{}};
const context={pages,page:(id,title,why,formula,input,output,hw,source,extra)=>pages[id]={title,why,input,output,...extra},n:(id,key,col,row,label,sub,kind)=>({id,key,col,row,label,sub,kind}),e:(a,b,type='data')=>({a,b,type}),graph:(id,nodes,edges)=>Object.assign(pages[id],{nodes,edges})};
vm.runInNewContext(fs.readFileSync(__dirname+'/encoder-sketch.js','utf8'),context);
vm.runInNewContext(fs.readFileSync(__dirname+'/rtl-draft.js','utf8'),context);
module.exports=['encoder','ln1','ffn','mha'].map(id=>{
 const p=pages[id],nodes=p.nodes.filter(n=>!['fsm','controller'].includes(n.id));
 const h=Math.max(...nodes.map(n=>n.row))*125+30;
 const pos=Object.fromEntries(nodes.map(n=>[n.id,{x:20+(n.col-1)*250,y:20+(n.row-1)*125}]));
 const paths=p.edges.map(e=>{const a=pos[e.a],b=pos[e.b];let d;
 if(a.x===b.x){d=b.y-a.y>150?(e.a==='in'?`M ${a.x} ${a.y+40} H ${a.x-15} V ${b.y+40} H ${b.x}`:`M ${a.x+215} ${a.y+40} H ${a.x+235} V ${b.y+40} H ${b.x+215}`):`M ${a.x+107.5} ${a.y+80} V ${b.y}`;}
 else if(a.y===b.y){d=a.x<b.x?`M ${a.x+215} ${a.y+40} H ${b.x}`:`M ${a.x} ${a.y+40} H ${b.x+215}`;}
 else if(b.y-a.y>150){const right=a.x>b.x,lane=right?b.x+235:b.x-15;d=`M ${a.x+(right?0:215)} ${a.y+40} H ${lane} V ${b.y+40} H ${b.x+(right?215:0)}`;}
 else{d=`M ${a.x+107.5} ${a.y+80} V ${a.y+100} H ${b.x+107.5} V ${b.y}`;}
 return `<path d="${d}" fill="none" stroke="${e.type==='mask'?'#9c6500':'#315c8d'}" stroke-width="2" ${e.type==='mask'?'stroke-dasharray="5 4"':''} marker-end="url(#arrow-${id})"/>`;
 }).join('');
 function lines(s,limit){const words=s.split(' '),out=[];let line='';for(const w of words){if((line+' '+w).length>limit&&line){out.push(line);line=w;}else line+=(line?' ':'')+w;}if(line)out.push(line);return out;}
 const boxes=nodes.map(n=>{const a=pos[n.id],label=lines(n.label,25),sub=lines(n.sub||'',30);return `<rect x="${a.x}" y="${a.y}" width="215" height="80" rx="6" fill="#fff" stroke="#7084a3"/><text x="${a.x+107.5}" y="${a.y+22}" text-anchor="middle" fill="#202c42" font-family="Arial" font-size="15">${label.map((t,i)=>`<tspan x="${a.x+107.5}" dy="${i?17:0}">${escape(t)}</tspan>`).join('')}${sub.map((t,i)=>`<tspan x="${a.x+107.5}" dy="${i?14:20}" font-size="11">${escape(t)}</tspan>`).join('')}</text>`;}).join('');
 return `<div class="paper-figure"><svg viewBox="0 0 750 ${h}" role="img" aria-label="${escape(p.title)}" style="width:100%;display:block"><defs><marker id="arrow-${id}" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10z" fill="#315c8d"/></marker></defs>${paths}${boxes}</svg></div>`;
});
