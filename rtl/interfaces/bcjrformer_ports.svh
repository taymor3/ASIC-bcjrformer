// Generated public port contracts; implementations are in the production file list.

extern module bcjrformer_core #(
  parameter longint unsigned F=0,M=0,N=0,D=0,H=0,K=0,
  parameter bit STATIC_MASK=0,
  parameter int unsigned MEMORY_DELAY=1
)(input logic clk,rst,bcjr_host_if.core host);

extern module core_ctrl #(
  parameter longint unsigned PARAM_WORDS = 0,
  parameter longint unsigned FEATURE_WORDS = 0,
  parameter longint unsigned MASK_WORDS = 0,
  parameter longint unsigned OUTPUT_WORDS = 0
)(
  input logic clk, rst,
  bcjr_host_if.core host,
  bcjr_cmd_if.caller embed, position, encoder, final_project,
  bcjr_cmd_if.caller aggregate,
  bcjr_mem_if.requester mem
);

extern module embedding_ctrl #(
  parameter longint unsigned F=0, D=0, TOKENS=0,
  parameter bcjrformer_contract_pkg::addr_t GAMMA_F_BASE='0, BETA_F_BASE='0,
  parameter bcjrformer_contract_pkg::addr_t WEIGHT_BASE='0, BIAS_BASE='0,
  parameter bcjrformer_contract_pkg::addr_t GAMMA_D_BASE='0, BETA_D_BASE='0
)(
  input logic clk, rst, bcjr_cmd_if.callee command,
  bcjr_cmd_if.caller norm, linear, bcjr_mem_if.requester mem
);

extern module position_ctrl #(
  parameter longint unsigned M=0,N=0,D=0,
  parameter bcjrformer_contract_pkg::addr_t POSITION_BASE=0,READ_BASE=0
)(input logic clk,rst,bcjr_cmd_if.callee command,bcjr_mem_if.requester mem);

extern module encoder_ctrl #(
  parameter longint unsigned K=0,LAYER_STRIDE=0,LAYER_WORDS=0,
  parameter bcjrformer_contract_pkg::addr_t FIRST_LAYER_BASE='0
)(input logic clk,rst,bcjr_cmd_if.callee command,bcjr_cmd_if.caller layer);

extern module layer_ctrl #(
  parameter longint unsigned TOKENS=0,D=0,K=0,LAYER_WORDS=0,
  parameter bcjrformer_contract_pkg::addr_t LN1_GAMMA_OFFSET='0,LN1_BETA_OFFSET='0,
  parameter bcjrformer_contract_pkg::addr_t LN2_GAMMA_OFFSET='0,LN2_BETA_OFFSET='0
)(input logic clk,rst,bcjr_cmd_if.callee command,
  bcjr_cmd_if.caller norm,attention,residual,ffn);

extern module attention_ctrl #(
  parameter longint unsigned TOKENS=0,H=0,D=0,K=0,LAYER_WORDS=0
)(input logic clk,rst,bcjr_cmd_if.callee command,
  bcjr_cmd_if.caller qkv,score,softmax,weighted,out_project,
  bcjr_mem_if.requester mem);

extern module qkv_ctrl #(
  parameter longint unsigned TOKENS=0,D=0,K=0,LAYER_WORDS=0,
  parameter bcjrformer_contract_pkg::addr_t WEIGHT_OFFSETS [3]='{default:'0},
  parameter bcjrformer_contract_pkg::addr_t BIAS_OFFSETS [3]='{default:'0}
)(input logic clk,rst,bcjr_cmd_if.callee command,bcjr_cmd_if.caller linear);

extern module score_row_ctrl #(
  parameter longint unsigned TOKENS=0,H=0,D=0,
  parameter logic [31:0] SCORE_SCALE=0
)(input logic clk,rst,bcjr_cmd_if.callee command,bcjr_cmd_if.caller dot,bcjr_mem_if.requester mem);

extern module softmax_ctrl #(
  parameter longint unsigned TOKENS=0,
  parameter logic [23:0] UNIFORM_PROB=0
)(input logic clk,rst,bcjr_cmd_if.callee command,bcjr_mem_if.requester mem,
  bcjr_arith_if.requester exponential,reciprocal);

extern module weighted_value_ctrl #(parameter longint unsigned TOKENS=0,H=0,D=0)(
  input logic clk,rst,bcjr_cmd_if.callee command,bcjr_cmd_if.caller dot,bcjr_mem_if.requester mem);

