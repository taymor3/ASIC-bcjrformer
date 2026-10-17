const {projectFile}=require('../scripts/project-paths.cjs');
// Hierarchical Stage 1 diagram. Each reusable block has its own page.
const fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'..');
const esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&apos;'}[c]));
const colors={data:'#1678be',control:'#c62828',unit:'#438b35',select:'#b68112',reg:'#75509e',frame:'#374151'};
const pages=[];
function page(id,name,file){const p={id,name,file,nodes:[],edges:[]};pages.push(p);return p;}
function box(p,id,x,y,w,h,label,type='data',shape='rect'){p.nodes.push({id,x,y,w,h,label,type,shape});}
function edge(p,id,a,b,from,to,via=[],type='data',both=false,label='',labelAt=null){p.edges.push({id,a,b,from,to,via,type,both,label,labelAt});}
function shell(p,title){
 box(p,'title',30,15,1440,35,title,'frame','text');
 box(p,'frame',190,75,1090,505,p.name,'frame','frame');
 box(p,'ctrl',220,125,1030,50,p.name+' controller','control');
 box(p,'command',20,125,140,50,'Start / command','control');
 box(p,'done',1320,125,160,50,'Done / error','control');
 edge(p,'start','command','ctrl',[160,150],[220,150],[],'control');
 edge(p,'done','ctrl','done',[1250,150],[1320,150],[],'control');
}
function note(p,text){box(p,'note',30,615,1440,85,text,'frame','text');}
if(require.main===module){
const top=page('stage1','Stage 1','Stage1_datapath');
shell(top,'Stage 1 — Input embedding');
box(top,'input',20,305,145,75,'Window features\nx [F]');
box(top,'nf',240,295,230,95,'Normalization block\nLength F\nPage 2','unit');
box(top,'linear',620,295,230,95,'Linear block\nF → D\nPage 3','unit');
box(top,'nd',1000,295,230,95,'Normalization block\nLength D\nPage 2','unit');
box(top,'output',1320,305,160,75,'Embedded values\ne [D]');
box(top,'copy',220,480,160,55,'Copy helper\nPage 5','unit');
box(top,'access',470,480,710,55,'Memory access: input / parameters / temporary values / output');
edge(top,'input_nf','input','nf',[165,342],[240,342]);
edge(top,'nf_linear','nf','linear',[470,342],[620,342]);
edge(top,'linear_nd','linear','nd',[850,342],[1000,342]);
edge(top,'nd_out','nd','output',[1230,342],[1320,342]);
for(const [id,x] of [['nf',355],['linear',735],['nd',1115]])edge(top,'cmd_'+id,'ctrl',id,[x,175],[x,295],[],'control',true,'command / done',[x+7,234]);
edge(top,'copy_cmd','ctrl','copy',[225,175],[220,507],[[205,175],[205,507]],'control',true);
edge(top,'copy_access','copy','access',[380,507],[470,507],[],'data',true);
edge(top,'nf_access','nf','access',[355,390],[600,480],[[355,435],[600,435]],'data',true);
edge(top,'linear_access','linear','access',[735,390],[820,480],[[735,435],[820,435]],'data',true);
edge(top,'nd_access','nd','access',[1115,390],[1080,480],[[1115,435],[1080,435]],'data',true);
note(top,'Two normalization boxes show two uses of the same hardware, each with its own parameter set.\nRun this sequence for all L tokens. Blue arrows show logical data flow; intermediate values pass through memory.\nMemory banks are omitted here. Each child block has its own controller on its detail page.');

const norm=page('normalization','Normalization','Stage1_normalization');
shell(norm,'Normalization block — reused for length F or D');
box(norm,'input',20,285,145,70,'Input values\na [J]');
box(norm,'operands',250,270,200,70,'Operand registers\ninput / gamma / beta','reg');
box(norm,'stats',250,455,200,70,'Statistics registers\nsum / mean / scale','reg');
box(norm,'mux',515,295,80,115,'Operand\nselect','select','mux');
box(norm,'add',660,280,135,55,'Add / Subtract','unit');
box(norm,'multiply',660,390,135,55,'Multiply','unit');
box(norm,'result',880,300,145,55,'Result register','reg');
box(norm,'convert',1080,300,160,55,'Round / saturate','unit');
box(norm,'rsqrt',880,455,210,70,'Inverse square root\nBlack box','unit');
box(norm,'access',20,470,145,65,'Memory / constant\naccess');
box(norm,'output',1320,295,160,70,'Normalized values\no [J]');
edge(norm,'in','input','operands',[165,320],[250,305]);
edge(norm,'ops_mux','operands','mux',[450,305],[515,325]);
edge(norm,'stats_mux','stats','mux',[450,490],[515,385],[[480,490],[480,385]]);
edge(norm,'mux_add','mux','add',[595,315],[660,307]);
edge(norm,'mux_mul','mux','multiply',[595,390],[660,417],[[625,390],[625,417]]);
edge(norm,'add_result','add','result',[795,307],[880,315]);
edge(norm,'mul_result','multiply','result',[795,417],[950,355],[[835,417],[835,380],[950,380]]);
edge(norm,'result_convert','result','convert',[1025,327],[1080,327]);
edge(norm,'converted_out','convert','output',[1240,327],[1320,327]);
edge(norm,'stats_result','result','stats',[880,342],[450,505],[[850,342],[850,550],[475,550],[475,505]]);
edge(norm,'result_rsqrt','result','rsqrt',[990,355],[990,455]);
edge(norm,'sqrt_stats','rsqrt','stats',[880,490],[450,480],[[810,490],[810,535],[475,535],[475,480]]);
edge(norm,'result_mux','result','mux',[900,300],[555,295],[[900,240],[555,240]]);
edge(norm,'mem_operands','access','operands',[95,470],[300,340],[[95,430],[300,430]],'data',false);
edge(norm,'mem_stats','access','stats',[165,503],[250,503]);
edge(norm,'ctrl_mux','ctrl','mux',[535,175],[535,295],[],'control');
edge(norm,'ctrl_math','ctrl','multiply',[780,175],[795,417],[[820,175],[820,417]],'control');
edge(norm,'ctrl_sqrt','ctrl','rsqrt',[1100,175],[1090,490],[[1260,175],[1260,560],[1110,560],[1110,490]],'control');
note(norm,'J = F or D. The controller selects operations and register loads; the same add/subtract and multiply units are reused.\nMean → variance → inverse square root → normalize → gamma / beta → convert and write.\nThe memory-access port supplies parameters and constants; no memory banks are drawn.');

const lin=page('linear','Linear','Stage1_linear');
shell(lin,'Linear block — F inputs to D outputs');
box(lin,'input',20,300,145,70,'Input values\nu [F]');
box(lin,'bias',260,300,160,65,'Bias register','reg');
box(lin,'dot',575,290,235,100,'Dot-product block\nPage 4','unit');
box(lin,'convert',980,310,220,65,'Round / saturate','unit');
box(lin,'output',1320,310,160,65,'Linear results\nv [D]');
box(lin,'access',360,480,775,55,'Memory access: inputs / weights / biases / result writes');
edge(lin,'input_dot','input','dot',[165,335],[575,320],[[190,335],[190,250],[535,250],[535,320]]);
edge(lin,'bias_init','bias','dot',[420,345],[575,365],[[500,345],[500,365]],'data',false,'initial sum',[425,390]);
edge(lin,'dot_convert','dot','convert',[810,340],[980,342]);
edge(lin,'linear_out','convert','output',[1200,342],[1320,342]);
edge(lin,'memory_bias','access','bias',[395,480],[340,365],[[395,430],[340,430]]);
edge(lin,'memory_dot','access','dot',[690,480],[690,390],[],'data',true);
edge(lin,'memory_write','convert','access',[1090,375],[1090,480]);
edge(lin,'ctrl_dot','ctrl','dot',[690,175],[690,290],[],'control',true,'command / result',[700,235]);
edge(lin,'ctrl_bias','ctrl','bias',[340,175],[340,300],[],'control');
edge(lin,'ctrl_convert','ctrl','convert',[1090,175],[1090,310],[],'control');
note(lin,'For each output j: read bias → request one F-term dot → convert → write. Repeat for all D outputs.\nThe linear controller owns result writes. The dot-product block returns a wide sum and has its own controller.');

const dot=page('dot','Dot product','Stage1_dot_product');
shell(dot,'Dot-product block — shared multiply–accumulate');
box(dot,'input',20,285,145,90,'Operand reads\nA and B');
box(dot,'a',260,265,120,60,'A register','reg');
box(dot,'b',260,410,120,60,'B register','reg');
box(dot,'mult',470,335,135,60,'Multiply','unit');
box(dot,'add',730,335,100,60,'Add','unit');
box(dot,'acc',1010,335,210,60,'Accumulator','reg');
box(dot,'init',740,490,205,55,'Initial sum\nBias or zero');
box(dot,'output',1320,330,160,75,'Wide dot result');
edge(dot,'read_a','input','a',[165,305],[260,295]);
edge(dot,'read_b','input','b',[165,355],[260,440],[[220,355],[220,440]]);
edge(dot,'a_mult','a','mult',[380,295],[470,350],[[430,295],[430,350]]);
edge(dot,'b_mult','b','mult',[380,440],[470,380],[[430,440],[430,380]]);
edge(dot,'mult_add','mult','add',[605,365],[730,365]);
edge(dot,'add_acc','add','acc',[830,365],[1010,365]);
edge(dot,'acc_output','acc','output',[1220,365],[1320,365]);
edge(dot,'acc_add','acc','add',[1115,395],[780,395],[[1115,450],[780,450]]);
edge(dot,'bias_acc','init','acc',[945,517],[1150,395],[[1150,517]]);
edge(dot,'ctrl_a','ctrl','a',[320,175],[320,265],[],'control');
edge(dot,'ctrl_mult','ctrl','mult',[535,175],[535,335],[],'control');
edge(dot,'ctrl_acc','ctrl','acc',[1115,175],[1115,335],[],'control');
note(dot,'Read A → read B → multiply → add to accumulator → next term. Initialize the accumulator only once per output.\nReturn the wide sum after all terms. This block does not round, saturate or write the linear output.');

const copy=page('copy','Copy','Stage1_copy');
shell(copy,'Copy helper — input loading and output storing');
box(copy,'input',20,320,145,70,'Read response');
box(copy,'saved',470,325,210,60,'Value register','reg');
box(copy,'output',1320,320,160,70,'Write request');
box(copy,'access',420,480,750,55,'Memory access: source / destination addresses and responses');
edge(copy,'read_saved','input','saved',[165,355],[470,355]);
edge(copy,'saved_write','saved','output',[680,355],[1320,355]);
edge(copy,'ctrl_saved','ctrl','saved',[575,175],[575,325],[],'control');
edge(copy,'ctrl_access','ctrl','access',[1110,175],[1110,480],[],'control');
edge(copy,'mem_saved','access','saved',[575,480],[575,385],[],'data',true);
note(copy,'Read one value → save it → write it → wait for write confirmation → advance the index.\nCopy preserves the stored number format. Use F values for loading a window and D values for storing its embedding.');
}

