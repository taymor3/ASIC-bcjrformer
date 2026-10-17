// One-time path migration after the file moves recorded in docs/organization.
const fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'..');
if(fs.existsSync(path.join(root,'docs/organization/path-updates-2026-10-10.json')))throw Error('This one-time migration has already been applied.');
const moves=JSON.parse(fs.readFileSync(path.join(root,'docs/organization/file-moves-2026-10-10.json'),'utf8'));
const mapping=Object.fromEntries(moves.map(m=>[m.old,m.new]));
const slash=p=>p.split(path.sep).join('/');
const relative=(file,target)=>slash(path.relative(path.dirname(file),path.join(root,target)));
const escaped=s=>s.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');
const files=[];
function walk(dir){for(const ent of fs.readdirSync(dir,{withFileTypes:true})){if(ent.isSymbolicLink())continue;const p=path.join(dir,ent.name);if(ent.isDirectory()){if(['BCJRFormer','.tools','node_modules','.git'].includes(ent.name))continue;walk(p);}else if(/\.(md|html|tex|cjs|mjs|py|css)$/.test(ent.name)&&!['katex.cjs','update-organized-paths.cjs'].includes(ent.name))files.push(p);}}
walk(root);const changed=[];
for(const file of files){const old=fs.readFileSync(file,'utf8');let text=old;const ext=path.extname(file);
 if(['.cjs','.mjs','.py'].includes(ext)){
  // Existing utilities use paths relative to the project root (or ../ from build folders).
  for(const [name,dest] of Object.entries(mapping))text=text.replace(new RegExp("(['\"`])((?:\\.\\.?/)*)("+escaped(name)+")\\1",'g'),(all,q,prefix)=>q+prefix+dest+q);
  if(moves.some(m=>m.new===slash(path.relative(root,file))&&m.old.endsWith('.cjs'))){
   text=text.replace(/__dirname/g,"require('path').resolve(__dirname,'..')");
   text=text.replace(/require\((['"])\.\/\.architecture-assets\//g,'require($1../.architecture-assets/');
  }
  // Generated stage filenames also need the new folders when not written as literals.
  const patterns=[[/path\.join\(root,p\.file\+'\.svg'\)/g,"projectFile(p.file+'.svg')"],[/path\.join\(root,name\+'\.png'\)/g,"projectFile(name+'.png')"],[/path\.join\(root,`Stage\$\{g\}_datapath\.drawio`\)/g,"projectFile(`Stage${g}_datapath.drawio`)"],[/path\.join\(root,g\?`Stage\$\{g\}_datapath\.drawio`:'diagrams\/drawio\/Frame_controller\.drawio'\)/g,"projectFile(g?`Stage${g}_datapath.drawio`:'Frame_controller.drawio')"]];
  let helper=false;for(const [re,repl]of patterns){if(re.test(text)){text=text.replace(re,repl);helper=true;}}
  if(helper)text="const {projectFile}=require('"+(relative(file,'scripts/project-paths.cjs').startsWith('.')?'':'./')+relative(file,'scripts/project-paths.cjs')+"');\n"+text;
 }
 if(ext==='.md'){
  // Rebase real Markdown links, including previously-valid links into unmoved rtl/output folders.
  text=text.replace(/\]\((<[^>]+>|[^)\n]+)\)/g,(all,target)=>{const wrapped=target.startsWith('<');const raw=wrapped?target.slice(1,-1):target;if(/^(https?:|codex:|#)/i.test(raw))return all;
   const prior=moves.find(m=>m.new===slash(path.relative(root,file)));const oldFile=path.join(root,prior?.old||slash(path.relative(root,file)));
   const base=raw.split('#')[0];const suffix=raw.slice(base.length);let resolved=path.isAbsolute(base)?base:path.resolve(path.dirname(oldFile),base);let rel=slash(path.relative(root,resolved));rel=mapping[rel]||rel;
   if(!fs.existsSync(path.join(root,rel)))return all;const next=relative(file,rel)+suffix;return ']('+((wrapped||next.includes(' '))?'<'+next+'>':next)+')';});
 }
 if(ext==='.html')text=text.replace(/\b(src|href)=(['"])([^'"\n]+)\2/g,(all,attr,q,url)=>{if(/^(https?:|data:|#|javascript:|blob:)/i.test(url))return all;const prior=moves.find(m=>m.new===slash(path.relative(root,file)));const oldFile=path.join(root,prior?.old||slash(path.relative(root,file)));const base=url.split(/[?#]/)[0];const suffix=url.slice(base.length);const rel=slash(path.relative(root,path.resolve(path.dirname(oldFile),base)));const target=mapping[rel]||rel;if(!fs.existsSync(path.join(root,target)))return all;return attr+'='+q+relative(file,target)+suffix+q;});
 if(ext==='.tex')text=text.replace(/\\(includegraphics(?:\[[^\]]*\])?|input|include)\{([^}]+)\}/g,(all,cmd,ref)=>{const target=mapping[ref];return target?'\\'+cmd+'{'+relative(file,target)+'}':all;});
 if(text!==old){fs.writeFileSync(file,text);changed.push(slash(path.relative(root,file)));}
}
fs.writeFileSync(path.join(root,'docs/organization/path-updates-2026-10-10.json'),JSON.stringify(changed,null,2)+'\n');
console.log(`Updated paths in ${changed.length} source/document files.`);
