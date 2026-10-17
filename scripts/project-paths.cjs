// Resolve artifact names consistently for generators that use computed filenames.
const fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'..');
const moves=JSON.parse(fs.readFileSync(path.join(root,'docs/organization/file-moves-2026-10-10.json'),'utf8'));
const names=Object.fromEntries(moves.map(m=>[m.old,m.new]));
function projectFile(name){return path.join(root,names[name]||name);}
module.exports={projectFile};
