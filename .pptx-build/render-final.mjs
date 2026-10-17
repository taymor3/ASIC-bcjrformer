import fs from 'node:fs/promises';
import {PresentationFile,FileBlob} from '@oai/artifact-tool';
const p=await PresentationFile.importPptx(await FileBlob.load('../presentation/BCJRFormer-Architecture-Amit.pptx'));
for(let i=0;i<p.slides.items.length;i++){const image=await p.export({slide:p.slides.items[i],format:'png',scale:1});await fs.writeFile(`final-${i+1}.png`,new Uint8Array(await image.arrayBuffer()));}
console.log('Rendered all 10 final slides');
