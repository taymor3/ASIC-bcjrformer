// Attention parent: tensors remain in banks; head split/join is addressing.
module attention_ctrl #(
  parameter longint unsigned TOKENS=0,H=0,D=0,K=0,LAYER_WORDS=0
)(input logic clk,rst,bcjr_cmd_if.callee command,
  bcjr_cmd_if.caller qkv,score,softmax,weighted,out_project,
  bcjr_mem_if.requester mem);
  import bcjrformer_contract_pkg::*;
  typedef enum logic [3:0] {IDLE,QKV_ISSUE,QKV_WAIT,MASK_ISSUE,MASK_WAIT,
    SCORE_ISSUE,SCORE_WAIT,SOFTMAX_ISSUE,SOFTMAX_WAIT,WEIGHTED_ISSUE,WEIGHTED_WAIT,
    OUTPUT_ISSUE,OUTPUT_WAIT,RESPONSE} state_t;
  state_t state;
  localparam int HW=H>1 ? $clog2(H):1;
  localparam int QW=TOKENS>1 ? $clog2(TOKENS):1;
  logic [HW-1:0] head_q;
  logic [QW-1:0] query_q;
  logic padded_q;
  layer_cmd_t layer_q,incoming;
  row_cmd_t row_descriptor;
  softmax_cmd_t softmax_descriptor;
  status_t status_q,child_status;
  logic child_valid,child_error;
  initial begin
    if(TOKENS==0 || TOKENS>65535 || H==0 || H>65535 || D==0 || D>65535 ||
       K==0 || K>65535 || D%H!=0 || TOKENS*D>(64'd1<<ADDR_W) ||
       LAYER_WORDS==0 || LAYER_WORDS>(64'd1<<ADDR_W))
      $fatal(1,"attention_ctrl requires positive bounded dimensions and layer extent");
  end
  always_comb begin
    incoming=layer_cmd_t'(command.cmd);
    row_descriptor='{head_index:count_t'(head_q),query_index:count_t'(query_q)};
    softmax_descriptor='{padded_query:padded_q};
    command.cmd_ready=!rst && state==IDLE && !status_q.protocol_error && !status_q.numeric_error;
    command.rsp_valid=!rst && state==RESPONSE;command.rsp='0;
    command.rsp_status=status_q;command.rsp_error=status_q.protocol_error || status_q.numeric_error;
    qkv.cmd=layer_q;out_project.cmd=layer_q;score.cmd=row_descriptor;weighted.cmd=row_descriptor;
    softmax.cmd=softmax_descriptor;
    qkv.cmd_valid=!rst && state==QKV_ISSUE;score.cmd_valid=!rst && state==SCORE_ISSUE;
    softmax.cmd_valid=!rst && state==SOFTMAX_ISSUE;weighted.cmd_valid=!rst && state==WEIGHTED_ISSUE;
    out_project.cmd_valid=!rst && state==OUTPUT_ISSUE;
    qkv.rsp_ready=!rst && state==QKV_WAIT;score.rsp_ready=!rst && state==SCORE_WAIT;
    softmax.rsp_ready=!rst && state==SOFTMAX_WAIT;weighted.rsp_ready=!rst && state==WEIGHTED_WAIT;
    out_project.rsp_ready=!rst && state==OUTPUT_WAIT;
    mem.req='{write:1'b0,bank:BANK_MASK,addr:addr_t'(query_q),format:FMT_BIT,wdata:'0};
    mem.req_valid=!rst && state==MASK_ISSUE;mem.rsp_ready=!rst && state==MASK_WAIT;
    child_valid=0;child_error=0;child_status='0;
    case(state)
      QKV_WAIT:begin child_valid=qkv.rsp_valid;child_error=qkv.rsp_error;child_status=qkv.rsp_status;end
      SCORE_WAIT:begin child_valid=score.rsp_valid;child_error=score.rsp_error;child_status=score.rsp_status;end
      SOFTMAX_WAIT:begin child_valid=softmax.rsp_valid;child_error=softmax.rsp_error;child_status=softmax.rsp_status;end
      WEIGHTED_WAIT:begin child_valid=weighted.rsp_valid;child_error=weighted.rsp_error;child_status=weighted.rsp_status;end
      OUTPUT_WAIT:begin child_valid=out_project.rsp_valid;child_error=out_project.rsp_error;child_status=out_project.rsp_status;end
      default: ;
    endcase
  end
  always_ff @(posedge clk) begin
    if(rst) begin state<=IDLE;head_q<=0;query_q<=0;padded_q<=0;layer_q<='0;status_q<='0;end
    else begin
      if(child_valid) begin
        status_q<=status_q | child_status;
        if(child_error || child_status.protocol_error || child_status.numeric_error) begin
          if(child_error && !child_status.protocol_error && !child_status.numeric_error) status_q.protocol_error<=1;
          state<=RESPONSE;
        end else case(state)
          QKV_WAIT:state<=MASK_ISSUE;
          SCORE_WAIT:state<=SOFTMAX_ISSUE;
          SOFTMAX_WAIT:state<=WEIGHTED_ISSUE;
          WEIGHTED_WAIT:begin
            if(64'(query_q)<TOKENS-1) begin query_q<=query_q+1;state<=MASK_ISSUE;end
            else if(64'(head_q)<H-1) begin head_q<=head_q+1;query_q<=0;state<=MASK_ISSUE;end
            else state<=OUTPUT_ISSUE;
          end
          OUTPUT_WAIT:state<=RESPONSE;
          default:begin status_q.protocol_error<=1;state<=RESPONSE;end
        endcase
      end else case(state)
        IDLE:if(command.cmd_valid && command.cmd_ready) begin
          layer_q<=incoming;head_q<=0;query_q<=0;padded_q<=0;status_q<='0;
          if(64'(incoming.layer_index)>=K || 64'(incoming.layer_param_base)+LAYER_WORDS>(64'd1<<ADDR_W)) begin
            status_q.protocol_error<=1;state<=RESPONSE;end else state<=QKV_ISSUE;
        end
        QKV_ISSUE:if(qkv.cmd_ready) state<=QKV_WAIT;
        MASK_ISSUE:if(mem.req_ready) state<=MASK_WAIT;
        MASK_WAIT:if(mem.rsp_valid) begin
          if(mem.rsp_error) begin status_q.protocol_error<=1;state<=RESPONSE;end
          else begin padded_q<=mem.rsp_rdata[0];state<=SCORE_ISSUE;end
        end
        SCORE_ISSUE:if(score.cmd_ready) state<=SCORE_WAIT;
        SOFTMAX_ISSUE:if(softmax.cmd_ready) state<=SOFTMAX_WAIT;
        WEIGHTED_ISSUE:if(weighted.cmd_ready) state<=WEIGHTED_WAIT;
        OUTPUT_ISSUE:if(out_project.cmd_ready) state<=OUTPUT_WAIT;
        RESPONSE:if(command.rsp_ready) state<=IDLE;
        QKV_WAIT,SCORE_WAIT,SOFTMAX_WAIT,WEIGHTED_WAIT,OUTPUT_WAIT: ;
        default:begin status_q.protocol_error<=1;state<=RESPONSE;end
      endcase
    end
  end
endmodule
