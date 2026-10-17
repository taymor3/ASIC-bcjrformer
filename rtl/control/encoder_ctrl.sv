// One physical layer service reused K times; bases come from integration manifest.
module encoder_ctrl #(
  parameter longint unsigned K=0,LAYER_STRIDE=0,LAYER_WORDS=0,
  parameter bcjrformer_contract_pkg::addr_t FIRST_LAYER_BASE='0
)(input logic clk,rst,bcjr_cmd_if.callee command,bcjr_cmd_if.caller layer);
  import bcjrformer_contract_pkg::*;
  typedef enum logic [1:0] {IDLE,ISSUE,WAIT_RESPONSE,RESPONSE} state_t;
  state_t state;
  localparam int KW=K>1 ? $clog2(K):1;
  logic [KW-1:0] index_q;
  status_t status_q;
  layer_cmd_t descriptor;
  initial begin
    if(K==0 || K>65535 || LAYER_WORDS==0 || LAYER_STRIDE<LAYER_WORDS ||
       LAYER_STRIDE>(64'd1<<ADDR_W) || LAYER_WORDS>(64'd1<<ADDR_W) ||
       64'(FIRST_LAYER_BASE)+(K-1)*LAYER_STRIDE+LAYER_WORDS>(64'd1<<ADDR_W))
      $fatal(1,"encoder_ctrl requires bounded K and an addressable layer manifest");
  end
  always_comb begin
    descriptor='{layer_index:count_t'(index_q),
      layer_param_base:addr_t'(64'(FIRST_LAYER_BASE)+64'(index_q)*LAYER_STRIDE)};
    command.cmd_ready=!rst && state==IDLE && !status_q.protocol_error && !status_q.numeric_error;
    command.rsp_valid=!rst && state==RESPONSE;
    command.rsp='0;command.rsp_status=status_q;
    command.rsp_error=status_q.protocol_error || status_q.numeric_error;
    layer.cmd=descriptor;layer.cmd_valid=!rst && state==ISSUE;
    layer.rsp_ready=!rst && state==WAIT_RESPONSE;
  end
  always_ff @(posedge clk) begin
    if(rst) begin state<=IDLE;index_q<=0;status_q<='0;end
    else case(state)
      IDLE: if(command.cmd_valid && command.cmd_ready) begin
        index_q<=0;status_q<='0;
        if(command.cmd!='0) begin status_q.protocol_error<=1;state<=RESPONSE;end
        else state<=ISSUE;
      end
      ISSUE: if(layer.cmd_ready) state<=WAIT_RESPONSE;
      WAIT_RESPONSE: if(layer.rsp_valid) begin
        status_q<=status_q | layer.rsp_status;
        if(layer.rsp_error || layer.rsp_status.protocol_error || layer.rsp_status.numeric_error) begin
          if(layer.rsp_error && !layer.rsp_status.protocol_error && !layer.rsp_status.numeric_error)
            status_q.protocol_error<=1;
          state<=RESPONSE;
        end else if(64'(index_q)==K-1) state<=RESPONSE;
        else begin index_q<=index_q+1;state<=ISSUE;end
      end
      RESPONSE: if(command.rsp_ready) state<=IDLE;
      default: begin status_q.protocol_error<=1;state<=RESPONSE;end
    endcase
  end
endmodule
