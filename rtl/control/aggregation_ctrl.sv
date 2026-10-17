module aggregation_ctrl #(parameter longint unsigned M=0,N=0)(
  input logic clk,rst,bcjr_cmd_if.callee command,bcjr_mem_if.requester mem,bcjr_arith_if.requester reciprocal);
  import bcjrformer_contract_pkg::*;import fixed_math_pkg::*;
  typedef enum logic [3:0] {IDLE,MASK_ISSUE,MASK_WAIT,LOGIT_ISSUE,LOGIT_WAIT,NEXT_READ,CHECK_COUNT,
    RECIP_ISSUE,RECIP_WAIT,WRITE_ISSUE,WRITE_WAIT,RESPONSE} state_t;
  state_t state;count_t m_q,n_q,count_q;score_t sum_q;act_t value_q;
  status_t status_q;aggregation_rsp_t response_q;conversion_t added,scaled;
  initial if(M==0 || M>65535 || N==0 || N>65535 || M*N>65535) $fatal(1,"invalid aggregation shape");
  always_comb begin
    added=convert(wide_t'(sum_q)+wide_t'(act_t'(mem.rsp_rdata[15:0])),0,48,1,0);
    scaled=convert(wide_t'(sum_q)*wide_t'({1'b0,reciprocal_t'(reciprocal.rsp)}),32,16,1,1);
    command.cmd_ready=!rst && state==IDLE && !fatal(status_q);
    command.rsp_valid=!rst && state==RESPONSE;command.rsp=response_q;
    command.rsp_error=fatal(status_q);command.rsp_status=status_q;
    mem.req='0;mem.req.bank=state==MASK_ISSUE ? BANK_MASK:state==LOGIT_ISSUE ? BANK_LOGIT:BANK_OUTPUT;
    mem.req.addr=state==WRITE_ISSUE ? addr_t'(n_q):addr_t'(64'(m_q)*N+64'(n_q));
    mem.req.format=state==MASK_ISSUE ? FMT_BIT:FMT_S16_F10;
    mem.req.write=state==WRITE_ISSUE;mem.req.wdata={80'b0,value_q};
    mem.req_valid=!rst && (state==MASK_ISSUE || state==LOGIT_ISSUE || state==WRITE_ISSUE);
    mem.rsp_ready=!rst && (state==MASK_WAIT || state==LOGIT_WAIT || state==WRITE_WAIT);
    reciprocal.req=denominator_t'(count_q)<<22;reciprocal.req_tag=0;
    reciprocal.req_valid=!rst && state==RECIP_ISSUE;reciprocal.rsp_ready=!rst && state==RECIP_WAIT;
  end
  task automatic fail_protocol;begin status_q.protocol_error<=1;response_q.code<=COMPLETION_FATAL;state<=RESPONSE;end endtask
  always_ff @(posedge clk) begin
    if(rst) begin state<=IDLE;m_q<=0;n_q<=0;count_q<=0;sum_q<=0;value_q<=0;status_q<='0;response_q<='0;end
    else case(state)
      IDLE:if(command.cmd_valid && command.cmd_ready) begin
        m_q<=0;n_q<=0;count_q<=0;sum_q<=0;status_q<='0;response_q<='0;
        if(command.cmd!='0) fail_protocol();else state<=MASK_ISSUE;
      end
      MASK_ISSUE:if(mem.req_ready) state<=MASK_WAIT;
      MASK_WAIT:if(mem.rsp_valid) begin
        if(mem.rsp_error) fail_protocol();else state<=mem.rsp_rdata[0] ? NEXT_READ:LOGIT_ISSUE;end
      LOGIT_ISSUE:if(mem.req_ready) state<=LOGIT_WAIT;
      LOGIT_WAIT:if(mem.rsp_valid) begin
        if(mem.rsp_error) fail_protocol();
        else if(fatal(added.status)) begin status_q.numeric_error<=1;response_q.code<=COMPLETION_FATAL;state<=RESPONSE;end
        else begin sum_q<=score_t'(added.value);count_q<=count_q+1;state<=NEXT_READ;end
      end
      NEXT_READ:if(64'(m_q)==M-1) state<=CHECK_COUNT;else begin m_q<=m_q+1;state<=MASK_ISSUE;end
      CHECK_COUNT:if(count_q==0) begin response_q<='{code:COMPLETION_EMPTY_POSITION,position:n_q};state<=RESPONSE;end
        else state<=RECIP_ISSUE;
      RECIP_ISSUE:if(reciprocal.req_ready) state<=RECIP_WAIT;
      RECIP_WAIT:if(reciprocal.rsp_valid) begin
        status_q<=status_q | child_status(reciprocal.rsp_status,reciprocal.rsp_error,reciprocal.rsp_tag!=0) | scaled.status;
        if(reciprocal.rsp_error || fatal(reciprocal.rsp_status) || reciprocal.rsp_tag!=0 || reciprocal.rsp==0) begin
          if(reciprocal.rsp==0) status_q.numeric_error<=1;
          response_q.code<=COMPLETION_FATAL;state<=RESPONSE;
        end else begin value_q<=act_t'(scaled.value);state<=WRITE_ISSUE;end
      end
      WRITE_ISSUE:if(mem.req_ready) state<=WRITE_WAIT;
      WRITE_WAIT:if(mem.rsp_valid) begin
        if(mem.rsp_error) fail_protocol();else if(64'(n_q)==N-1) state<=RESPONSE;
        else begin n_q<=n_q+1;m_q<=0;sum_q<=0;count_q<=0;state<=MASK_ISSUE;end
      end
      RESPONSE:if(command.rsp_ready) state<=IDLE;
      default:fail_protocol();
    endcase
  end
endmodule
