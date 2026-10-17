module position_ctrl #(
  parameter longint unsigned M=0,N=0,D=0,
  parameter bcjrformer_contract_pkg::addr_t POSITION_BASE=0,READ_BASE=0
)(input logic clk,rst,bcjr_cmd_if.callee command,bcjr_mem_if.requester mem);
  import bcjrformer_contract_pkg::*;
  bcjr_arith_if #(position_add_req_t,act_t) addition();
  position_sequencer #(.M(M),.N(N),.D(D),.POSITION_BASE(POSITION_BASE),.READ_BASE(READ_BASE)) sequence_ctrl(.*);
  position_add_unit local_add(clk,rst,addition);
endmodule
