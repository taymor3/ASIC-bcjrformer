// Shared internal score/weighted row loop; each public wrapper selects its mode.
module row_dot_ctrl #(
  parameter bit WEIGHTED=0,
  parameter longint unsigned TOKENS=0,H=0,D=0,
  parameter logic [31:0] SCORE_SCALE=0
)(input logic clk,rst,bcjr_cmd_if.callee command,bcjr_cmd_if.caller dot,bcjr_mem_if.requester mem);
  import bcjrformer_contract_pkg::*;
  import fixed_math_pkg::*;
  localparam longint unsigned HEAD_DIM=H>0 ? D/H:0;
  localparam longint unsigned ITEMS=WEIGHTED ? HEAD_DIM:TOKENS;
  typedef enum logic [2:0] {IDLE,DOT_ISSUE,DOT_WAIT,WRITE_ISSUE,WRITE_WAIT,RESPONSE} state_t;
  state_t state;
  row_cmd_t row_q,incoming;
  count_t index_q;
  status_t status_q;
  mem_data_t value_q;
  dot_cmd_t descriptor;
  conversion_t converted;
  initial begin
    if(TOKENS==0 || TOKENS>65535 || H==0 || H>65535 || D==0 || D>65535 ||
      D%H!=0 || TOKENS*D>(64'd1<<ADDR_W) || (!WEIGHTED && SCORE_SCALE==0))
      $fatal(1,"row dot requires valid dimensions and score scale");
  end
  always_comb begin
    incoming=row_cmd_t'(command.cmd);
    descriptor='0;
    descriptor.length=count_t'(WEIGHTED ? TOKENS:HEAD_DIM);
    descriptor.mode=WEIGHTED ? DOT_U24_S16:DOT_S16_S16;
    descriptor.a='{bank:WEIGHTED ? BANK_PROB:BANK_Q,
      addr:WEIGHTED ? addr_t'(0):addr_t'(64'(row_q.query_index)*D+64'(row_q.head_index)*HEAD_DIM)};
    descriptor.b='{bank:WEIGHTED ? BANK_VALUE:BANK_KEY,
      addr:WEIGHTED ? addr_t'(64'(row_q.head_index)*HEAD_DIM+64'(index_q)):
        addr_t'(64'(index_q)*D+64'(row_q.head_index)*HEAD_DIM)};
    descriptor.a_stride=1; descriptor.b_stride=addr_t'(WEIGHTED ? D:1);
    converted=WEIGHTED ? convert(wide_t'(accum_t'(dot.rsp)),22,16,1,1):
      convert(wide_t'(accum_t'(dot.rsp))*wide_t'({1'b0,SCORE_SCALE}),30,48,1,0);
    command.cmd_ready=!rst && state==IDLE && !fatal(status_q);
    command.rsp_valid=!rst && state==RESPONSE;command.rsp='0;
    command.rsp_error=fatal(status_q);command.rsp_status=status_q;
    dot.cmd=descriptor;dot.cmd_valid=!rst && state==DOT_ISSUE;dot.rsp_ready=!rst && state==DOT_WAIT;
    mem.req='0;mem.req.write=1;mem.req.bank=WEIGHTED ? BANK_Z:BANK_SCORE;
    mem.req.addr=WEIGHTED ? addr_t'(64'(row_q.query_index)*D+64'(row_q.head_index)*HEAD_DIM+64'(index_q)):addr_t'(index_q);
    mem.req.format=WEIGHTED ? FMT_S16_F10:FMT_S48_F20;mem.req.wdata=value_q;
    mem.req_valid=!rst && state==WRITE_ISSUE;mem.rsp_ready=!rst && state==WRITE_WAIT;
  end
  always_ff @(posedge clk) begin
    if(rst) begin state<=IDLE;row_q<='0;index_q<=0;status_q<='0;value_q<='0;end
    else case(state)
      IDLE:if(command.cmd_valid && command.cmd_ready) begin
        row_q<=incoming;index_q<=0;status_q<='0;
        if(64'(incoming.head_index)>=H || 64'(incoming.query_index)>=TOKENS) begin
          status_q.protocol_error<=1;state<=RESPONSE;end else state<=DOT_ISSUE;
      end
      DOT_ISSUE:if(dot.cmd_ready) state<=DOT_WAIT;
      DOT_WAIT:if(dot.rsp_valid) begin
        status_q<=status_q | child_status(dot.rsp_status,dot.rsp_error) | converted.status;
        if(dot.rsp_error || fatal(dot.rsp_status) || fatal(converted.status)) state<=RESPONSE;
        else begin value_q<=WEIGHTED ? {80'b0,converted.value[15:0]}:{48'b0,converted.value[47:0]};state<=WRITE_ISSUE;end
      end
      WRITE_ISSUE:if(mem.req_ready) state<=WRITE_WAIT;
      WRITE_WAIT:if(mem.rsp_valid) begin
        if(mem.rsp_error) begin status_q.protocol_error<=1;state<=RESPONSE;end
        else if(64'(index_q)==ITEMS-1) state<=RESPONSE;
        else begin index_q<=index_q+1;state<=DOT_ISSUE;end
      end
      RESPONSE:if(command.rsp_ready) state<=IDLE;
      default:begin status_q.protocol_error<=1;state<=RESPONSE;end
    endcase
  end
endmodule