extern module output_projection_ctrl #(
  parameter longint unsigned TOKENS=0,D=0,K=0,LAYER_WORDS=0,
  parameter bcjrformer_contract_pkg::addr_t WEIGHT_OFFSET='0,BIAS_OFFSET='0
)(input logic clk,rst,bcjr_cmd_if.callee command,bcjr_cmd_if.caller linear);

extern module ffn_ctrl #(
  parameter longint unsigned D=0,LAYER_WORDS=0,
  parameter bcjrformer_contract_pkg::addr_t W1_OFFSET=0,B1_OFFSET=0,W2_OFFSET=0,B2_OFFSET=0
)(input logic clk,rst,bcjr_cmd_if.callee command,bcjr_cmd_if.caller linear,
  bcjr_mem_if.requester mem,bcjr_arith_if.requester gelu);

extern module layernorm_ctrl #(parameter bcjrformer_contract_pkg::variance_t EPSILON=48'd42950)(
  input logic clk,rst,bcjr_cmd_if.callee command,bcjr_mem_if.requester mem,bcjr_arith_if.requester rsqrt);

extern module linear_ctrl(input logic clk,rst,bcjr_cmd_if.callee command,bcjr_cmd_if.caller dot,bcjr_mem_if.requester mem);

extern module residual_ctrl(input logic clk,rst,bcjr_cmd_if.callee command,bcjr_mem_if.requester mem);

extern module final_ctrl #(
  parameter longint unsigned TOKENS=0,D=0,
  parameter bcjrformer_contract_pkg::addr_t WEIGHT_BASE=0,BIAS_BASE=0
)(input logic clk,rst,bcjr_cmd_if.callee command,bcjr_cmd_if.caller linear);

extern module aggregation_ctrl #(parameter longint unsigned M=0,N=0)(
  input logic clk,rst,bcjr_cmd_if.callee command,bcjr_mem_if.requester mem,bcjr_arith_if.requester reciprocal);

extern module dot_engine(input logic clk,rst,bcjr_cmd_if.callee command,
  bcjr_mem_if.requester mem,bcjr_arith_if.requester mac);

extern module mac_unit(input logic clk,rst,bcjr_arith_if.responder operation);

extern module exp_unit(input logic clk,rst,bcjr_arith_if.responder operation);

extern module reciprocal_unit(input logic clk,rst,bcjr_arith_if.responder operation);

extern module rsqrt_unit #(parameter bcjrformer_contract_pkg::variance_t MINIMUM=48'd42950)(
  input logic clk,rst,bcjr_arith_if.responder operation);

extern module gelu_unit(input logic clk,rst,bcjr_arith_if.responder operation);

extern module command_switch #(
  parameter int unsigned CLIENTS = 1,
  parameter type CMD_T = bcjrformer_contract_pkg::empty_t,
  parameter type RSP_T = bcjrformer_contract_pkg::empty_t
)(
  input logic clk, rst,
  bcjr_cmd_if.callee clients [CLIENTS], bcjr_cmd_if.caller service
);

extern module arithmetic_switch #(
  parameter int unsigned CLIENTS = 1,
  parameter type REQ_T = bcjrformer_contract_pkg::act_t,
  parameter type RSP_T = bcjrformer_contract_pkg::act_t
)(
  input logic clk, rst,
  bcjr_arith_if.responder clients [CLIENTS], bcjr_arith_if.requester service
);

extern module memory_fabric #(
  parameter int unsigned CLIENTS = 13,
  // Integration must supply all depths. Zero means disabled, never a guessed model.
  parameter longint unsigned BANK_DEPTHS [18] = '{default:0}
)(
  input logic clk, rst, bcjr_mem_if.responder clients [CLIENTS],
  bcjr_mem_if.requester parameters, scratch
);

extern module parameter_mem #(
  parameter longint unsigned DEPTH = 0,
  parameter int unsigned RESPONSE_DELAY = 1
)(input logic clk, rst, bcjr_mem_if.responder access);

extern module scratch_mem #(
  parameter longint unsigned BANK_DEPTHS [18] = '{default:0},
  parameter int unsigned RESPONSE_DELAY = 1
)(input logic clk, rst, bcjr_mem_if.responder access);