function port(p,n){return [(p[0]-n.x)/n.w,(p[1]-n.y)/n.h];}
function xml(p){
 const ids=new Set(p.nodes.map(n=>n.id));if(ids.size!==p.nodes.length)throw Error('Duplicate node');
 const byId=Object.fromEntries(p.nodes.map(n=>[n.id,n]));
 const nodes=p.nodes.map(n=>{
  const style=['html=1','whiteSpace=wrap','fontFamily=Helvetica','fontSize=16','fillColor=#ffffff','strokeColor='+colors[n.type],'fontColor='+colors[n.type],'strokeWidth=2','rounded=0'];
  if(n.shape==='frame')style.push('dashed=1','align=left','verticalAlign=top','spacingLeft=12','spacingTop=8');
  if(n.shape==='text')style.push('strokeColor=none','fillColor=none','fontColor=#263442',n.id==='title'?'fontSize=24':'fontSize=15');
  if(n.shape==='mux')style.push('shape=trapezoid','direction=east');
  if(n.shape==='circle')style.push('shape=ellipse','perimeter=ellipsePerimeter');
  return '<mxCell id="'+n.id+'" value="'+esc(n.label.replace(/\n/g,'<br>'))+'" style="'+style.join(';')+';" vertex="1" parent="1"><mxGeometry x="'+n.x+'" y="'+n.y+'" width="'+n.w+'" height="'+n.h+'" as="geometry"/></mxCell>';
 }).join('\n');
 const edges=p.edges.map(e=>{
  if(!ids.has(e.a)||!ids.has(e.b))throw Error('Missing edge endpoint');
  const [ex,ey]=port(e.from,byId[e.a]),[ix,iy]=port(e.to,byId[e.b]);
  const style='edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;endArrow=block;endFill=1;strokeWidth=1.8;strokeColor='+colors[e.type]+';fontColor='+colors[e.type]+';fontSize=13;labelBackgroundColor=#ffffff;exitX='+ex+';exitY='+ey+';entryX='+ix+';entryY='+iy+';'+(e.both?'startArrow=block;startFill=1;':'')+(e.type==='control'?'dashed=1;':'');
  return '<mxCell id="edge_'+e.id+'" value="'+esc(e.label)+'" style="'+style+'" edge="1" parent="1" source="'+e.a+'" target="'+e.b+'"><mxGeometry relative="1" as="geometry">'+(e.via.length?'<Array as="points">'+e.via.map(([x,y])=>'<mxPoint x="'+x+'" y="'+y+'"/>').join('')+'</Array>':'')+'</mxGeometry></mxCell>';
 }).join('\n');
 return '<diagram id="'+p.id+'" name="'+esc(p.name)+'"><mxGraphModel dx="1500" dy="720" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1500" pageHeight="720"><root><mxCell id="0"/><mxCell id="1" parent="0"/>\n'+nodes+'\n'+edges+'\n</root></mxGraphModel></diagram>';
}
function svg(p){
 let out='<svg xmlns="http://www.w3.org/2000/svg" width="1500" height="720" viewBox="0 0 1500 720"><rect width="1500" height="720" fill="white"/><defs>';
 for(const [id,c] of Object.entries(colors))out+='<marker id="'+id+'" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10Z" fill="'+c+'"/></marker>';
 out+='</defs>';
 const shape=n=>n.shape==='text'?'':n.shape==='mux'?'<path d="M'+n.x+' '+n.y+' L'+(n.x+n.w)+' '+(n.y+16)+' L'+(n.x+n.w)+' '+(n.y+n.h-16)+' L'+n.x+' '+(n.y+n.h)+'Z" fill="white" stroke="'+colors[n.type]+'" stroke-width="2"/>':'<rect x="'+n.x+'" y="'+n.y+'" width="'+n.w+'" height="'+n.h+'" fill="white" stroke="'+colors[n.type]+'" stroke-width="2"'+(n.shape==='frame'?' stroke-dasharray="7 5"':'')+'/>';
 const renderShape=n=>n.shape==='circle'?'<ellipse cx="'+(n.x+n.w/2)+'" cy="'+(n.y+n.h/2)+'" rx="'+n.w/2+'" ry="'+n.h/2+'" fill="white" stroke="'+colors[n.type]+'" stroke-width="2"/>':shape(n);
 for(const n of p.nodes.filter(n=>n.shape==='frame'))out+=renderShape(n);
 for(const e of p.edges)out+='<polyline points="'+[e.from,...e.via,e.to].map(p=>p.join(',')).join(' ')+'" fill="none" stroke="'+colors[e.type]+'" stroke-width="1.8" marker-end="url(#'+e.type+')"'+(e.both?' marker-start="url(#'+e.type+')"':'')+(e.type==='control'?' stroke-dasharray="6 5"':'')+'/>';
 for(const n of p.nodes){if(n.shape!=='frame')out+=renderShape(n);const lines=n.label.split('\n'),size=n.id==='title'?24:n.shape==='text'?15:16,cx=n.shape==='frame'?n.x+12:n.x+n.w/2,y=n.shape==='frame'?n.y+23:n.y+n.h/2-(lines.length-1)*11+5;out+='<text fill="'+(n.shape==='text'?'#263442':colors[n.type])+'" font-family="Arial,sans-serif" font-size="'+size+'" text-anchor="'+(n.shape==='frame'?'start':'middle')+'">'+lines.map((l,i)=>'<tspan x="'+cx+'" y="'+(y+i*22)+'">'+esc(l)+'</tspan>').join('')+'</text>';}
 for(const e of p.edges.filter(e=>e.labelAt))out+='<text x="'+e.labelAt[0]+'" y="'+e.labelAt[1]+'" fill="'+colors[e.type]+'" font-family="Arial" font-size="13">'+esc(e.label)+'</text>';
 return out+'</svg>\n';
}
if(require.main===module){
fs.writeFileSync(path.join(root,'diagrams/drawio/Stage1_datapath.drawio'),'<?xml version="1.0" encoding="UTF-8"?>\n<mxfile host="app.diagrams.net" type="device">'+pages.map(xml).join('\n')+'</mxfile>\n');
for(const p of pages)fs.writeFileSync(projectFile(p.file+'.svg'),svg(p));
console.log(JSON.stringify({pages:pages.map(p=>p.name),file:'diagrams/drawio/Stage1_datapath.drawio'}));
}
module.exports={root,pages,page,box,edge,shell,note,xml,svg};
