// Internal controller shared by QKV and output-projection wrappers.
module projection_loop #(
  parameter longint unsigned TOKENS=0,D=0,K=0,LAYER_WORDS=0,
  parameter int unsigned PROJECTIONS=1,
  parameter bcjrformer_contract_pkg::bank_t INPUT_BANK=bcjrformer_contract_pkg::BANK_U,
  parameter bcjrformer_contract_pkg::bank_t OUTPUT_BANKS [PROJECTIONS]='{default:bcjrformer_contract_pkg::BANK_Q},
  parameter bcjrformer_contract_pkg::addr_t WEIGHT_OFFSETS [PROJECTIONS]='{default:'0},
  parameter bcjrformer_contract_pkg::addr_t BIAS_OFFSETS [PROJECTIONS]='{default:'0}
)(input logic clk,rst,bcjr_cmd_if.callee command,bcjr_cmd_if.caller linear);
  import bcjrformer_contract_pkg::*;
  typedef enum logic [1:0] {IDLE,ISSUE,WAIT_RESPONSE,RESPONSE} state_t;
  state_t state;
  localparam int TW=TOKENS>1 ? $clog2(TOKENS):1;
  localparam int PW=PROJECTIONS>1 ? $clog2(PROJECTIONS):1;
  logic [TW-1:0] token_q;
  logic [PW-1:0] projection_q;
  layer_cmd_t layer_q,incoming;
  linear_cmd_t descriptor;
  status_t status_q;
  initial begin
    if(TOKENS==0 || TOKENS>65535 || D==0 || D>65535 || K==0 || K>65535 ||
       TOKENS*D>(64'd1<<ADDR_W) || LAYER_WORDS==0 || LAYER_WORDS>(64'd1<<ADDR_W) ||
       PROJECTIONS==0 || PROJECTIONS>3)
      $fatal(1,"projection_loop requires bounded dimensions and projection count");
    for(int p=0;p<PROJECTIONS;p++)
      if(64'(WEIGHT_OFFSETS[p])+D*D>LAYER_WORDS || 64'(BIAS_OFFSETS[p])+D>LAYER_WORDS)
        $fatal(1,"projection tensors exceed the configured layer region");
  end
  always_comb begin
    incoming=layer_cmd_t'(command.cmd);
    descriptor='{in_count:count_t'(D),out_count:count_t'(D),
      src:'{bank:INPUT_BANK,addr:addr_t'(64'(token_q)*D)},
      dst:'{bank:OUTPUT_BANKS[projection_q],addr:addr_t'(64'(token_q)*D)},
      weight_base:addr_t'(64'(layer_q.layer_param_base)+64'(WEIGHT_OFFSETS[projection_q])),
      bias_base:addr_t'(64'(layer_q.layer_param_base)+64'(BIAS_OFFSETS[projection_q]))};
    command.cmd_ready=!rst && state==IDLE && !status_q.protocol_error && !status_q.numeric_error;
    command.rsp_valid=!rst && state==RESPONSE;command.rsp='0;
    command.rsp_status=status_q;command.rsp_error=status_q.protocol_error || status_q.numeric_error;
    linear.cmd=descriptor;linear.cmd_valid=!rst && state==ISSUE;
    linear.rsp_ready=!rst && state==WAIT_RESPONSE;
  end
  always_ff @(posedge clk) begin
    if(rst) begin state<=IDLE;token_q<=0;projection_q<=0;layer_q<='0;status_q<='0;end
    else case(state)
      IDLE:if(command.cmd_valid && command.cmd_ready) begin
        layer_q<=incoming;token_q<=0;projection_q<=0;status_q<='0;
        if(64'(incoming.layer_index)>=K || 64'(incoming.layer_param_base)+LAYER_WORDS>(64'd1<<ADDR_W)) begin
          status_q.protocol_error<=1;state<=RESPONSE;end else state<=ISSUE;
      end
      ISSUE:if(linear.cmd_ready) state<=WAIT_RESPONSE;
      WAIT_RESPONSE:if(linear.rsp_valid) begin
        status_q<=status_q | linear.rsp_status;
        if(linear.rsp_error || linear.rsp_status.protocol_error || linear.rsp_status.numeric_error) begin
          if(linear.rsp_error && !linear.rsp_status.protocol_error && !linear.rsp_status.numeric_error)
            status_q.protocol_error<=1;
          state<=RESPONSE;
        end else if(64'(token_q)<TOKENS-1) begin token_q<=token_q+1;state<=ISSUE;end
        else if(32'(projection_q)<PROJECTIONS-1) begin token_q<=0;projection_q<=projection_q+1;state<=ISSUE;end
        else state<=RESPONSE;
      end
      RESPONSE:if(command.rsp_ready) state<=IDLE;
      default:begin status_q.protocol_error<=1;state<=RESPONSE;end
    endcase
  end
endmodule
