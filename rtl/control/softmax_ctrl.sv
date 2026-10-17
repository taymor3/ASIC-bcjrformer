module softmax_ctrl #(
  parameter longint unsigned TOKENS=0,
  parameter logic [23:0] UNIFORM_PROB=0
)(input logic clk,rst,bcjr_cmd_if.callee command,bcjr_mem_if.requester mem,
  bcjr_arith_if.requester exponential,reciprocal);
  import bcjrformer_contract_pkg::*;import fixed_math_pkg::*;
  typedef enum logic [3:0] {IDLE,MAX_ISSUE,MAX_WAIT,SCORE_ISSUE,SCORE_WAIT,EXP_ISSUE,EXP_WAIT,
    EXP_WRITE_ISSUE,EXP_WRITE_WAIT,RECIP_ISSUE,RECIP_WAIT,PROB_READ_ISSUE,PROB_READ_WAIT,
    PROB_WRITE_ISSUE,PROB_WRITE_WAIT,RESPONSE} state_t;
  state_t state;count_t index_q;score_t maximum_q,difference_q;
  logic uniform_q;probability_t value_q;denominator_t sum_q;reciprocal_t inverse_q;
  status_t status_q;softmax_cmd_t incoming;
  wide_t difference,exp_sum;conversion_t probability;
  initial if(TOKENS==0 || TOKENS>65535 || UNIFORM_PROB==0 || UNIFORM_PROB>24'd4194304)
    $fatal(1,"invalid softmax length or uniform probability");
  always_comb begin
    incoming=softmax_cmd_t'(command.cmd);
    difference=wide_t'(score_t'(mem.rsp_rdata[47:0]))-wide_t'(maximum_q);
    exp_sum=wide_t'({1'b0,sum_q})+wide_t'({1'b0,probability_t'(exponential.rsp)});
    probability=convert(wide_t'({1'b0,mem.rsp_rdata[23:0]})*wide_t'({1'b0,inverse_q}),32,24,0,0);
    command.cmd_ready=!rst && state==IDLE && !fatal(status_q);
    command.rsp_valid=!rst && state==RESPONSE;command.rsp='0;
    command.rsp_error=fatal(status_q);command.rsp_status=status_q;
    mem.req='0;mem.req.addr=addr_t'(index_q);
    mem.req.bank=(state==MAX_ISSUE || state==SCORE_ISSUE) ? BANK_SCORE:
      (state==PROB_WRITE_ISSUE ? BANK_PROB:BANK_EXP);
    mem.req.format=(state==MAX_ISSUE || state==SCORE_ISSUE) ? FMT_S48_F20:FMT_U24_F22;
    mem.req.write=state==EXP_WRITE_ISSUE || state==PROB_WRITE_ISSUE;
    mem.req.wdata={72'b0,value_q};
    mem.req_valid=!rst && (state==MAX_ISSUE || state==SCORE_ISSUE || state==EXP_WRITE_ISSUE ||
      state==PROB_READ_ISSUE || state==PROB_WRITE_ISSUE);
    mem.rsp_ready=!rst && (state==MAX_WAIT || state==SCORE_WAIT || state==EXP_WRITE_WAIT ||
      state==PROB_READ_WAIT || state==PROB_WRITE_WAIT);
    exponential.req=difference_q;exponential.req_tag=0;
    exponential.req_valid=!rst && state==EXP_ISSUE;exponential.rsp_ready=!rst && state==EXP_WAIT;
    reciprocal.req=sum_q;reciprocal.req_tag=0;
    reciprocal.req_valid=!rst && state==RECIP_ISSUE;reciprocal.rsp_ready=!rst && state==RECIP_WAIT;
  end
  task automatic protocol_failure;begin status_q.protocol_error<=1;state<=RESPONSE;end endtask
  task automatic numeric_failure;begin status_q.numeric_error<=1;state<=RESPONSE;end endtask
  always_ff @(posedge clk) begin
    if(rst) begin state<=IDLE;index_q<=0;maximum_q<=0;difference_q<=0;uniform_q<=0;
      value_q<=0;sum_q<=0;inverse_q<=0;status_q<='0;end
    else case(state)
      IDLE:if(command.cmd_valid && command.cmd_ready) begin
        index_q<=0;sum_q<=0;uniform_q<=incoming.padded_query;status_q<='0;
        if(incoming.padded_query) begin value_q<=UNIFORM_PROB;state<=PROB_WRITE_ISSUE;end else state<=MAX_ISSUE;
      end
      MAX_ISSUE:if(mem.req_ready) state<=MAX_WAIT;
      MAX_WAIT:if(mem.rsp_valid) begin
        if(mem.rsp_error) protocol_failure();
        else begin
          if(index_q==0 || score_t'(mem.rsp_rdata[47:0])>maximum_q) maximum_q<=score_t'(mem.rsp_rdata[47:0]);
          if(64'(index_q)==TOKENS-1) begin index_q<=0;state<=SCORE_ISSUE;end
          else begin index_q<=index_q+1;state<=MAX_ISSUE;end
        end
      end
      SCORE_ISSUE:if(mem.req_ready) state<=SCORE_WAIT;
      SCORE_WAIT:if(mem.rsp_valid) begin
        if(mem.rsp_error) protocol_failure();else if(difference>0) numeric_failure();
        else if(difference<-(160'sd16<<<20)) begin value_q<=0;state<=EXP_WRITE_ISSUE;end
        else begin difference_q<=score_t'(difference);state<=EXP_ISSUE;end
      end
      EXP_ISSUE:if(exponential.req_ready) state<=EXP_WAIT;
      EXP_WAIT:if(exponential.rsp_valid) begin
        status_q<=status_q | child_status(exponential.rsp_status,exponential.rsp_error,exponential.rsp_tag!=0);
        if(exponential.rsp_error || fatal(exponential.rsp_status) || exponential.rsp_tag!=0) state<=RESPONSE;
        else if(probability_t'(exponential.rsp)>24'd4194304 || exp_sum>=(160'sd1<<<64) ||
          (difference_q==0 && exponential.rsp==0)) numeric_failure();
        else begin value_q<=probability_t'(exponential.rsp);sum_q<=denominator_t'(exp_sum);state<=EXP_WRITE_ISSUE;end
      end
      EXP_WRITE_ISSUE:if(mem.req_ready) state<=EXP_WRITE_WAIT;
      EXP_WRITE_WAIT:if(mem.rsp_valid) begin
        if(mem.rsp_error) protocol_failure();
        else if(64'(index_q)==TOKENS-1) begin
          if(sum_q==0) numeric_failure();else begin index_q<=0;state<=RECIP_ISSUE;end
        end else begin index_q<=index_q+1;state<=SCORE_ISSUE;end
      end
      RECIP_ISSUE:if(reciprocal.req_ready) state<=RECIP_WAIT;
      RECIP_WAIT:if(reciprocal.rsp_valid) begin
        status_q<=status_q | child_status(reciprocal.rsp_status,reciprocal.rsp_error,reciprocal.rsp_tag!=0);
        if(reciprocal.rsp_error || fatal(reciprocal.rsp_status) || reciprocal.rsp_tag!=0) state<=RESPONSE;
        else if(reciprocal.rsp==0) numeric_failure();
        else begin inverse_q<=reciprocal_t'(reciprocal.rsp);index_q<=0;state<=PROB_READ_ISSUE;end
      end
      PROB_READ_ISSUE:if(mem.req_ready) state<=PROB_READ_WAIT;
      PROB_READ_WAIT:if(mem.rsp_valid) begin
        if(mem.rsp_error) protocol_failure();
        else begin status_q<=status_q | probability.status;
          if(fatal(probability.status) || probability.value>4194304) numeric_failure();
          else begin value_q<=probability_t'(probability.value);state<=PROB_WRITE_ISSUE;end
        end
      end
      PROB_WRITE_ISSUE:if(mem.req_ready) state<=PROB_WRITE_WAIT;
      PROB_WRITE_WAIT:if(mem.rsp_valid) begin
        if(mem.rsp_error) protocol_failure();else if(64'(index_q)==TOKENS-1) state<=RESPONSE;
        else begin index_q<=index_q+1;state<=uniform_q ? PROB_WRITE_ISSUE:PROB_READ_ISSUE;end
      end
      RESPONSE:if(command.rsp_ready) state<=IDLE;
      default:protocol_failure();
    endcase
  end
endmodule
