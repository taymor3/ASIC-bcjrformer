module ffn_ctrl #(
  parameter longint unsigned D=0,LAYER_WORDS=0,
  parameter bcjrformer_contract_pkg::addr_t W1_OFFSET=0,B1_OFFSET=0,W2_OFFSET=0,B2_OFFSET=0
)(input logic clk,rst,bcjr_cmd_if.callee command,bcjr_cmd_if.caller linear,
  bcjr_mem_if.requester mem,bcjr_arith_if.requester gelu);
  import bcjrformer_contract_pkg::*;import fixed_math_pkg::*;
  typedef enum logic [3:0] {IDLE,LINEAR_ISSUE,LINEAR_WAIT,READ_ISSUE,READ_WAIT,GELU_ISSUE,GELU_WAIT,WRITE_ISSUE,WRITE_WAIT,RESPONSE} state_t;
  state_t state;ffn_cmd_t descriptor_q,incoming;linear_cmd_t linear_descriptor;
  count_t index_q;logic second_q;act_t input_q;gelu_t value_q;status_t status_q;
  initial if(D==0 || D>16383 || LAYER_WORDS==0 || LAYER_WORDS>(64'd1<<ADDR_W) ||
    64'(W1_OFFSET)+4*D*D>LAYER_WORDS || 64'(B1_OFFSET)+4*D>LAYER_WORDS ||
    64'(W2_OFFSET)+4*D*D>LAYER_WORDS || 64'(B2_OFFSET)+D>LAYER_WORDS)
    $fatal(1,"invalid FFN dimensions or tensor offsets");
  always_comb begin
    incoming=ffn_cmd_t'(command.cmd);
    linear_descriptor='{in_count:count_t'(second_q ? 4*D:D),out_count:count_t'(second_q ? D:4*D),
      src:second_q ? ptr_t'{bank:BANK_FFN_HIDDEN,addr:0}:descriptor_q.src,
      dst:second_q ? descriptor_q.dst:ptr_t'{bank:BANK_FFN_HIDDEN,addr:0},
      weight_base:addr_t'(64'(descriptor_q.layer_param_base)+64'(second_q ? W2_OFFSET:W1_OFFSET)),
      bias_base:addr_t'(64'(descriptor_q.layer_param_base)+64'(second_q ? B2_OFFSET:B1_OFFSET))};
    command.cmd_ready=!rst && state==IDLE && !fatal(status_q);
    command.rsp_valid=!rst && state==RESPONSE;command.rsp='0;
    command.rsp_error=fatal(status_q);command.rsp_status=status_q;
    linear.cmd=linear_descriptor;linear.cmd_valid=!rst && state==LINEAR_ISSUE;linear.rsp_ready=!rst && state==LINEAR_WAIT;
    mem.req='0;mem.req.bank=BANK_FFN_HIDDEN;mem.req.addr=addr_t'(index_q);mem.req.format=FMT_S32_F22;
    mem.req.write=state==WRITE_ISSUE;mem.req.wdata={64'b0,value_q};
    mem.req_valid=!rst && (state==READ_ISSUE || state==WRITE_ISSUE);
    mem.rsp_ready=!rst && (state==READ_WAIT || state==WRITE_WAIT);
    gelu.req=input_q;gelu.req_tag=0;gelu.req_valid=!rst && state==GELU_ISSUE;gelu.rsp_ready=!rst && state==GELU_WAIT;
  end
  always_ff @(posedge clk) begin
    if(rst) begin state<=IDLE;descriptor_q<='0;index_q<=0;second_q<=0;input_q<=0;value_q<=0;status_q<='0;end
    else case(state)
      IDLE:if(command.cmd_valid && command.cmd_ready) begin
        descriptor_q<=incoming;index_q<=0;second_q<=0;status_q<='0;
        if(!act_bank(incoming.src.bank) || !act_destination(incoming.dst.bank) ||
          !extent(incoming.src.addr,D) || !extent(incoming.dst.addr,D) ||
          incoming.src.bank==BANK_FFN_HIDDEN || incoming.dst.bank==BANK_FFN_HIDDEN ||
          64'(incoming.layer_param_base)+LAYER_WORDS>(64'd1<<ADDR_W)) begin
          status_q.protocol_error<=1;state<=RESPONSE;end else state<=LINEAR_ISSUE;
      end
      LINEAR_ISSUE:if(linear.cmd_ready) state<=LINEAR_WAIT;
      LINEAR_WAIT:if(linear.rsp_valid) begin
        status_q<=status_q | child_status(linear.rsp_status,linear.rsp_error);
        if(linear.rsp_error || fatal(linear.rsp_status) || second_q) state<=RESPONSE;
        else begin index_q<=0;state<=READ_ISSUE;end
      end
      READ_ISSUE:if(mem.req_ready) state<=READ_WAIT;
      READ_WAIT:if(mem.rsp_valid) begin
        if(mem.rsp_error) begin status_q.protocol_error<=1;state<=RESPONSE;end
        else if(mem.rsp_rdata[11:0]!=0 ||
          (gelu_t'(mem.rsp_rdata[31:0])>>>12)!=gelu_t'(act_t'(mem.rsp_rdata[27:12]))) begin
          status_q.protocol_error<=1;state<=RESPONSE;end
        else begin input_q<=act_t'(mem.rsp_rdata[27:12]);state<=GELU_ISSUE;end
      end
      GELU_ISSUE:if(gelu.req_ready) state<=GELU_WAIT;
      GELU_WAIT:if(gelu.rsp_valid) begin
        status_q<=status_q | child_status(gelu.rsp_status,gelu.rsp_error,gelu.rsp_tag!=0);
        if(gelu.rsp_error || fatal(gelu.rsp_status) || gelu.rsp_tag!=0) state<=RESPONSE;
        else begin value_q<=gelu_t'(gelu.rsp);state<=WRITE_ISSUE;end
      end
      WRITE_ISSUE:if(mem.req_ready) state<=WRITE_WAIT;
      WRITE_WAIT:if(mem.rsp_valid) begin
        if(mem.rsp_error) begin status_q.protocol_error<=1;state<=RESPONSE;end
        else if(64'(index_q)==4*D-1) begin second_q<=1;state<=LINEAR_ISSUE;end
        else begin index_q<=index_q+1;state<=READ_ISSUE;end
      end
      RESPONSE:if(command.rsp_ready) state<=IDLE;
      default:begin status_q.protocol_error<=1;state<=RESPONSE;end
    endcase
  end
endmodule
