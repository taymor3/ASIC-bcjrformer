// Deliberately small memory fixture; both numerical/controller services are real RTL.
module agg_tie_top(input logic clk,rst,start,finish_ready,mem_ready,mem_valid,mem_error,
  input logic [95:0] mem_data,
  output logic ready,done,error,memory_request,memory_response,write,
  output logic [4:0] bank,output logic [31:0] address,output logic [95:0] wdata);
  import bcjrformer_contract_pkg::*;
  bcjr_cmd_if #(empty_t,aggregation_rsp_t) command();
  bcjr_mem_if mem();
  bcjr_arith_if #(denominator_t,reciprocal_t) reciprocal();
  assign command.cmd='0;assign command.cmd_valid=start;assign command.rsp_ready=finish_ready;
  assign ready=command.cmd_ready;assign done=command.rsp_valid;assign error=command.rsp_error;
  assign mem.req_ready=mem_ready;assign mem.rsp_valid=mem_valid;
  assign mem.rsp_error=mem_error;assign mem.rsp_rdata=mem_data;
  assign memory_request=mem.req_valid;assign memory_response=mem.rsp_ready;
  assign write=mem.req.write;assign bank=mem.req.bank;assign address=mem.req.addr;assign wdata=mem.req.wdata;
  aggregation_ctrl #(.M(6),.N(1)) dut(clk,rst,command,mem,reciprocal);
  reciprocal_unit actual_reciprocal(clk,rst,reciprocal);
endmodule
