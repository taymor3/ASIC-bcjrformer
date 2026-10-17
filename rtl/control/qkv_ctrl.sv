module qkv_ctrl #(
  parameter longint unsigned TOKENS=0,D=0,K=0,LAYER_WORDS=0,
  parameter bcjrformer_contract_pkg::addr_t WEIGHT_OFFSETS [3]='{default:'0},
  parameter bcjrformer_contract_pkg::addr_t BIAS_OFFSETS [3]='{default:'0}
)(input logic clk,rst,bcjr_cmd_if.callee command,bcjr_cmd_if.caller linear);
  projection_loop #(.TOKENS(TOKENS),.D(D),.K(K),.LAYER_WORDS(LAYER_WORDS),.PROJECTIONS(3),
    .INPUT_BANK(bcjrformer_contract_pkg::BANK_U),
    .OUTPUT_BANKS('{bcjrformer_contract_pkg::BANK_Q,bcjrformer_contract_pkg::BANK_KEY,bcjrformer_contract_pkg::BANK_VALUE}),
    .WEIGHT_OFFSETS(WEIGHT_OFFSETS),.BIAS_OFFSETS(BIAS_OFFSETS)) control(clk,rst,command,linear);
endmodule
