module score_row_ctrl #(
  parameter longint unsigned TOKENS=0,H=0,D=0,
  parameter logic [31:0] SCORE_SCALE=0
)(input logic clk,rst,bcjr_cmd_if.callee command,bcjr_cmd_if.caller dot,bcjr_mem_if.requester mem);
  row_dot_ctrl #(.TOKENS(TOKENS),.H(H),.D(D),.SCORE_SCALE(SCORE_SCALE)) loop_ctrl(.*);
endmodule
