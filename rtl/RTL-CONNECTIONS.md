# RTL connection inventory

Generated from architecture-connections.cjs. Structural review only; typed widths remain provisional.

## Dedicated controller links

| Caller | Callee | Command | Response |
|---|---|---|---|
| core_ctrl.embed | embedding_ctrl.command | empty_t | empty_t |
| core_ctrl.position | position_ctrl.command | empty_t | empty_t |
| core_ctrl.encoder | encoder_ctrl.command | empty_t | empty_t |
| core_ctrl.final_project | final_ctrl.command | empty_t | empty_t |
| core_ctrl.aggregate | aggregation_ctrl.command | empty_t | aggregation_rsp_t |
| encoder_ctrl.layer | layer_ctrl.command | layer_cmd_t | empty_t |
| layer_ctrl.attention | attention_ctrl.command | layer_cmd_t | empty_t |
| layer_ctrl.ffn | ffn_ctrl.command | ffn_cmd_t | empty_t |
| layer_ctrl.residual | residual_ctrl.command | residual_cmd_t | empty_t |
| attention_ctrl.qkv | qkv_ctrl.command | layer_cmd_t | empty_t |
| attention_ctrl.score | score_row_ctrl.command | row_cmd_t | empty_t |
| attention_ctrl.softmax | softmax_ctrl.command | softmax_cmd_t | empty_t |
| attention_ctrl.weighted | weighted_value_ctrl.command | row_cmd_t | empty_t |
| attention_ctrl.out_project | output_projection_ctrl.command | layer_cmd_t | empty_t |

## Shared services

| Switch | Clients in arbitration order | Service | Payloads |
|---|---|---|---|
| norm_switch (command_switch, 2 clients) | embedding_ctrl.norm, layer_ctrl.norm | layernorm_ctrl.command | layernorm_cmd_t / empty_t |
| linear_switch (command_switch, 5 clients) | embedding_ctrl.linear, qkv_ctrl.linear, output_projection_ctrl.linear, ffn_ctrl.linear, final_ctrl.linear | linear_ctrl.command | linear_cmd_t / empty_t |
| dot_switch (command_switch, 3 clients) | linear_ctrl.dot, score_row_ctrl.dot, weighted_value_ctrl.dot | dot_engine.command | dot_cmd_t / accum_t |
| reciprocal_switch (arithmetic_switch, 2 clients) | softmax_ctrl.reciprocal, aggregation_ctrl.reciprocal | reciprocal_unit.operation | denominator_t / reciprocal_t |

## Direct arithmetic

- dot_engine.mac -> mac_unit.operation: mac_req_t / accum_t
- softmax_ctrl.exponential -> exp_unit.operation: score_t / probability_t
- layernorm_ctrl.rsqrt -> rsqrt_unit.operation: variance_t / rsqrt_t
- ffn_ctrl.gelu -> gelu_unit.operation: act_t / gelu_t

## Memory clients

- Client 0: core_ctrl.mem
- Client 1: embedding_ctrl.mem
- Client 2: position_ctrl.mem
- Client 3: attention_ctrl.mem
- Client 4: layernorm_ctrl.mem
- Client 5: linear_ctrl.mem
- Client 6: score_row_ctrl.mem
- Client 7: softmax_ctrl.mem
- Client 8: weighted_value_ctrl.mem
- Client 9: ffn_ctrl.mem
- Client 10: residual_ctrl.mem
- Client 11: aggregation_ctrl.mem
- Client 12: dot_engine.mem

PARAM routes to parameter_mem.access; other legal banks route to scratch_mem.access. Invalid bank requests return protocol error. Host passes through the wrapper to core_ctrl; all physical blocks share clk/rst.

## Structural checks

29 declared module kinds covered, 14 dedicated links, 4 shared switches, 4 arithmetic links, 13 memory clients. Checked concrete controller port coverage and duplicate endpoint use. This is not SV compilation, elaboration or simulation.
