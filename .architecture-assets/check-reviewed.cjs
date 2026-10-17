const {chromium}=require('playwright');
const {pathToFileURL}=require('url');const path=require('path');
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'msedge'});
 try {
 const page=await browser.newPage({viewport:{width:1440,height:1050}});
 await page.goto(pathToFileURL(path.resolve('web/bcjrformer-architecture.html')).href+'#document');
 await page.addStyleTag({content:'*{scroll-behavior:auto!important;animation:none!important;transition:none!important}'});
 const paper=await page.locator('.paper').innerText();
 for(const text of ['Stage 1: Input Embedding','Stage 2: Position and Read Embedding','Stage 3: Transformer Encoder','Stage 4: Final Linear Projection','Stage 5: Read Aggregation and Output','Numerical Research Findings and Black-Box Validation Plan','I-BERT','SwiftTron','Softermax','COUNT_VALID_SLOTS','Experiment sequence and acceptance gates'])if(!paper.includes(text))throw Error('Missing '+text);
 const heads=await page.locator('.paper h2').allTextContents();
 if(!(heads.indexOf('High-Level Architecture and Stage Interfaces')<heads.indexOf('Detailed Architecture, Mathematics and RTL Mapping')&&heads.indexOf('Detailed Architecture, Mathematics and RTL Mapping')<heads.indexOf('Stage 1: Input Embedding')))throw Error('Overview must precede detailed stages');
 for(let i=1;i<=5;i++)if(!paper.includes('Stage '+i+' overview:'))throw Error('Missing high-level stage '+i);
 const stages=heads.filter(t=>/^Stage [1-5]:/.test(t));
 if(stages.length!==5||stages.some((t,i)=>!t.startsWith('Stage '+(i+1)+':')))throw Error('Wrong stage ordering');
 if(/September|Joint review|Target review draft|first architecture step/i.test(paper))throw Error('Progress-log language');
 if(await page.getByRole('heading',{name:'Architectural rationale',exact:true}).count()!==5)throw Error('Each stage needs rationale');
 if(/BACKSLASHPLACEHOLDER|\\begin\{|\\operatorname/.test(paper))throw Error('Unrendered LaTeX');
 if(await page.locator('.katex-error').count())throw Error('Math rendering error');
 const lastHeading=await page.locator('.paper h2').last().innerText();
 if(lastHeading!=='Numerical Research Findings and Black-Box Validation Plan')throw Error('Research is not final section');
 for(const [heading,file] of [['Connections, storage and control ownership','high-level-connections'],['Stage 3 overview: transformer encoder','high-level-encoder'],['Stage 1: Input Embedding','reviewed-mathematics'],['Stage 2: Position and Read Embedding','reviewed-position'],['Mask and softmax','reviewed-softmax-math'],['Numerical Research Findings and Black-Box Validation Plan','reviewed-research']]){
  await page.getByRole('heading',{name:heading,exact:true}).scrollIntoViewIfNeeded();
  await page.screenshot({path:'.architecture-assets/'+file+'.png'});
 }
 console.log('Reviewed mathematics, rendered equations, research placement and primary sources passed.');
 } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
