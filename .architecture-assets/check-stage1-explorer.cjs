// Static checks: no browser access or rendering.
const fs=require('fs'),vm=require('vm'),path=require('path');
const root=path.resolve(__dirname,'..'),file=path.join(root,'web/bcjrformer-architecture.html');
const html=fs.readFileSync(file,'utf8');
for(const match of html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g))new vm.Script(match[1]);
const sectionsLine=html.match(/const stage1Sections=(.+);\n/);if(!sectionsLine)throw Error('Missing content');
const content=JSON.parse(sectionsLine[1]);
const pages={},ctx={pages,stage1Sections:content,
 page:(id,title,why,formula,input,output,hw,source,extra)=>pages[id]={title,why,formula,input,output,hw,source,...extra},
 n:(id,key,col,row,label,sub,kind)=>({id,key,col,row,label,sub,kind}),
 e:(a,b,type='data')=>({a,b,type}),
 graph:(id,nodes,edges)=>Object.assign(pages[id],{nodes,edges})};
vm.runInNewContext(fs.readFileSync(path.join(__dirname,'stage1-explorer.js'),'utf8'),ctx);
for(const [id,p] of Object.entries(pages)){
 if(!p.detailHtml)throw Error('No explanation: '+id);
 const nodes=p.nodes||[];const names=new Set(nodes.map(n=>n.id));
 if(names.size!==nodes.length)throw Error('Duplicate node: '+id);
 for(const node of nodes)if(node.key&&!pages[node.key])throw Error('Missing clickable page '+node.key);
 for(const edge of p.edges||[])if(!names.has(edge.a)||!names.has(edge.b))throw Error('Broken edge: '+id);
 if(p.fsmView){if(!nodes.some(n=>n.label==='DONE'))throw Error('No done state');if(!(p.edges||[]).some(e=>e.label==='reset'))throw Error('No error reset path');}
}
const markdown=fs.readFileSync(path.join(root,'docs/rtl/RTL-specification.md'),'utf8');
const stage=markdown.slice(markdown.indexOf('### Stage 1 input embedding'),markdown.indexOf('### Stage 2 position'));
for(const line of stage.split(/\r?\n/).filter(l=>/^#{4,5} /.test(l)))if(!Object.values(content).some(s=>s.includes(line.replace(/^#+ /,''))))throw Error('Missing heading: '+line);
const attach=require('./update-stage1-explorer.cjs');if(attach(html)!==html)throw Error('Updater is not idempotent');
console.log(JSON.stringify({syntax:'passed',stage1Pages:Object.keys(pages).length,sections:Object.keys(content).length,graphLinks:'passed',specHeadings:'all included',repeatUpdate:'stable',visualRendering:'not checked'}));
