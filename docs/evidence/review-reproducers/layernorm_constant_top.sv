module layernorm_review_top(input logic clk,rst,start, output logic ready,done,error,write_seen, output logic signed [15:0] first_value, output logic [3:0] status);
 import bcjrformer_contract_pkg::*;
 bcjr_cmd_if #(layernorm_cmd_t,empty_t) command();
 bcjr_mem_if mem(); bcjr_arith_if #(variance_t,rsqrt_t) rsqrt();
 logic pending; mem_data_t data_q;
 assign command.cmd_valid=start; assign command.cmd='{length:count_t'(768),src:'{bank:BANK_FEATURE,addr:0},dst:'{bank:BANK_TOKEN,addr:0},gamma_base:1000,beta_base:2000};
 assign command.rsp_ready=!rst; assign ready=command.cmd_ready; assign done=command.rsp_valid;assign error=command.rsp_error;assign status=command.rsp_status;
 assign mem.req_ready=!rst && !pending;assign mem.rsp_valid=!rst && pending;assign mem.rsp_error=0;assign mem.rsp_rdata=data_q;
 always_ff @(posedge clk) begin
  if(rst) begin pending<=0;data_q<=0;write_seen<=0;first_value<=0;end
  else begin
   if(mem.req_valid && mem.req_ready) begin
    pending<=1;
    data_q<=mem.req.bank==BANK_PARAM ? (mem.req.addr<2000 ? 96'd1024:96'd0):96'd32767;
    if(mem.req.write && !write_seen) begin write_seen<=1;first_value<=act_t'(mem.req.wdata[15:0]);end
   end
   if(mem.rsp_valid && mem.rsp_ready) pending<=0;
  end
 end
 layernorm_ctrl dut(clk,rst,command,mem,rsqrt);
 rsqrt_unit actual_rsqrt(clk,rst,rsqrt);
endmodule
