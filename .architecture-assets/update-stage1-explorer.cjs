const fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'..');
const esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function inline(s){return esc(s).replace(/`([^`]+)`/g,'<code>$1</code>').replace(/\*\*([^*]+)\*\*/g,'<strong>$1</strong>');}
function markdown(text){
 const lines=text.split(/\r?\n/),out=[];let i=0;
 while(i<lines.length){const line=lines[i].trim();
  if(!line){i++;continue;}
  if(line.startsWith('```')){i++;while(i<lines.length&&!lines[i].trim().startsWith('```'))i++;i++;continue;}
  const heading=line.match(/^(#{3,5})\s+(.+)$/);if(heading){out.push('<'+(heading[1].length===5?'h4':'h3')+'>'+inline(heading[2])+'</'+(heading[1].length===5?'h4':'h3')+'>');i++;continue;}
  if(line.startsWith('|')){
   const rows=[];while(i<lines.length&&lines[i].trim().startsWith('|')){const raw=lines[i++].trim();if(/^\|[\s:|\-]+\|$/.test(raw))continue;rows.push(raw.split('|').slice(1,-1).map(x=>x.trim()));}
   const width=rows[0].length;if(rows.some(r=>r.length!==width))throw Error('Malformed Markdown table');
   out.push('<div class="s1-table" tabindex="0" role="region" aria-label="Scrollable specification table"><table><thead><tr>'+rows[0].map(c=>'<th scope="col">'+inline(c)+'</th>').join('')+'</tr></thead><tbody>'+rows.slice(1).map(r=>'<tr>'+r.map(c=>'<td>'+inline(c)+'</td>').join('')+'</tr>').join('')+'</tbody></table></div>');continue;
  }
  if(line.startsWith('- ')){const items=[];while(i<lines.length&&lines[i].trim().startsWith('- '))items.push('<li>'+inline(lines[i++].trim().slice(2))+'</li>');out.push('<ul>'+items.join('')+'</ul>');continue;}
  const paragraph=[line];i++;while(i<lines.length&&lines[i].trim()&&!/^(#|\||```|- )/.test(lines[i].trim()))paragraph.push(lines[i++].trim());out.push('<p>'+inline(paragraph.join(' '))+'</p>');
 }
 return out.join('\n');
}
function sections(){
 const spec=fs.readFileSync(path.join(root,'docs/rtl/RTL-specification.md'),'utf8');
 const start=spec.indexOf('### Stage 1 input embedding'),end=spec.indexOf('### Stage 2 position',start);
 if(start<0||end<0)throw Error('Stage 1 specification boundaries missing');
 const stage=spec.slice(start,end);
 const markers=['#### Internal arithmetic:','#### Stage 1 memory banks','#### Stage 1 control paths','#### Stage 1 main FSM','#### Stage 1 number formats'];
 const positions=markers.map(x=>stage.indexOf(x));if(positions.some(x=>x<0))throw Error('Missing Stage 1 section');
 const chunks={overview:stage.slice(0,positions[0]),arithmetic:stage.slice(positions[0],positions[1]),memory:stage.slice(positions[1],positions[2]),control:stage.slice(positions[2],positions[3]),fsm:stage.slice(positions[3],positions[4]),formats:stage.slice(positions[4])};
 const a=chunks.arithmetic;
 chunks.normalization=a.slice(a.indexOf('##### Blocks 1'),a.indexOf('##### Block 2'));
 chunks.linear=a.slice(a.indexOf('##### Block 2'),a.indexOf('##### Stage 1 arithmetic summary'));
 return Object.fromEntries(Object.entries(chunks).map(([k,v])=>[k,markdown(v)]));
}
function attach(html){
 html=html.replace(/<!-- BEGIN STAGE1 STYLE -->[\s\S]*?<!-- END STAGE1 STYLE -->\s*/g,'').replace(/\/\/ BEGIN STAGE1 EXPLORER\n[\s\S]*?\/\/ END STAGE1 EXPLORER\n/g,'');
 const css=fs.readFileSync(path.join(__dirname,'stage1-explorer.css'),'utf8');
 html=html.replace('</head>','<!-- BEGIN STAGE1 STYLE --><style>'+css+'</style><!-- END STAGE1 STYLE -->\n</head>');
 const anchor="const graphEl=document.getElementById('graph');";
 if(!html.includes(anchor))throw Error('Explorer insertion point missing');
 const payload=JSON.stringify(sections()).replace(/</g,'\\u003c');
 const js=fs.readFileSync(path.join(__dirname,'stage1-explorer.js'),'utf8');
 html=html.replace(anchor,'// BEGIN STAGE1 EXPLORER\nconst stage1Sections='+payload+';\n'+js+'\n// END STAGE1 EXPLORER\n'+anchor);
 const renderHook=' renderStage1Details(p,key);\n';
 if(!html.includes(renderHook)){
  const nodeMarker=' const nodes=p.nodes||';if(!html.includes(nodeMarker))throw Error('Render hook missing');
  html=html.replace(nodeMarker,renderHook+nodeMarker);
 }
 const graphMarker="graphEl.classList.toggle('boundary-graph',key==='system');";
 if(!html.includes("graphEl.classList.toggle('s1-fsm'"))html=html.replace(graphMarker,graphMarker+"graphEl.classList.toggle('s1-fsm',!!p.fsmView);");
 const nodeHook="if(p.fsmView&&v.label==='DONE')el.classList.add('s1-terminal');";
 if(!html.includes(nodeHook))html=html.replace("if(v.key==='core')",nodeHook+"if(v.key==='core')");
 const drawHook='// Stage 1 FSM loops and condition labels';
 if(!html.includes(drawHook)){
  const pathMarker=" const path=document.createElementNS(ns,'path');path.dataset.from";
  html=html.replace(pathMarker," if(p.fsmView&&edge.a===edge.b){const lane=a.x+a.w+28;d=`M ${a.x+a.w} ${a.y+a.h*.35} H ${lane} V ${a.y+a.h*.65} H ${a.x+a.w}`;}\n"+pathMarker);
  const svgMarker=' });graphEl.prepend(svg);';
  if(!html.includes(svgMarker))throw Error('Wire drawing hook missing');
  html=html.replace(svgMarker,`\n ${drawHook}
 if(p.stage1&&edge.label){
  const label=document.createElementNS(ns,'text');label.setAttribute('class','s1-edge-label');label.setAttribute('text-anchor','middle');
  label.dataset.edgeLabel=edge.label;
  // SVG path metrics are available after attachment, so position in the next frame.
  label.textContent=edge.label;svg.append(label);
  requestAnimationFrame(()=>{if(!path.isConnected)return;const pt=path.getPointAtLength(path.getTotalLength()/2);label.setAttribute('x',pt.x);label.setAttribute('y',pt.y-8);});
 }
 });graphEl.prepend(svg);`);
 }
 const routeMarker="if(mode==='architecture')requestAnimationFrame(drawWires);";
 if(html.includes(routeMarker))html=html.replace(routeMarker,"if(mode==='architecture'){if(parts[1]&&pages[parts[1]]){trail=['system','core',parts[1]];render();}requestAnimationFrame(drawWires);}");
 return html;
}
module.exports=attach;
if(require.main===module){const file=path.join(root,'web/bcjrformer-architecture.html');const out=attach(fs.readFileSync(file,'utf8'));fs.writeFileSync(file,out);console.log(JSON.stringify({updated:'Stage 1',bytes:Buffer.byteLength(out),sections:Object.keys(sections())}));}
