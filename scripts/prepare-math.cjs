const fs=require('fs');
const path=require('path');
const root=path.join(require('path').resolve(__dirname,'..'),'.architecture-assets');
async function get(url){const r=await fetch(url);if(!r.ok)throw Error(url+' '+r.status);return Buffer.from(await r.arrayBuffer());}
(async()=>{fs.mkdirSync(root,{recursive:true});const base='https://cdn.jsdelivr.net/npm/katex@0.16.22/dist/';
fs.writeFileSync(path.join(root,'katex.cjs'),await get(base+'katex.min.js'));
fs.writeFileSync(path.join(root,'KATEX-LICENSE.txt'),await get('https://cdn.jsdelivr.net/npm/katex@0.16.22/LICENSE'));
let css=(await get(base+'katex.min.css')).toString();
const fonts=[...new Set([...css.matchAll(/url\((fonts\/[^)]+\.woff2)\)/g)].map(x=>x[1]))];
for(const font of fonts){const data=await get(base+font);css=css.split('url('+font+')').join('url(data:font/woff2;base64,'+data.toString('base64')+')');}
css=css.replace(/,url\(fonts\/[^)]+\) format\("(?:woff|truetype)"\)/g,'');
fs.writeFileSync(path.join(root,'math.css'),css);console.log('Saved KaTeX and '+fonts.length+' embedded fonts for offline equations.');
})().catch(e=>{console.error(e.message);process.exitCode=1;});
