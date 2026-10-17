module output_projection_ctrl #(
  parameter longint unsigned TOKENS=0,D=0,K=0,LAYER_WORDS=0,
  parameter bcjrformer_contract_pkg::addr_t WEIGHT_OFFSET='0,BIAS_OFFSET='0
)(input logic clk,rst,bcjr_cmd_if.callee command,bcjr_cmd_if.caller linear);
  projection_loop #(.TOKENS(TOKENS),.D(D),.K(K),.LAYER_WORDS(LAYER_WORDS),.PROJECTIONS(1),
    .INPUT_BANK(bcjrformer_contract_pkg::BANK_Z),.OUTPUT_BANKS('{bcjrformer_contract_pkg::BANK_ATTN_OUT}),
    .WEIGHT_OFFSETS('{WEIGHT_OFFSET}),.BIAS_OFFSETS('{BIAS_OFFSET})) control(clk,rst,command,linear);
endmodule
