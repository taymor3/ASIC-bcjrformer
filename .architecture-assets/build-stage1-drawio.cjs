// One editable draw.io page and a matching SVG preview; all positions are shared.
const fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'..');
const X=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&apos;'}[c]));
const colors={memory:'#1678be',control:'#c62828',arithmetic:'#438b35',select:'#b68112',register:'#75509e',outline:'#374151'};
const nodes=[];const edges=[];
function box(id,x,y,w,h,label,type='memory',shape='rect'){nodes.push({id,x,y,w,h,label,type,shape});}
function line(id,a,b,from,to,via=[],type='memory',double=false,label=''){edges.push({id,a,b,from,to,via,type,double,label});}
box('title',40,18,1320,30,'Stage 1 — Input embedding','outline','text');
box('stage',40,65,1320,50,'Stage 1 controller','control');
box('frame',20,150,1360,575,'Stage 1 datapath','outline','frame');
box('feature',55,205,180,75,'Feature bank\nL × F values');
box('parameter',295,205,245,75,'Parameter memory\nWeights, bias, gamma, beta');
box('token',610,205,190,75,'Token scratch\nx → u   [F]');
box('result',875,205,190,75,'Result scratch\nv → e   [D]');
box('output',1140,205,190,75,'X bank\nL × D embeddings');
box('bankselect',265,345,845,55,'Memory access / bank selector','select');
box('nf',70,445,610,240,'Normalization engine — reused for F and D','outline','frame');
box('nc',90,474,570,28,'Normalization controller','control');
box('nr',100,525,85,45,'Input reg.','register');
box('sel',240,528,72,92,'Select','select','mux');
box('add',350,525,95,45,'Add / Sub','arithmetic');
box('mult',350,600,95,45,'Multiply','arithmetic');
box('nresult',510,535,115,45,'Result reg.','register');
box('stats',100,620,172,45,'Statistics registers','register');
box('sqrt',510,620,115,45,'1 / √q\nBlack box','arithmetic');
box('mf',745,445,590,240,'Shared dot-product engine','outline','frame');
box('mc',765,474,550,28,'Dot controller','control');
box('a',770,525,90,45,'A reg.','register');
box('b',770,620,90,45,'B reg.','register');
box('macmult',905,568,100,45,'Multiply','arithmetic');
box('macadd',1060,568,75,45,'Add','arithmetic');
box('acc',1190,568,115,45,'Accumulator\nBias init.','register');
box('note',40,743,1320,45,'For each token: normalize F → linear F-to-D → normalize D → store in X.\nBlue: data access   •   Red dashed: control   •   Registers retain values while operations wait.','outline','text');
line('control_bank','stage','bankselect',[350,115],[350,345],[[350,175],[570,175],[570,325],[350,325]],'control',false,'bank / read / write');
line('control_norm','stage','nc',[45,115],[90,488],[[45,420],[80,420],[80,488]],'control',false);
line('control_dot','stage','mc',[1360,115],[1315,488],[[1370,420],[1330,420],[1330,488]],'control',false);
line('feature_bus','feature','bankselect',[145,280],[300,345],[[145,315],[300,315]]);
line('parameters_bus','parameter','bankselect',[415,280],[415,345]);
line('token_bus','token','bankselect',[705,280],[705,345],[],'memory',true);
line('result_bus','result','bankselect',[970,280],[970,345],[],'memory',true);
line('bus_x','bankselect','output',[1060,345],[1230,280],[[1060,315],[1230,315]]);
line('bus_norm','bankselect','nr',[285,400],[143,525],[[285,420],[143,420]]);
line('norm_write','nresult','bankselect',[625,558],[650,400],[[700,558],[700,420],[650,420]]);
line('bus_a','bankselect','a',[820,400],[815,525],[[820,420],[815,420]]);
line('bus_b','bankselect','b',[1110,373],[770,643],[[1395,373],[1395,705],[720,705],[720,643]]);
line('acc_store','acc','bankselect',[1305,590],[1030,400],[[1350,590],[1350,420],[1030,420]],'memory',false,'convert / write');
line('input_sel','nr','sel',[185,548],[240,550]);
line('stats_sel','stats','sel',[186,620],[240,597],[[186,597]]);
line('sel_add','sel','add',[312,548],[350,548]);
line('sel_mul','sel','mult',[312,600],[350,623],[[330,600],[330,623]]);
line('add_result','add','nresult',[445,548],[510,548]);
line('mul_result','mult','nresult',[445,623],[550,580],[[475,623],[475,597],[550,597]]);
line('result_feedback','nresult','stats',[568,580],[272,643],[[460,580],[460,676],[290,676],[290,643]]);
line('result_sqrt','nresult','sqrt',[605,580],[605,620]);
line('sqrt_stats','sqrt','stats',[510,643],[272,653],[[485,643],[485,672],[300,672],[300,653]]);
line('a_mult','a','macmult',[860,548],[905,580],[[882,548],[882,580]]);
line('b_mult','b','macmult',[860,643],[905,602],[[882,643],[882,602]]);
line('mult_add','macmult','macadd',[1005,590],[1060,590]);
line('add_acc','macadd','acc',[1135,590],[1190,590]);
line('acc_feedback','acc','macadd',[1248,613],[1098,613],[[1248,655],[1098,655]]);
line('norm_feedback_sel','nresult','sel',[510,566],[272,528],[[490,566],[490,515],[272,515]]);

