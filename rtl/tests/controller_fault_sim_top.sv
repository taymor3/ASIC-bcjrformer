// Actual controllers; child numerical services and memory are supplied by the test.
module controller_fault_sim_top #(parameter int MODE=0)(
  input logic clk,rst,start,finish_ready,
  input logic mem_ready,mem_valid,mem_error,input logic [95:0] mem_data,
  input logic norm_ready,norm_valid,norm_error,input logic [3:0] norm_status,
  input logic linear_ready,linear_valid,linear_error,input logic [3:0] linear_status,
  input logic recip_ready,recip_valid,recip_error,input logic [3:0] recip_status,
  input logic [39:0] recip_data,input logic [7:0] recip_tag,
  output logic ready,done,error,output logic [3:0] status,output logic [17:0] result,
  output logic memory_request,memory_response,write,output logic [4:0] bank,
  output logic [31:0] address,output logic [2:0] format,output logic [95:0] wdata,
  output logic norm_request,norm_response,output logic [15:0] norm_length,
  output logic linear_request,linear_response,output logic [15:0] linear_inputs,linear_outputs,
  output logic [31:0] linear_src,linear_dst,
  output logic reciprocal_request,reciprocal_response,output logic [63:0] reciprocal_input
);
  import bcjrformer_contract_pkg::*;
  bcjr_cmd_if #(empty_t,empty_t) command();
  bcjr_cmd_if #(empty_t,aggregation_rsp_t) aggregate_command();
  bcjr_cmd_if #(layernorm_cmd_t,empty_t) norm();
  bcjr_cmd_if #(linear_cmd_t,empty_t) linear();
  bcjr_mem_if mem();bcjr_arith_if #(denominator_t,reciprocal_t) reciprocal();
  layernorm_cmd_t norm_descriptor;linear_cmd_t linear_descriptor;
  assign command.cmd_valid=start;assign command.cmd='0;assign command.rsp_ready=finish_ready;
  assign aggregate_command.cmd_valid=start;assign aggregate_command.cmd='0;assign aggregate_command.rsp_ready=finish_ready;
  assign norm.cmd_ready=norm_ready;assign norm.rsp_valid=norm_valid;assign norm.rsp='0;
  assign norm.rsp_error=norm_error;assign norm.rsp_status=status_t'(norm_status);
  assign linear.cmd_ready=linear_ready;assign linear.rsp_valid=linear_valid;assign linear.rsp='0;
  assign linear.rsp_error=linear_error;assign linear.rsp_status=status_t'(linear_status);
  assign mem.req_ready=mem_ready;assign mem.rsp_valid=mem_valid;assign mem.rsp_error=mem_error;assign mem.rsp_rdata=mem_data;
  assign reciprocal.req_ready=recip_ready;assign reciprocal.rsp_valid=recip_valid;
  assign reciprocal.rsp=recip_data;assign reciprocal.rsp_error=recip_error;
  assign reciprocal.rsp_status=status_t'(recip_status);assign reciprocal.rsp_tag=recip_tag;
  assign norm_descriptor=layernorm_cmd_t'(norm.cmd);assign linear_descriptor=linear_cmd_t'(linear.cmd);
  assign norm_request=norm.cmd_valid;assign norm_response=norm.rsp_ready;assign norm_length=norm_descriptor.length;
  assign linear_request=linear.cmd_valid;assign linear_response=linear.rsp_ready;
  assign linear_inputs=linear_descriptor.in_count;assign linear_outputs=linear_descriptor.out_count;
  assign linear_src=linear_descriptor.src.addr;assign linear_dst=linear_descriptor.dst.addr;
  assign memory_request=mem.req_valid;assign memory_response=mem.rsp_ready;
  assign write=mem.req.write;assign bank=mem.req.bank;assign address=mem.req.addr;
  assign format=mem.req.format;assign wdata=mem.req.wdata;
  assign reciprocal_request=reciprocal.req_valid;assign reciprocal_response=reciprocal.rsp_ready;
  assign reciprocal_input=reciprocal.req;
  generate if(MODE==0) begin : embedding
    embedding_ctrl #(.F(2),.D(3),.TOKENS(2),.GAMMA_F_BASE(10),.BETA_F_BASE(20),
      .WEIGHT_BASE(30),.BIAS_BASE(40),.GAMMA_D_BASE(50),.BETA_D_BASE(60)) dut(clk,rst,command,norm,linear,mem);
    assign reciprocal.req_valid=0;assign reciprocal.req='0;assign reciprocal.req_tag=0;assign reciprocal.rsp_ready=0;
    assign ready=command.cmd_ready;assign done=command.rsp_valid;assign error=command.rsp_error;
    assign status=command.rsp_status;assign result=0;
  end else if(MODE==1) begin : final_projection
    final_ctrl #(.TOKENS(3),.D(2),.WEIGHT_BASE(30),.BIAS_BASE(40)) dut(clk,rst,command,linear);
    assign norm.cmd_valid=0;assign norm.cmd='0;assign norm.rsp_ready=0;
    assign mem.req_valid=0;assign mem.req='0;assign mem.rsp_ready=0;
    assign reciprocal.req_valid=0;assign reciprocal.req='0;assign reciprocal.req_tag=0;assign reciprocal.rsp_ready=0;
    assign ready=command.cmd_ready;assign done=command.rsp_valid;assign error=command.rsp_error;
    assign status=command.rsp_status;assign result=0;
  end else begin : aggregation
    aggregation_ctrl #(.M(2),.N(2)) dut(clk,rst,aggregate_command,mem,reciprocal);
    assign norm.cmd_valid=0;assign norm.cmd='0;assign norm.rsp_ready=0;
    assign linear.cmd_valid=0;assign linear.cmd='0;assign linear.rsp_ready=0;
    assign ready=aggregate_command.cmd_ready;assign done=aggregate_command.rsp_valid;assign error=aggregate_command.rsp_error;
    assign status=aggregate_command.rsp_status;assign result=aggregate_command.rsp;
  end endgenerate
endmodule
