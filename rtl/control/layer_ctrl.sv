module layer_ctrl #(
  parameter longint unsigned TOKENS=0,D=0,K=0,LAYER_WORDS=0,
  parameter bcjrformer_contract_pkg::addr_t LN1_GAMMA_OFFSET='0,LN1_BETA_OFFSET='0,
  parameter bcjrformer_contract_pkg::addr_t LN2_GAMMA_OFFSET='0,LN2_BETA_OFFSET='0
)(input logic clk,rst,bcjr_cmd_if.callee command,
  bcjr_cmd_if.caller norm,attention,residual,ffn);
  import bcjrformer_contract_pkg::*;
  typedef enum logic [1:0] {IDLE,ISSUE,WAIT_RESPONSE,RESPONSE} state_t;
  state_t state;
  logic [2:0] phase;
  localparam int TW=TOKENS>1 ? $clog2(TOKENS):1;
  logic [TW-1:0] token_q;
  layer_cmd_t layer_q,incoming;
  layernorm_cmd_t norm_descriptor;
  residual_cmd_t residual_descriptor;
  ffn_cmd_t ffn_descriptor;
  status_t status_q,child_status;
  logic child_ready,child_valid,child_error;
  addr_t token_address;
  initial begin
    if(TOKENS==0 || TOKENS>65535 || D==0 || D>65535 || K==0 || K>65535 ||
       TOKENS*D>(64'd1<<ADDR_W) || LAYER_WORDS==0 || LAYER_WORDS>(64'd1<<ADDR_W) ||
       64'(LN1_GAMMA_OFFSET)+D>LAYER_WORDS || 64'(LN1_BETA_OFFSET)+D>LAYER_WORDS ||
       64'(LN2_GAMMA_OFFSET)+D>LAYER_WORDS || 64'(LN2_BETA_OFFSET)+D>LAYER_WORDS)
      $fatal(1,"layer_ctrl requires bounded dimensions and valid norm offsets");
  end
  always_comb begin
    incoming=layer_cmd_t'(command.cmd);
    token_address=addr_t'(64'(token_q)*D);
    norm_descriptor='{length:count_t'(D),src:'{bank:BANK_X,addr:token_address},
      dst:'{bank:BANK_U,addr:token_address},
      gamma_base:addr_t'(64'(layer_q.layer_param_base)+64'(phase==0 ? LN1_GAMMA_OFFSET:LN2_GAMMA_OFFSET)),
      beta_base:addr_t'(64'(layer_q.layer_param_base)+64'(phase==0 ? LN1_BETA_OFFSET:LN2_BETA_OFFSET))};
    residual_descriptor='{length:count_t'(D),left:'{bank:BANK_X,addr:token_address},
      right:'{bank:phase==2 ? BANK_ATTN_OUT:BANK_VECTOR,addr:phase==2 ? token_address:32'd0},
      dst:'{bank:BANK_X,addr:token_address}};
    ffn_descriptor='{src:'{bank:BANK_U,addr:token_address},dst:'{bank:BANK_VECTOR,addr:'0},
      layer_param_base:layer_q.layer_param_base};
    command.cmd_ready=!rst && state==IDLE && !status_q.protocol_error && !status_q.numeric_error;
    command.rsp_valid=!rst && state==RESPONSE;command.rsp='0;
    command.rsp_status=status_q;command.rsp_error=status_q.protocol_error || status_q.numeric_error;
    norm.cmd=norm_descriptor;attention.cmd=layer_q;residual.cmd=residual_descriptor;ffn.cmd=ffn_descriptor;
    norm.cmd_valid=!rst && state==ISSUE && (phase==0 || phase==3);
    attention.cmd_valid=!rst && state==ISSUE && phase==1;
    residual.cmd_valid=!rst && state==ISSUE && (phase==2 || phase==5);
    ffn.cmd_valid=!rst && state==ISSUE && phase==4;
    norm.rsp_ready=!rst && state==WAIT_RESPONSE && (phase==0 || phase==3);
    attention.rsp_ready=!rst && state==WAIT_RESPONSE && phase==1;
    residual.rsp_ready=!rst && state==WAIT_RESPONSE && (phase==2 || phase==5);
    ffn.rsp_ready=!rst && state==WAIT_RESPONSE && phase==4;
    child_ready=0;child_valid=0;child_error=0;child_status='0;
    case(phase)
      0,3: begin child_ready=norm.cmd_ready;child_valid=norm.rsp_valid;child_error=norm.rsp_error;child_status=norm.rsp_status;end
      1: begin child_ready=attention.cmd_ready;child_valid=attention.rsp_valid;child_error=attention.rsp_error;child_status=attention.rsp_status;end
      2,5: begin child_ready=residual.cmd_ready;child_valid=residual.rsp_valid;child_error=residual.rsp_error;child_status=residual.rsp_status;end
      4: begin child_ready=ffn.cmd_ready;child_valid=ffn.rsp_valid;child_error=ffn.rsp_error;child_status=ffn.rsp_status;end
      default: ;
    endcase
  end
  always_ff @(posedge clk) begin
    if(rst) begin state<=IDLE;phase<=0;token_q<=0;layer_q<='0;status_q<='0;end
    else case(state)
      IDLE: if(command.cmd_valid && command.cmd_ready) begin
        layer_q<=incoming;phase<=0;token_q<=0;status_q<='0;
        if(64'(incoming.layer_index)>=K || 64'(incoming.layer_param_base)+LAYER_WORDS>(64'd1<<ADDR_W)) begin
          status_q.protocol_error<=1;state<=RESPONSE;end
        else state<=ISSUE;
      end
      ISSUE: if(child_ready) state<=WAIT_RESPONSE;
      WAIT_RESPONSE: if(child_valid) begin
        status_q<=status_q | child_status;
        if(child_error || child_status.protocol_error || child_status.numeric_error) begin
          if(child_error && !child_status.protocol_error && !child_status.numeric_error) status_q.protocol_error<=1;
          state<=RESPONSE;
        end else case(phase)
          0,2,3: begin
            if(64'(token_q)==TOKENS-1) begin token_q<=0;phase<=phase+1;end
            else token_q<=token_q+1;
            state<=ISSUE;
          end
          1: begin token_q<=0;phase<=2;state<=ISSUE;end
          4: begin phase<=5;state<=ISSUE;end
          5: if(64'(token_q)==TOKENS-1) state<=RESPONSE;
             else begin token_q<=token_q+1;phase<=4;state<=ISSUE;end
          default: begin status_q.protocol_error<=1;state<=RESPONSE;end
        endcase
      end
      RESPONSE: if(command.rsp_ready) state<=IDLE;
      default: begin status_q.protocol_error<=1;state<=RESPONSE;end
    endcase
  end
endmodule
