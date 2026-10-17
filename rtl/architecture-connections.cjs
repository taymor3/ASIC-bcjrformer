// Structural architecture manifest. No model dimensions or arithmetic choices.
const fs=require('fs'),path=require('path');
const links=[];
function link(parent,child,command='empty_t',response='empty_t') { links.push({parent,child,command,response}); }
for(const [p,c] of [['embed','embedding_ctrl'],['position','position_ctrl'],['encoder','encoder_ctrl'],['final_project','final_ctrl']]) link(`core_ctrl.${p}`,`${c}.command`);
link('core_ctrl.aggregate','aggregation_ctrl.command','empty_t','aggregation_rsp_t');
link('encoder_ctrl.layer','layer_ctrl.command','layer_cmd_t');
link('layer_ctrl.attention','attention_ctrl.command','layer_cmd_t');
link('layer_ctrl.ffn','ffn_ctrl.command','ffn_cmd_t');
link('layer_ctrl.residual','residual_ctrl.command','residual_cmd_t');
for(const [p,c,t] of [['qkv','qkv_ctrl','layer_cmd_t'],['score','score_row_ctrl','row_cmd_t'],['softmax','softmax_ctrl','softmax_cmd_t'],['weighted','weighted_value_ctrl','row_cmd_t'],['out_project','output_projection_ctrl','layer_cmd_t']]) link(`attention_ctrl.${p}`,`${c}.command`,t);
const switches=[
 {name:'norm_switch',module:'command_switch',callers:['embedding_ctrl.norm','layer_ctrl.norm'],service:'layernorm_ctrl.command',command:'layernorm_cmd_t',response:'empty_t'},
 {name:'linear_switch',module:'command_switch',callers:['embedding_ctrl.linear','qkv_ctrl.linear','output_projection_ctrl.linear','ffn_ctrl.linear','final_ctrl.linear'],service:'linear_ctrl.command',command:'linear_cmd_t',response:'empty_t'},
 {name:'dot_switch',module:'command_switch',callers:['linear_ctrl.dot','score_row_ctrl.dot','weighted_value_ctrl.dot'],service:'dot_engine.command',command:'dot_cmd_t',response:'accum_t'},
 {name:'reciprocal_switch',module:'arithmetic_switch',callers:['softmax_ctrl.reciprocal','aggregation_ctrl.reciprocal'],service:'reciprocal_unit.operation',command:'denominator_t',response:'reciprocal_t'}
];
const arithmetic=[
 {parent:'dot_engine.mac',child:'mac_unit.operation',request:'mac_req_t',response:'accum_t'},
 {parent:'softmax_ctrl.exponential',child:'exp_unit.operation',request:'score_t',response:'probability_t'},
 {parent:'layernorm_ctrl.rsqrt',child:'rsqrt_unit.operation',request:'variance_t',response:'rsqrt_t'},
 {parent:'ffn_ctrl.gelu',child:'gelu_unit.operation',request:'act_t',response:'gelu_t'}
];
const memoryClients=['core_ctrl','embedding_ctrl','position_ctrl','attention_ctrl','layernorm_ctrl','linear_ctrl','score_row_ctrl','softmax_ctrl','weighted_value_ctrl','ffn_ctrl','residual_ctrl','aggregation_ctrl','dot_engine'];
const modules=['bcjrformer_core','core_ctrl','embedding_ctrl','position_ctrl','encoder_ctrl','layer_ctrl','attention_ctrl','qkv_ctrl','score_row_ctrl','softmax_ctrl','weighted_value_ctrl','output_projection_ctrl','ffn_ctrl','layernorm_ctrl','linear_ctrl','residual_ctrl','final_ctrl','aggregation_ctrl','dot_engine','mac_unit','exp_unit','reciprocal_unit','rsqrt_unit','gelu_unit','command_switch','arithmetic_switch','memory_fabric','parameter_mem','scratch_mem'];
const manifest={status:'implemented provisional numerical RTL; review and numerical validation pending',modules,links,switches,arithmetic,memoryClients,
 memoryRouting:{parameter:'memory_fabric.parameters -> parameter_mem.access',scratch:'memory_fabric.scratch -> scratch_mem.access'},host:'bcjrformer_core.host -> core_ctrl.host'};
