// Elaboration fixture only. Small depth values are test sizes, not a chosen model.
module protocol_elaboration;
  import bcjrformer_contract_pkg::*;
  logic clk, rst;
  bcjr_cmd_if #(layernorm_cmd_t,empty_t) norm_clients[2]();
  bcjr_cmd_if #(layernorm_cmd_t,empty_t) norm_service();
  command_switch #(.CLIENTS(2),.CMD_T(layernorm_cmd_t)) norms(clk,rst,norm_clients,norm_service);
  bcjr_cmd_if #(linear_cmd_t,empty_t) linear_clients[5]();
  bcjr_cmd_if #(linear_cmd_t,empty_t) linear_service();
  command_switch #(.CLIENTS(5),.CMD_T(linear_cmd_t)) linears(clk,rst,linear_clients,linear_service);
  bcjr_cmd_if #(dot_cmd_t,accum_t) dot_clients[3]();
  bcjr_cmd_if #(dot_cmd_t,accum_t) dot_service();
  command_switch #(.CLIENTS(3),.CMD_T(dot_cmd_t),.RSP_T(accum_t)) dots(clk,rst,dot_clients,dot_service);
  bcjr_cmd_if #(empty_t,empty_t) single_client[1]();
  bcjr_cmd_if #(empty_t,empty_t) single_service();
  command_switch #(.CLIENTS(1)) single(clk,rst,single_client,single_service);
  bcjr_arith_if #(denominator_t,reciprocal_t) reciprocal_clients[2]();
  bcjr_arith_if #(denominator_t,reciprocal_t) reciprocal_service();
  arithmetic_switch #(.CLIENTS(2),.REQ_T(denominator_t),.RSP_T(reciprocal_t)) reciprocal(clk,rst,reciprocal_clients,reciprocal_service);
  bcjr_mem_if memory_clients[13]();
  bcjr_mem_if parameter_service();
  bcjr_mem_if scratch_service();
  memory_fabric #(.CLIENTS(13),.BANK_DEPTHS('{default:8})) memory_router(
    clk,rst,memory_clients,parameter_service,scratch_service);
  parameter_mem #(.DEPTH(8),.RESPONSE_DELAY(2)) parameters(clk,rst,parameter_service);
  scratch_mem #(.BANK_DEPTHS('{default:8}),.RESPONSE_DELAY(3)) scratch(clk,rst,scratch_service);
  bcjr_host_if #(.INDEX_W(1)) host();
  bcjr_cmd_if #(empty_t,empty_t) embed(),position(),encoder(),final_project();
  bcjr_cmd_if #(empty_t,aggregation_rsp_t) aggregate();
  core_ctrl #(.PARAM_WORDS(2),.FEATURE_WORDS(2),.MASK_WORDS(2),.OUTPUT_WORDS(2)) core(
    clk,rst,host,embed,position,encoder,final_project,aggregate,memory_clients[0]);
  // Additional elaboration boundaries only: N=1, N=3, and a feature count
  // above 65535. These are not selected model dimensions or capacity targets.
  bcjr_host_if #(.INDEX_W(1)) single_host();
  bcjr_cmd_if #(empty_t,empty_t) single_stages[4]();
  bcjr_cmd_if #(empty_t,aggregation_rsp_t) single_aggregate();
  bcjr_mem_if single_mem();
  core_ctrl #(.PARAM_WORDS(1),.FEATURE_WORDS(1),.MASK_WORDS(1),.OUTPUT_WORDS(1))
    single_core(clk,rst,single_host,single_stages[0],single_stages[1],
      single_stages[2],single_stages[3],single_aggregate,single_mem);
  bcjr_host_if #(.INDEX_W(2)) wide_host();
  bcjr_cmd_if #(empty_t,empty_t) wide_stages[4]();
  bcjr_cmd_if #(empty_t,aggregation_rsp_t) wide_aggregate();
  bcjr_mem_if wide_mem();
  core_ctrl #(.PARAM_WORDS(3),.FEATURE_WORDS(131072),.MASK_WORDS(3),.OUTPUT_WORDS(3))
    wide_core(clk,rst,wide_host,wide_stages[0],wide_stages[1],
      wide_stages[2],wide_stages[3],wide_aggregate,wide_mem);
  bcjr_cmd_if #(empty_t,empty_t) embedding_command(),position_command();
  bcjr_arith_if #(position_add_req_t,act_t) position_addition();
  embedding_ctrl #(.F(2),.D(3),.TOKENS(2),.GAMMA_F_BASE(10),.BETA_F_BASE(20),
    .WEIGHT_BASE(30),.BIAS_BASE(40),.GAMMA_D_BASE(50),.BETA_D_BASE(60))
    embedding_stage(clk,rst,embedding_command,norm_clients[0],linear_clients[0],memory_clients[1]);
  position_sequencer #(.M(3),.N(2),.D(3),.POSITION_BASE(100),.READ_BASE(200))
    position_control(clk,rst,position_command,memory_clients[2],position_addition);
  bcjr_cmd_if #(empty_t,empty_t) encoder_command();
  bcjr_cmd_if #(layer_cmd_t,empty_t) layer_command(),attention_command();
  bcjr_cmd_if #(residual_cmd_t,empty_t) residual_command();
  bcjr_cmd_if #(ffn_cmd_t,empty_t) ffn_command();
  encoder_ctrl #(.K(3),.LAYER_STRIDE(64),.LAYER_WORDS(20),.FIRST_LAYER_BASE(100))
    encoder_control(clk,rst,encoder_command,layer_command);
  layer_ctrl #(.TOKENS(2),.D(3),.K(3),.LAYER_WORDS(20),.LN1_GAMMA_OFFSET(0),
    .LN1_BETA_OFFSET(4),.LN2_GAMMA_OFFSET(8),.LN2_BETA_OFFSET(12))
    layer_control(clk,rst,layer_command,norm_clients[1],attention_command,residual_command,ffn_command);
  bcjr_cmd_if #(layer_cmd_t,empty_t) qkv_command(),projection_command();
  bcjr_cmd_if #(row_cmd_t,empty_t) score_command(),weighted_command();
  bcjr_cmd_if #(softmax_cmd_t,empty_t) softmax_command();
  attention_ctrl #(.TOKENS(2),.H(3),.D(3),.K(3),.LAYER_WORDS(20))
    attention_control(clk,rst,attention_command,qkv_command,score_command,softmax_command,
      weighted_command,projection_command,memory_clients[3]);
  qkv_ctrl #(.TOKENS(2),.D(3),.K(3),.LAYER_WORDS(64),
    .WEIGHT_OFFSETS('{0,16,32}),.BIAS_OFFSETS('{12,28,44}))
    qkv_control(clk,rst,qkv_command,linear_clients[1]);
  output_projection_ctrl #(.TOKENS(2),.D(3),.K(3),.LAYER_WORDS(64),
    .WEIGHT_OFFSET(48),.BIAS_OFFSET(60))
    projection_control(clk,rst,projection_command,linear_clients[2]);
endmodule
