module residual_ctrl(input logic clk,rst,bcjr_cmd_if.callee command,bcjr_mem_if.requester mem);
  import bcjrformer_contract_pkg::*;import fixed_math_pkg::*;
  typedef enum logic [2:0] {IDLE,LEFT_ISSUE,LEFT_WAIT,RIGHT_ISSUE,RIGHT_WAIT,WRITE_ISSUE,WRITE_WAIT,RESPONSE} state_t;
  state_t state;residual_cmd_t descriptor_q,incoming;count_t index_q;
  act_t left_q,value_q;status_t status_q;conversion_t added;
  always_comb begin
    incoming=residual_cmd_t'(command.cmd);
    added=convert(wide_t'(left_q)+wide_t'(act_t'(mem.rsp_rdata[15:0])),0,16,1,1);
    command.cmd_ready=!rst && state==IDLE && !fatal(status_q);
    command.rsp_valid=!rst && state==RESPONSE;command.rsp='0;
    command.rsp_status=status_q;command.rsp_error=fatal(status_q);
    mem.req='0;mem.req.format=FMT_S16_F10;
    mem.req.bank=state==LEFT_ISSUE ? descriptor_q.left.bank:state==RIGHT_ISSUE ? descriptor_q.right.bank:descriptor_q.dst.bank;
    mem.req.addr=addr_t'(64'(index_q)+64'(state==LEFT_ISSUE ? descriptor_q.left.addr:
      state==RIGHT_ISSUE ? descriptor_q.right.addr:descriptor_q.dst.addr));
    mem.req.write=state==WRITE_ISSUE;mem.req.wdata={80'b0,value_q};
    mem.req_valid=!rst && (state==LEFT_ISSUE || state==RIGHT_ISSUE || state==WRITE_ISSUE);
    mem.rsp_ready=!rst && (state==LEFT_WAIT || state==RIGHT_WAIT || state==WRITE_WAIT);
  end
  always_ff @(posedge clk) begin
    if(rst) begin state<=IDLE;descriptor_q<='0;index_q<=0;left_q<=0;value_q<=0;status_q<='0;end
    else case(state)
      IDLE:if(command.cmd_valid && command.cmd_ready) begin
        descriptor_q<=incoming;index_q<=0;status_q<='0;
        if(!act_bank(incoming.left.bank) || !act_bank(incoming.right.bank) || !act_destination(incoming.dst.bank) ||
          !extent(incoming.left.addr,64'(incoming.length)) || !extent(incoming.right.addr,64'(incoming.length)) ||
          !extent(incoming.dst.addr,64'(incoming.length)) ||
          (overlap(incoming.left,64'(incoming.length),incoming.dst,64'(incoming.length)) && incoming.left!=incoming.dst) ||
          (overlap(incoming.right,64'(incoming.length),incoming.dst,64'(incoming.length)) && incoming.right!=incoming.dst)) begin
          status_q.protocol_error<=1;state<=RESPONSE;end else state<=LEFT_ISSUE;
      end
      LEFT_ISSUE:if(mem.req_ready) state<=LEFT_WAIT;
      RIGHT_ISSUE:if(mem.req_ready) state<=RIGHT_WAIT;
      LEFT_WAIT:if(mem.rsp_valid) begin
        if(mem.rsp_error) begin status_q.protocol_error<=1;state<=RESPONSE;end
        else begin left_q<=act_t'(mem.rsp_rdata[15:0]);state<=RIGHT_ISSUE;end
      end
      RIGHT_WAIT:if(mem.rsp_valid) begin
        if(mem.rsp_error) begin status_q.protocol_error<=1;state<=RESPONSE;end
        else begin value_q<=act_t'(added.value);status_q<=status_q | added.status;state<=WRITE_ISSUE;end
      end
      WRITE_ISSUE:if(mem.req_ready) state<=WRITE_WAIT;
      WRITE_WAIT:if(mem.rsp_valid) begin
        if(mem.rsp_error) begin status_q.protocol_error<=1;state<=RESPONSE;end
        else if(index_q==descriptor_q.length-1) state<=RESPONSE;
        else begin index_q<=index_q+1;state<=LEFT_ISSUE;end
      end
      RESPONSE:if(command.rsp_ready) state<=IDLE;
      default:begin status_q.protocol_error<=1;state<=RESPONSE;end
    endcase
  end
endmodule