const declarations=fs.readFileSync(path.join(__dirname,'interfaces/bcjrformer_ports.svh'),'utf8');
const declared=[...declarations.matchAll(/extern module\s+(\w+)/g)].map(m=>m[1]);
const errors=[];
for(const m of declared) if(!modules.includes(m)) errors.push(`Unmapped module ${m}`);
for(const m of modules) if(!declared.includes(m)) errors.push(`Missing declaration ${m}`);
const endpoints=[...links.flatMap(x=>[x.parent,x.child]),...arithmetic.flatMap(x=>[x.parent,x.child]),...switches.flatMap(x=>[...x.callers,x.service]),...memoryClients.map(x=>`${x}.mem`)];
if(new Set(endpoints).size!==endpoints.length) errors.push('Multiply connected controller endpoint');
// Check every concrete controller/engine port against the connection inventory.
for(const match of declarations.matchAll(/extern module\s+(\w+)\s*(?:#\([\s\S]*?\)\s*)?\(([\s\S]*?)\);/g)) {
 const [,name,body]=match;
 // Generic switch/fabric prototypes are represented by concrete instances in
 // switches/memoryRouting; controller prototypes must all be checked here.
 if(['bcjrformer_core','parameter_mem','scratch_mem','command_switch','arithmetic_switch','memory_fabric'].includes(name)) continue;
 const clean=body.replace(/\/\/[^\n]*/g,'');
 for(const p of clean.matchAll(/bcjr_(?:cmd|arith|mem)_if\.\w+\s+([\w\s,]+?)(?=\s*,\s*bcjr_|\s*\))/g)) {
   for(const port of p[1].split(',').map(x=>x.trim()).filter(Boolean)) if(!endpoints.includes(`${name}.${port}`)) errors.push(`Unconnected ${name}.${port}`);
 }
 // Append a closing delimiter so final port groups are also inspected.
 const groups=[...(clean+')').matchAll(/bcjr_(?:cmd|arith|mem)_if\.\w+\s+([\w\s,]+?)(?=\s*,\s*bcjr_|\s*\))/g)];
 for(const p of groups) for(const port of p[1].split(',').map(x=>x.trim()).filter(Boolean)) if(!endpoints.includes(`${name}.${port}`)) errors.push(`Unconnected ${name}.${port}`);
}
if(errors.length) throw Error([...new Set(errors)].join('\n'));
fs.writeFileSync(path.join(__dirname,'architecture-connections.json'),JSON.stringify(manifest,null,2)+'\n');
const rows=links.map(x=>`| ${x.parent} | ${x.child} | ${x.command} | ${x.response} |`).join('\n');
const shared=switches.map(x=>`| ${x.name} (${x.module}, ${x.callers.length} clients) | ${x.callers.join(', ')} | ${x.service} | ${x.command} / ${x.response} |`).join('\n');
const md=`# RTL connection inventory\n\nGenerated from architecture-connections.cjs. Structural review only; typed widths remain provisional.\n\n## Dedicated controller links\n\n| Caller | Callee | Command | Response |\n|---|---|---|---|\n${rows}\n\n## Shared services\n\n| Switch | Clients in arbitration order | Service | Payloads |\n|---|---|---|---|\n${shared}\n\n## Direct arithmetic\n\n${arithmetic.map(x=>`- ${x.parent} -> ${x.child}: ${x.request} / ${x.response}`).join('\n')}\n\n## Memory clients\n\n${memoryClients.map((x,i)=>`- Client ${i}: ${x}.mem`).join('\n')}\n\nPARAM routes to parameter_mem.access; other legal banks route to scratch_mem.access. Invalid bank requests return protocol error. Host passes through the wrapper to core_ctrl; all physical blocks share clk/rst.\n\n## Structural checks\n\n${declared.length} declared module kinds covered, ${links.length} dedicated links, ${switches.length} shared switches, ${arithmetic.length} arithmetic links, ${memoryClients.length} memory clients. Checked concrete controller port coverage and duplicate endpoint use. This is not SV compilation, elaboration or simulation.\n`;
fs.writeFileSync(path.join(__dirname,'RTL-CONNECTIONS.md'),md);
console.log(`Structural inventory passed: ${declared.length} module kinds, ${endpoints.length} unique service endpoints.`);
