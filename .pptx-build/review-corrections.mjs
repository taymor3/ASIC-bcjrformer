import fs from 'node:fs/promises';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {PresentationFile,FileBlob} from '@oai/artifact-tool';
// Set RUNTIME_NODE_MODULES to your separately installed artifact-tool runtime if required.
const root=path.resolve('..');
const skill=process.env.PRESENTATIONS_SKILL_DIR;
const {finalizePresentation}=await import(pathToFileURL(skill+'/container_tools/artifact_tool_utils.mjs').href);
const deck=await PresentationFile.importPptx(await FileBlob.load('../presentation/BCJRFormer-Architecture-Amit-with-code.pptx'));
await fs.writeFile('review-before.ndjson',(await deck.inspect({kind:'slide,textbox,shape,layout',maxChars:200000})).ndjson);
function get(slide,text){const shape=slide.shapes.items.find(x=>String(x.text)===text);if(!shape)throw Error('Missing shape: '+text);return shape;}
function txt(slide,text,x,y,w,h=35,size=23){const sh=slide.shapes.add({geometry:'textbox',position:{left:x,top:y,width:w,height:h},fill:'none',line:{fill:'none',width:0}});sh.text=text;sh.text.style={typeface:'Arial',fontSize:size,color:'#166da0',autoFit:'none'};return sh;}
const embedding=deck.slides.items[5];
get(embedding,'Adds the encoded-position information and the received-read identity.').text='Adds P[n] and E[m], learned during training and stored with the model weights.';
get(embedding,'3. Read position').text='3. Read P[n]';
get(embedding,'5. Read sequence').text='5. Read E[m]';
txt(embedding,'Inference reads the saved vectors from parameter memory; it does not train them.',75,551,1130,40,24);
embedding.speakerNotes.textFrame.setText(embedding.speakerNotes.textFrame.text+'\n\nP[n] and E[m] are trained parameters saved in the checkpoint as pos_embed and seq_embed.weight. Load both tables into parameter memory before inference. READ POSITION and READ SEQUENCE are table reads, while ADD POSITION and ADD SEQUENCE perform vector additions. sequence_to_embed generates indices only. Source: bcjrformer/models/bcjrformer.py, lines 40–54 and 82–91.');
const code=deck.slides.items[6];
get(code,'Python computation shown here. Hardware FSMs require a separate schedule.').text='pos_embed and seq_embed.weight are trained tables. Inference reads and adds them.';
const s=deck.slides.items[7];
const a=get(s,'Normalize +\nself-attention'),b=get(s,'Add original\ninput'),c=get(s,'Normalize +\nfeed-forward'),d=get(s,'Residual\naddition');
for(const sh of [a,b,c,d])sh.position={...sh.position,top:320};
b.text='+\nFirst sum r';d.text='+\nOutput';
get(s,'Attention shares information between tokens.').position.top=500;
get(s,'The feed-forward block refines each token’s features.').position.top=556;
get(s,'Repeated layers preserve the token dimensions. Detailed FSMs are still open.').text='Software data flow. Stage 3 hardware design is pending.';
function anchor(x,y){return s.shapes.add({geometry:'rect',position:{left:x-0.5,top:y-0.5,width:1,height:1},fill:'none',line:{fill:'none',width:0}});}
function wire(p,q,arrow=false){s.shapes.connect(p,q,{kind:'straight',line:{fill:'#166da0',width:2.5},...(arrow?{tail:{type:'arrow',width:'med',length:'med'}}:{})});}
const input=anchor(48,382.5),turn1=anchor(48,270),turn2=anchor(515,270);
wire(input,a,true);wire(input,turn1);wire(turn1,turn2);s.shapes.connect(turn2,b,{kind:'straight',toSide:'top',line:{fill:'#166da0',width:2.5},tail:{type:'arrow',width:'med',length:'med'}});
const turn3=anchor(515,480),turn4=anchor(1110,480);
s.shapes.connect(b,turn3,{kind:'straight',fromSide:'bottom',line:{fill:'#166da0',width:2.5}});wire(turn3,turn4);s.shapes.connect(turn4,d,{kind:'straight',toSide:'bottom',line:{fill:'#166da0',width:2.5},tail:{type:'arrow',width:'med',length:'med'}});
txt(s,'x',24,343,40);txt(s,'Original x bypasses normalization and attention',80,233,520,35,20);
txt(s,'r bypasses normalization and feed-forward',600,447,470,30,20);
const out=anchor(1240,382.5);wire(d,out,true);
const candidate=path.join(root,'.pptx-build/review-candidate.pptx');
await(await PresentationFile.exportPptx(deck)).save(candidate);
const finalPath=path.join(root,'presentation/BCJRFormer-Architecture-Amit-with-code-reviewed.pptx');
await finalizePresentation({workspaceDir:root,candidatePath:candidate,finalPath,pythonExecutable:process.env.PYTHON_EXECUTABLE || 'python',integrityValidatorPath:skill+'/container_tools/inspect_presentation_package_integrity.py',layoutValidatorPath:skill+'/container_tools/inspect_presentation_layout_geometry.py',layoutArgs:['--expected-slide-size-emu','12192000,6858000','--validate-heading-fit','--require-native-table-slide','18'],requiredNativeTableOwnerSlides:[18],verifyArtifactToolImport:true,receiptPath:path.join(root,'.pptx-build/review-validation.json')});
const final=await PresentationFile.importPptx(await FileBlob.load(finalPath));
for(let i=0;i<final.slides.items.length;i++){const blob=await final.export({slide:final.slides.items[i],format:'png',scale:1});await fs.writeFile('review-'+(i+1)+'.png',new Uint8Array(await blob.arrayBuffer()));}
await fs.writeFile('../presentation/BCJRFormer-speaker-notes-with-code-reviewed.md','# BCJRFormer presentation notes\n\n'+final.slides.items.map((s,i)=>'## Slide '+(i+1)+'\n\n'+s.speakerNotes.textFrame.text).join('\n\n'));
console.log(finalPath);
