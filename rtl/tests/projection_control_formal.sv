// Actual controller + five-client linear switch; numerical linear service is modeled.
module projection_control_formal #(parameter int MODE=0,CASE=0,
  parameter longint unsigned TOKENS=3,D=2)(
  input logic clk,service_go,response_go,finish_check,
  output logic test_done=0,saw_stall=0,saw_reset=0
);
  import bcjrformer_contract_pkg::*;
  logic rst,past_valid=0,reset_trigger=0,reset_done=0,sent,run_q,fault_seen;
  bcjr_cmd_if #(layer_cmd_t,empty_t) command();
  bcjr_cmd_if #(linear_cmd_t,empty_t) clients[5](),service();
  command_switch #(.CLIENTS(5),.CMD_T(linear_cmd_t),.RSP_T(empty_t)) shared_linear(clk,rst,clients,service);
  generate if(MODE==0) begin : qkv
    qkv_ctrl #(.TOKENS(TOKENS),.D(D),.K(2),.LAYER_WORDS(64),
      .WEIGHT_OFFSETS('{0,8,16}),.BIAS_OFFSETS('{4,12,20})) dut(clk,rst,command,clients[1]);
  end else begin : projection
    output_projection_ctrl #(.TOKENS(TOKENS),.D(D),.K(2),.LAYER_WORDS(64),.WEIGHT_OFFSET(24),.BIAS_OFFSET(28))
      dut(clk,rst,command,clients[2]);
  end endgenerate
  for(genvar c=0;c<5;c++) begin : unused
    if(c!=(MODE==0 ? 1:2)) begin
      assign clients[c].cmd_valid=0;assign clients[c].cmd='0;assign clients[c].rsp_ready=0;
    end
  end
  localparam longint unsigned CALLS=(MODE==0 ? 3:1)*TOKENS;
  localparam int CW=CALLS>0 ? $clog2(CALLS+1):1;
  logic [CW-1:0] count_q;
  logic pending,reply,delay_q,fault_q;
  layer_cmd_t incoming;
  linear_cmd_t descriptor;
  logic [31:0] token_index,projection_index;
  addr_t base;
  bank_t dst_bank;
  assign rst=!past_valid || reset_trigger;
  assign token_index=32'(64'(count_q)%TOKENS);
  assign projection_index=32'(64'(count_q)/TOKENS);
  assign base=run_q ? 200:100;
  assign dst_bank=MODE==1 ? BANK_ATTN_OUT : projection_index==0 ? BANK_Q : projection_index==1 ? BANK_KEY:BANK_VALUE;
  always_comb begin
    incoming='{layer_index:run_q ? 16'd0:16'd1,layer_param_base:base};
    if(CASE==3) incoming.layer_index=2;
    if(CASE==4) incoming.layer_param_base=32'hfffffff0;
    if(sent) incoming='{layer_index:16'hffff,layer_param_base:32'hffffffff};
  end
  assign command.cmd=incoming;assign command.cmd_valid=!sent && !test_done;
  assign command.rsp_ready=response_go;
  assign service.cmd_ready=service_go && !pending && !rst;
  assign service.rsp_valid=reply && !rst;assign service.rsp='0;
  assign service.rsp_error=fault_q;
  assign service.rsp_status='{protocol_error:0,numeric_error:CASE!=2 && fault_q,saturated:1,rounded:1};
  always @(posedge clk) begin
    past_valid<=1;reset_trigger<=0;
    if(reset_trigger) begin reset_done<=1;saw_reset<=1;end
    if(!rst && !reset_done && (CASE==5 && pending || CASE==6 && command.rsp_valid)) reset_trigger<=1;
    if(rst) begin count_q<=0;sent<=0;run_q<=0;fault_seen<=0;pending<=0;reply<=0;delay_q<=0;fault_q<=0;test_done<=0;
      assert(!command.cmd_ready && !command.rsp_valid && !service.cmd_valid && !service.rsp_ready);
    end else begin
      if(finish_check) assert(test_done);
      if(command.cmd_valid && command.cmd_ready) begin sent<=1;count_q<=0;fault_seen<=0;end
      if(service.cmd_valid && service.cmd_ready) begin
        assert(sent && !pending && 64'(count_q)<CALLS && CASE!=3 && CASE!=4);
        descriptor=linear_cmd_t'(service.cmd);
        assert(descriptor.in_count==16'(D) && descriptor.out_count==16'(D));
        assert(descriptor.src==ptr_t'{bank:MODE==0 ? BANK_U:BANK_Z,addr:32'(64'(token_index)*D)});
        assert(descriptor.dst==ptr_t'{bank:dst_bank,addr:32'(64'(token_index)*D)});
        assert(descriptor.weight_base==base+(MODE==0 ? projection_index*8:24));
        assert(descriptor.bias_base==base+(MODE==0 ? projection_index*8+4:28));
        pending<=1;delay_q<=1;fault_q<=CASE==1 || CASE==2 || CASE==7 && 64'(count_q)==CALLS-1;
      end
      if(pending && !reply) begin if(!delay_q) reply<=1;else delay_q<=0;end
      if(service.rsp_valid && service.rsp_ready) begin pending<=0;reply<=0;
        if(fault_q) fault_seen<=1;else count_q<=count_q+1;end
      if(command.rsp_valid) begin
        assert(!pending && !service.cmd_valid);
        if(fault_seen || CASE==3 || CASE==4) assert(command.rsp_error &&
          (command.rsp_status.protocol_error || command.rsp_status.numeric_error));
        else begin assert(!command.rsp_error && 64'(count_q)==CALLS);
          assert(command.rsp_status.saturated && command.rsp_status.rounded);end
        if(command.rsp_ready) begin
          if(CASE==0 && !run_q) begin run_q<=1;sent<=0;end else test_done<=1;
        end
      end
      if(test_done && (fault_seen || CASE==3 || CASE==4)) assert(!command.cmd_ready && !service.cmd_valid);
      if(service.cmd_valid && !service.cmd_ready || command.rsp_valid && !command.rsp_ready) saw_stall<=1;
      if(past_valid && !$past(rst)) begin
        if($past(service.cmd_valid && !service.cmd_ready)) assert(service.cmd_valid && service.cmd==$past(service.cmd));
        if($past(command.rsp_valid && !command.rsp_ready)) assert(command.rsp_valid &&
          {command.rsp_error,command.rsp_status}==$past({command.rsp_error,command.rsp_status}));
      end
    end
  end
endmodule
