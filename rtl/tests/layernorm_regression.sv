// Actual LayerNorm and RSQRT; runner supplies a delayed, backpressured memory.
module layernorm_regression #(
  parameter bcjrformer_contract_pkg::variance_t EPSILON=bcjrformer_contract_pkg::NORMALIZATION_MINIMUM
)(input logic clk,rst,cmd_valid,rsp_ready,
  input bcjrformer_contract_pkg::count_t length,
  input logic mem_req_ready,mem_rsp_valid,mem_rsp_error,
  input bcjrformer_contract_pkg::mem_data_t mem_rsp_rdata,
  output logic cmd_ready,rsp_valid,rsp_error,mem_req_valid,mem_rsp_ready,
  output bcjrformer_contract_pkg::mem_req_t mem_req,
  output bcjrformer_contract_pkg::status_t status,
  output logic signed [31:0] mean,
  output bcjrformer_contract_pkg::variance_t variance);
  import bcjrformer_contract_pkg::*;
  bcjr_cmd_if #(layernorm_cmd_t,empty_t) command();
  bcjr_mem_if mem();bcjr_arith_if #(variance_t,rsqrt_t) root();
  assign command.cmd='{length:length,src:'{bank:BANK_TOKEN,addr:'0},
    dst:'{bank:BANK_TOKEN,addr:'0},gamma_base:32'd65536,beta_base:32'd131072};
  assign command.cmd_valid=cmd_valid;assign command.rsp_ready=rsp_ready;
  assign cmd_ready=command.cmd_ready;assign rsp_valid=command.rsp_valid;
  assign rsp_error=command.rsp_error;assign status=command.rsp_status;
  assign mem_req_valid=mem.req_valid;assign mem_req=mem.req;
  assign mem_rsp_ready=mem.rsp_ready;assign mem.req_ready=mem_req_ready;
  assign mem.rsp_valid=mem_rsp_valid;assign mem.rsp_error=mem_rsp_error;
  assign mem.rsp_rdata=mem_rsp_rdata;
  layernorm_ctrl #(.EPSILON(EPSILON)) dut(clk,rst,command,mem,root);
  rsqrt_unit inverse_root(clk,rst,root);
  assign mean=dut.mean_q;assign variance=dut.variance_q;
endmodule
