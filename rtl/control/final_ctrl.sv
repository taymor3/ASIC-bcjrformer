module final_ctrl #(
  parameter longint unsigned TOKENS=0,D=0,
  parameter bcjrformer_contract_pkg::addr_t WEIGHT_BASE=0,BIAS_BASE=0
)(input logic clk,rst,bcjr_cmd_if.callee command,bcjr_cmd_if.caller linear);
  import bcjrformer_contract_pkg::*;import fixed_math_pkg::*;
  typedef enum logic [1:0] {IDLE,ISSUE,WAIT_RESPONSE,RESPONSE} state_t;
  state_t state;count_t token_q;status_t status_q;linear_cmd_t descriptor;
  initial if(TOKENS==0 || TOKENS>65535 || D==0 || D>65535 || TOKENS*D>(64'd1<<ADDR_W) ||
    !extent(WEIGHT_BASE,D) || !extent(BIAS_BASE,1)) $fatal(1,"invalid final projection configuration");
  always_comb begin
    descriptor='{in_count:count_t'(D),out_count:1,src:'{bank:BANK_X,addr:addr_t'(64'(token_q)*D)},
      dst:'{bank:BANK_LOGIT,addr:addr_t'(token_q)},weight_base:WEIGHT_BASE,bias_base:BIAS_BASE};
    command.cmd_ready=!rst && state==IDLE && !fatal(status_q);
    command.rsp_valid=!rst && state==RESPONSE;command.rsp='0;
    command.rsp_error=fatal(status_q);command.rsp_status=status_q;
    linear.cmd=descriptor;linear.cmd_valid=!rst && state==ISSUE;linear.rsp_ready=!rst && state==WAIT_RESPONSE;
  end
  always_ff @(posedge clk) begin
    if(rst) begin state<=IDLE;token_q<=0;status_q<='0;end
    else case(state)
      IDLE:if(command.cmd_valid && command.cmd_ready) begin token_q<=0;status_q<='0;
        if(command.cmd!='0) begin status_q.protocol_error<=1;state<=RESPONSE;end else state<=ISSUE;end
      ISSUE:if(linear.cmd_ready) state<=WAIT_RESPONSE;
      WAIT_RESPONSE:if(linear.rsp_valid) begin
        status_q<=status_q | child_status(linear.rsp_status,linear.rsp_error);
        if(linear.rsp_error || fatal(linear.rsp_status) || 64'(token_q)==TOKENS-1) state<=RESPONSE;
        else begin token_q<=token_q+1;state<=ISSUE;end
      end
      RESPONSE:if(command.rsp_ready) state<=IDLE;
      default:begin status_q.protocol_error<=1;state<=RESPONSE;end
    endcase
  end
endmodule
