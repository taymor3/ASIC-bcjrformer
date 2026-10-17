module parameter_mem #(
  parameter longint unsigned DEPTH = 0,
  parameter int unsigned RESPONSE_DELAY = 1
)(input logic clk, rst, bcjr_mem_if.responder access);
  localparam longint unsigned DEPTHS [18] = '{0:DEPTH,default:0};
  memory_adapter #(.PARAMETER_ONLY(1'b1),.BANK_DEPTHS(DEPTHS),.RESPONSE_DELAY(RESPONSE_DELAY)) adapter(.*);
endmodule
