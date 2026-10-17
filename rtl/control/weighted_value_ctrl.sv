module weighted_value_ctrl #(parameter longint unsigned TOKENS=0,H=0,D=0)(
  input logic clk,rst,bcjr_cmd_if.callee command,bcjr_cmd_if.caller dot,bcjr_mem_if.requester mem);
  row_dot_ctrl #(.WEIGHTED(1),.TOKENS(TOKENS),.H(H),.D(D)) loop_ctrl(.*);
endmodule