const byId=Object.fromEntries(nodes.map(n=>[n.id,n]));
for(const e of edges)if(!byId[e.a]||!byId[e.b])throw Error('Missing endpoint');
function port(p,n){return [(p[0]-n.x)/n.w,(p[1]-n.y)/n.h];}
const vertices=nodes.map(n=>{
 const c=colors[n.type];
 const styles=['html=1','whiteSpace=wrap','fontFamily=Helvetica','fontSize=16','fillColor=#ffffff','strokeColor='+c,'fontColor='+c,'strokeWidth=2','rounded=0'];
 if(n.shape==='frame')styles.push('dashed=1','verticalAlign=top','align=left','spacingTop=8','spacingLeft=10','fontSize=15');
 if(n.shape==='text')styles.push('strokeColor=none','fillColor=none','fontColor=#263442',n.id==='title'?'fontSize=23':'fontSize=14');
 if(n.shape==='mux')styles.push('shape=trapezoid','direction=east');
 return '<mxCell id="'+n.id+'" value="'+X(n.label.replace(/\n/g,'<br>'))+'" style="'+styles.join(';')+';" vertex="1" parent="1"><mxGeometry x="'+n.x+'" y="'+n.y+'" width="'+n.w+'" height="'+n.h+'" as="geometry"/></mxCell>';
}).join('\n');
const links=edges.map(e=>{
 const [ex,ey]=port(e.from,byId[e.a]),[ix,iy]=port(e.to,byId[e.b]);
 const style='edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;endArrow=block;endFill=1;strokeWidth=1.8;strokeColor='+colors[e.type]+';fontColor='+colors[e.type]+';fontSize=13;labelBackgroundColor=#ffffff;exitX='+ex+';exitY='+ey+';entryX='+ix+';entryY='+iy+';'+(e.double?'startArrow=block;startFill=1;':'')+(e.type==='control'?'dashed=1;':'');
 return '<mxCell id="'+e.id+'" value="'+X(e.label)+'" style="'+style+'" edge="1" parent="1" source="'+e.a+'" target="'+e.b+'"><mxGeometry relative="1" as="geometry">'+(e.via.length?'<Array as="points">'+e.via.map(([x,y])=>'<mxPoint x="'+x+'" y="'+y+'"/>').join('')+'</Array>':'')+'</mxGeometry></mxCell>';
}).join('\n');
const drawio='<?xml version="1.0" encoding="UTF-8"?>\n<mxfile host="app.diagrams.net" type="device"><diagram id="stage1" name="Stage 1 datapath"><mxGraphModel dx="1420" dy="810" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1420" pageHeight="810"><root><mxCell id="0"/><mxCell id="1" parent="0"/>\n'+vertices+'\n'+links+'\n</root></mxGraphModel></diagram></mxfile>\n';
let svg='<svg xmlns="http://www.w3.org/2000/svg" width="1420" height="810" viewBox="0 0 1420 810"><rect width="1420" height="810" fill="white"/><defs>';
for(const [type,c] of Object.entries(colors))svg+='<marker id="arrow-'+type+'" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10 Z" fill="'+c+'"/></marker>';
svg+='</defs>';
function shape(n){const c=colors[n.type];let out='';
 if(n.shape==='mux')out='<path d="M'+n.x+' '+n.y+' L'+(n.x+n.w)+' '+(n.y+16)+' L'+(n.x+n.w)+' '+(n.y+n.h-16)+' L'+n.x+' '+(n.y+n.h)+' Z"';
 else if(n.shape!=='text')out='<rect x="'+n.x+'" y="'+n.y+'" width="'+n.w+'" height="'+n.h+'"'+(n.shape==='frame'?' stroke-dasharray="7 5"':'');
 if(out)out+=' fill="white" stroke="'+c+'" stroke-width="2"/>';
 return out;
}
// Containers under the connections; other boxes over them.
for(const n of nodes.filter(n=>n.shape==='frame'))svg+=shape(n);
for(const e of edges){const pts=[e.from,...e.via,e.to];svg+='<polyline points="'+pts.map(p=>p.join(',')).join(' ')+'" fill="none" stroke="'+colors[e.type]+'" stroke-width="1.8" marker-end="url(#arrow-'+e.type+')"'+(e.double?' marker-start="url(#arrow-'+e.type+')"':'')+(e.type==='control'?' stroke-dasharray="6 5"':'')+'/>';}
for(const n of nodes){if(n.shape!=='frame')svg+=shape(n);const lines=n.label.split('\n'),size=n.id==='title'?23:n.shape==='text'?14:n.shape==='frame'?15:16;const cx=n.shape==='frame'?n.x+12:n.x+n.w/2;const start=n.shape==='frame'?n.y+22:n.y+n.h/2-(lines.length-1)*10+5;svg+='<text fill="'+(n.shape==='text'?'#263442':colors[n.type])+'" font-family="Arial, sans-serif" font-size="'+size+'" text-anchor="'+(n.shape==='frame'?'start':'middle')+'">'+lines.map((l,i)=>'<tspan x="'+cx+'" y="'+(start+i*20)+'">'+X(l)+'</tspan>').join('')+'</text>';}
// Sparse connection labels, kept outside boxes.
svg+='<text x="445" y="168" fill="'+colors.control+'" font-family="Arial" font-size="13">bank / read / write</text><text x="1190" y="415" fill="'+colors.memory+'" font-family="Arial" font-size="13">convert / write</text></svg>\n';
fs.writeFileSync(path.join(root,'diagrams/drawio/Stage1_datapath.drawio'),drawio);
fs.writeFileSync(path.join(root,'images/stage1/Stage1_datapath.svg'),svg);
console.log(JSON.stringify({boxes:nodes.length,connections:edges.length,files:['diagrams/drawio/Stage1_datapath.drawio','images/stage1/Stage1_datapath.svg']}));
