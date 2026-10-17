// Stage 1 controller. Shared norm/linear services supply the numerical work.
module embedding_ctrl #(
  parameter longint unsigned F=0, D=0, TOKENS=0,
  parameter bcjrformer_contract_pkg::addr_t GAMMA_F_BASE='0, BETA_F_BASE='0,
  parameter bcjrformer_contract_pkg::addr_t WEIGHT_BASE='0, BIAS_BASE='0,
  parameter bcjrformer_contract_pkg::addr_t GAMMA_D_BASE='0, BETA_D_BASE='0
)(
  input logic clk, rst, bcjr_cmd_if.callee command,
  bcjr_cmd_if.caller norm, linear, bcjr_mem_if.requester mem
);
  import bcjrformer_contract_pkg::*;
  typedef enum logic [3:0] {IDLE,READ_ISSUE,READ_WAIT,WRITE_ISSUE,WRITE_WAIT,
    NORM_F_ISSUE,NORM_F_WAIT,LINEAR_ISSUE,LINEAR_WAIT,NORM_D_ISSUE,NORM_D_WAIT,
    RESPONSE} state_t;
  state_t state;
  localparam int TW=TOKENS>1 ? $clog2(TOKENS) : 1;
  localparam longint unsigned WIDTH=F>D ? F:D;
  localparam int IW=WIDTH>1 ? $clog2(WIDTH):1;
  logic [TW-1:0] token_index;
  logic [IW-1:0] element_index;
  logic copy_output;
  act_t word_q;
  status_t status_q;
  layernorm_cmd_t norm_descriptor;
  linear_cmd_t linear_descriptor;
  initial begin
    if(F==0 || D==0 || TOKENS==0 || F>65535 || D>65535 || TOKENS>65535 ||
       F*TOKENS>(64'd1<<ADDR_W) || D*TOKENS>(64'd1<<ADDR_W) ||
       64'(GAMMA_F_BASE)+F>(64'd1<<ADDR_W) || 64'(BETA_F_BASE)+F>(64'd1<<ADDR_W) ||
       64'(WEIGHT_BASE)+D*F>(64'd1<<ADDR_W) || 64'(BIAS_BASE)+D>(64'd1<<ADDR_W) ||
       64'(GAMMA_D_BASE)+D>(64'd1<<ADDR_W) || 64'(BETA_D_BASE)+D>(64'd1<<ADDR_W))
      $fatal(1,"embedding_ctrl requires positive bounded dimensions and addressable manifest bases");
  end
  always_comb begin
    norm_descriptor='{length:count_t'(copy_output ? D:F),
      src:'{bank:copy_output ? BANK_VECTOR:BANK_TOKEN,addr:'0},
      dst:'{bank:copy_output ? BANK_VECTOR:BANK_TOKEN,addr:'0},
      gamma_base:copy_output ? GAMMA_D_BASE:GAMMA_F_BASE,
      beta_base:copy_output ? BETA_D_BASE:BETA_F_BASE};
    linear_descriptor='{in_count:count_t'(F),out_count:count_t'(D),
      src:'{bank:BANK_TOKEN,addr:'0},dst:'{bank:BANK_VECTOR,addr:'0},
      weight_base:WEIGHT_BASE,bias_base:BIAS_BASE};
    command.cmd_ready=!rst && state==IDLE && !status_q.protocol_error && !status_q.numeric_error;
    command.rsp_valid=!rst && state==RESPONSE;
    command.rsp='0; command.rsp_status=status_q;
    command.rsp_error=status_q.protocol_error || status_q.numeric_error;
    norm.cmd=norm_descriptor;
    norm.cmd_valid=!rst && (state==NORM_F_ISSUE || state==NORM_D_ISSUE);
    norm.rsp_ready=!rst && (state==NORM_F_WAIT || state==NORM_D_WAIT);
    linear.cmd=linear_descriptor;
    linear.cmd_valid=!rst && state==LINEAR_ISSUE;
    linear.rsp_ready=!rst && state==LINEAR_WAIT;
    mem.req='0;
    mem.req.format=FMT_S16_F10;
    mem.req_valid=!rst && (state==READ_ISSUE || state==WRITE_ISSUE);
    mem.rsp_ready=!rst && (state==READ_WAIT || state==WRITE_WAIT);
    if(state==WRITE_ISSUE) begin
      mem.req.write=1;
      mem.req.bank=copy_output ? BANK_X:BANK_TOKEN;
      mem.req.addr=addr_t'(copy_output ? 64'(token_index)*D+64'(element_index) : 64'(element_index));
      mem.req.wdata={80'b0,word_q};
    end else begin
      mem.req.bank=copy_output ? BANK_VECTOR:BANK_FEATURE;
      mem.req.addr=addr_t'(copy_output ? 64'(element_index) : 64'(token_index)*F+64'(element_index));
    end
  end
  task automatic protocol_failure;
    begin status_q.protocol_error<=1; state<=RESPONSE; end
  endtask
  always_ff @(posedge clk) begin
    if(rst) begin state<=IDLE; token_index<=0; element_index<=0;
      copy_output<=0; word_q<='0; status_q<='0; end
    else case(state)
      IDLE: if(command.cmd_valid && command.cmd_ready) begin
        token_index<=0; element_index<=0; copy_output<=0; status_q<='0;
        if(command.cmd!='0) protocol_failure(); else state<=READ_ISSUE;
      end
      READ_ISSUE: if(mem.req_ready) state<=READ_WAIT;
      READ_WAIT: if(mem.rsp_valid) begin
        if(mem.rsp_error) protocol_failure();
        else begin word_q<=act_t'(mem.rsp_rdata[15:0]); state<=WRITE_ISSUE; end
      end
      WRITE_ISSUE: if(mem.req_ready) state<=WRITE_WAIT;
      WRITE_WAIT: if(mem.rsp_valid) begin
        if(mem.rsp_error) protocol_failure();
        else if(64'(element_index)==(copy_output ? D:F)-1) begin
          element_index<=0;
          if(!copy_output) state<=NORM_F_ISSUE;
          else if(64'(token_index)==TOKENS-1) state<=RESPONSE;
          else begin token_index<=token_index+1; copy_output<=0; state<=READ_ISSUE; end
        end else begin element_index<=element_index+1; state<=READ_ISSUE; end
      end
      NORM_F_ISSUE: if(norm.cmd_ready) state<=NORM_F_WAIT;
      NORM_D_ISSUE: if(norm.cmd_ready) state<=NORM_D_WAIT;
      NORM_F_WAIT,NORM_D_WAIT: if(norm.rsp_valid) begin
        status_q<=status_q | norm.rsp_status;
        if(norm.rsp_error || norm.rsp_status.protocol_error || norm.rsp_status.numeric_error) begin
          if(norm.rsp_error && !norm.rsp_status.protocol_error && !norm.rsp_status.numeric_error)
            status_q.protocol_error<=1;
          state<=RESPONSE;
        end else if(state==NORM_F_WAIT) state<=LINEAR_ISSUE;
        else begin element_index<=0; state<=READ_ISSUE; end
      end
      LINEAR_ISSUE: if(linear.cmd_ready) state<=LINEAR_WAIT;
      LINEAR_WAIT: if(linear.rsp_valid) begin
        status_q<=status_q | linear.rsp_status;
        if(linear.rsp_error || linear.rsp_status.protocol_error || linear.rsp_status.numeric_error) begin
          if(linear.rsp_error && !linear.rsp_status.protocol_error && !linear.rsp_status.numeric_error)
            status_q.protocol_error<=1;
          state<=RESPONSE;
        end else begin copy_output<=1; state<=NORM_D_ISSUE; end
      end
      RESPONSE: if(command.rsp_ready) state<=IDLE;
      default: protocol_failure();
    endcase
  end
endmodule
