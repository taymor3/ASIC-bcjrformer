// Complete provisional fixed-point assembly; dimensions must be supplied.
// Canonical packed manifest: Stage 1, P, E, K layer regions, final W/b.
module bcjrformer_core #(
  parameter longint unsigned F=0,M=0,N=0,D=0,H=0,K=0,
  parameter bit STATIC_MASK=0,
  parameter int unsigned MEMORY_DELAY=1
)(input logic clk,rst,bcjr_host_if.core host);
  import bcjrformer_contract_pkg::*;import fixed_math_pkg::*;
  localparam longint unsigned TOKENS=M*N;
  localparam longint unsigned EMBED_WORDS=2*F+D*F+3*D;
  localparam longint unsigned POSITION_BASE=EMBED_WORDS,READ_BASE=POSITION_BASE+N*D;
  localparam longint unsigned FIRST_LAYER=READ_BASE+M*D,LAYER_WORDS=12*D*D+13*D;
  localparam longint unsigned FINAL_WEIGHT=FIRST_LAYER+K*LAYER_WORDS,FINAL_BIAS=FINAL_WEIGHT+D;
  localparam longint unsigned PARAM_WORDS=FINAL_BIAS+1;
  localparam longint unsigned DEPTHS[18]='{PARAM_WORDS,TOKENS*F,TOKENS,TOKENS*D,TOKENS*D,
    TOKENS*D,TOKENS*D,TOKENS*D,TOKENS*D,TOKENS*D,F,4*D,D,TOKENS,TOKENS,TOKENS,TOKENS,N};
  initial if(F==0 || F>65535 || M==0 || M>65535 || N==0 || N>65535 || TOKENS>65535 || D==0 || D>16383 ||
    H==0 || H>D || D%H!=0 || K==0 || K>65535 || PARAM_WORDS>(64'd1<<ADDR_W) ||
    TOKENS*F>(64'd1<<ADDR_W) || TOKENS*D>(64'd1<<ADDR_W) || STATIC_MASK)
    $fatal(1,"core requires bounded dimensions, canonical manifest, and no static mask");
  bcjr_cmd_if #(empty_t,empty_t) embed(),position(),encoder(),final_project();
  bcjr_cmd_if #(empty_t,aggregation_rsp_t) aggregate();
  bcjr_cmd_if #(layer_cmd_t,empty_t) layer(),attention(),qkv(),out_project();
  bcjr_cmd_if #(row_cmd_t,empty_t) score(),weighted();
  bcjr_cmd_if #(softmax_cmd_t,empty_t) softmax();
  bcjr_cmd_if #(residual_cmd_t,empty_t) residual();
  bcjr_cmd_if #(ffn_cmd_t,empty_t) ffn();
  bcjr_cmd_if #(layernorm_cmd_t,empty_t) norm_clients[2](),norm_service();
  bcjr_cmd_if #(linear_cmd_t,empty_t) linear_clients[5](),linear_service();
  bcjr_cmd_if #(dot_cmd_t,accum_t) dot_clients[3](),dot_service();
  bcjr_arith_if #(denominator_t,reciprocal_t) reciprocal_clients[2](),reciprocal_service();
  bcjr_arith_if #(mac_req_t,accum_t) mac();
  bcjr_arith_if #(score_t,probability_t) exponential();
  bcjr_arith_if #(variance_t,rsqrt_t) rsqrt();
  bcjr_arith_if #(act_t,gelu_t) gelu();
  bcjr_mem_if memory_clients[13](),parameter_service(),scratch_service();
  core_ctrl #(.PARAM_WORDS(PARAM_WORDS),.FEATURE_WORDS(TOKENS*F),.MASK_WORDS(TOKENS),.OUTPUT_WORDS(N))
    core(clk,rst,host,embed,position,encoder,final_project,aggregate,memory_clients[0]);
  embedding_ctrl #(.F(F),.D(D),.TOKENS(TOKENS),.GAMMA_F_BASE(0),.BETA_F_BASE(addr_t'(F)),
    .WEIGHT_BASE(addr_t'(2*F)),.BIAS_BASE(addr_t'(2*F+D*F)),
    .GAMMA_D_BASE(addr_t'(2*F+D*F+D)),.BETA_D_BASE(addr_t'(2*F+D*F+2*D)))
    embedding(clk,rst,embed,norm_clients[0],linear_clients[0],memory_clients[1]);
  position_ctrl #(.M(M),.N(N),.D(D),.POSITION_BASE(addr_t'(POSITION_BASE)),.READ_BASE(addr_t'(READ_BASE)))
    position_stage(clk,rst,position,memory_clients[2]);
  encoder_ctrl #(.K(K),.LAYER_STRIDE(LAYER_WORDS),.LAYER_WORDS(LAYER_WORDS),.FIRST_LAYER_BASE(addr_t'(FIRST_LAYER)))
    encoder_stage(clk,rst,encoder,layer);
  layer_ctrl #(.TOKENS(TOKENS),.D(D),.K(K),.LAYER_WORDS(LAYER_WORDS),.LN1_GAMMA_OFFSET(0),
    .LN1_BETA_OFFSET(addr_t'(D)),.LN2_GAMMA_OFFSET(addr_t'(2*D)),.LN2_BETA_OFFSET(addr_t'(3*D)))
    layer_stage(clk,rst,layer,norm_clients[1],attention,residual,ffn);
  attention_ctrl #(.TOKENS(TOKENS),.H(H),.D(D),.K(K),.LAYER_WORDS(LAYER_WORDS))
    attention_stage(clk,rst,attention,qkv,score,softmax,weighted,out_project,memory_clients[3]);
  qkv_ctrl #(.TOKENS(TOKENS),.D(D),.K(K),.LAYER_WORDS(LAYER_WORDS),
    .WEIGHT_OFFSETS('{addr_t'(4*D),addr_t'(5*D+D*D),addr_t'(6*D+2*D*D)}),
    .BIAS_OFFSETS('{addr_t'(4*D+D*D),addr_t'(5*D+2*D*D),addr_t'(6*D+3*D*D)}))
    qkv_stage(clk,rst,qkv,linear_clients[1]);
  output_projection_ctrl #(.TOKENS(TOKENS),.D(D),.K(K),.LAYER_WORDS(LAYER_WORDS),
    .WEIGHT_OFFSET(addr_t'(7*D+3*D*D)),.BIAS_OFFSET(addr_t'(7*D+4*D*D)))
    projection_stage(clk,rst,out_project,linear_clients[2]);
  score_row_ctrl #(.TOKENS(TOKENS),.H(H),.D(D),.SCORE_SCALE(head_scale(H>0 ? D/H:0)))
    score_stage(clk,rst,score,dot_clients[1],memory_clients[6]);
  weighted_value_ctrl #(.TOKENS(TOKENS),.H(H),.D(D))
    weighted_stage(clk,rst,weighted,dot_clients[2],memory_clients[8]);
  softmax_ctrl #(.TOKENS(TOKENS),.UNIFORM_PROB(uniform_probability(TOKENS)))
    softmax_stage(clk,rst,softmax,memory_clients[7],exponential,reciprocal_clients[0]);
  ffn_ctrl #(.D(D),.LAYER_WORDS(LAYER_WORDS),.W1_OFFSET(addr_t'(8*D+4*D*D)),
    .B1_OFFSET(addr_t'(8*D+8*D*D)),.W2_OFFSET(addr_t'(12*D+8*D*D)),.B2_OFFSET(addr_t'(12*D+12*D*D)))
    ffn_stage(clk,rst,ffn,linear_clients[3],memory_clients[9],gelu);
  residual_ctrl residual_stage(clk,rst,residual,memory_clients[10]);
  final_ctrl #(.TOKENS(TOKENS),.D(D),.WEIGHT_BASE(addr_t'(FINAL_WEIGHT)),.BIAS_BASE(addr_t'(FINAL_BIAS)))
    final_stage(clk,rst,final_project,linear_clients[4]);
  aggregation_ctrl #(.M(M),.N(N)) aggregation_stage(clk,rst,aggregate,memory_clients[11],reciprocal_clients[1]);
  layernorm_ctrl norm_engine(clk,rst,norm_service,memory_clients[4],rsqrt);
  linear_ctrl linear_engine(clk,rst,linear_service,dot_clients[0],memory_clients[5]);
  dot_engine dot_service_engine(clk,rst,dot_service,memory_clients[12],mac);
  command_switch #(.CLIENTS(2),.CMD_T(layernorm_cmd_t)) norm_switch(clk,rst,norm_clients,norm_service);
  command_switch #(.CLIENTS(5),.CMD_T(linear_cmd_t)) linear_switch(clk,rst,linear_clients,linear_service);
  command_switch #(.CLIENTS(3),.CMD_T(dot_cmd_t),.RSP_T(accum_t)) dot_switch(clk,rst,dot_clients,dot_service);
  arithmetic_switch #(.CLIENTS(2),.REQ_T(denominator_t),.RSP_T(reciprocal_t))
    reciprocal_switch(clk,rst,reciprocal_clients,reciprocal_service);
  mac_unit multiply_accumulate(clk,rst,mac);
  exp_unit exp_service(clk,rst,exponential);
  reciprocal_unit inverse_service(clk,rst,reciprocal_service);
  rsqrt_unit root_service(clk,rst,rsqrt);
  gelu_unit activation_service(clk,rst,gelu);
  memory_fabric #(.CLIENTS(13),.BANK_DEPTHS(DEPTHS)) fabric(clk,rst,memory_clients,parameter_service,scratch_service);
  parameter_mem #(.DEPTH(PARAM_WORDS),.RESPONSE_DELAY(MEMORY_DELAY)) parameters(clk,rst,parameter_service);
  scratch_mem #(.BANK_DEPTHS(DEPTHS),.RESPONSE_DELAY(MEMORY_DELAY)) scratch(clk,rst,scratch_service);
endmodule
