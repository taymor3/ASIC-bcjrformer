module scratch_mem #(
  parameter longint unsigned BANK_DEPTHS [18] = '{default:0},
  parameter int unsigned RESPONSE_DELAY = 1
)(input logic clk, rst, bcjr_mem_if.responder access);
  memory_adapter #(.PARAMETER_ONLY(1'b0),.BANK_DEPTHS(BANK_DEPTHS),.RESPONSE_DELAY(RESPONSE_DELAY)) adapter(.*);
endmodule
