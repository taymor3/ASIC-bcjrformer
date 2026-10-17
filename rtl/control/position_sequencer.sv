// Internal Stage 2 control helper. The local add/convert datapath is not supplied
// here: its requester boundary permits control verification with test models.
module position_sequencer #(
  parameter longint unsigned M=0,N=0,D=0,
  parameter bcjrformer_contract_pkg::addr_t POSITION_BASE='0, READ_BASE='0
)(input logic clk,rst,bcjr_cmd_if.callee command,
  bcjr_mem_if.requester mem,bcjr_arith_if.requester addition);
  import bcjrformer_contract_pkg::*;
  typedef enum logic [4:0] {IDLE,X_ISSUE,X_WAIT,P_ISSUE,P_WAIT,ADD_P_ISSUE,ADD_P_WAIT,
    E_ISSUE,E_WAIT,ADD_E_ISSUE,ADD_E_WAIT,WRITE_ISSUE,WRITE_WAIT,RESPONSE} state_t;
  state_t state;
  localparam int MW=M>1 ? $clog2(M):1;
  localparam int NW=N>1 ? $clog2(N):1;
  localparam int DW=D>1 ? $clog2(D):1;
  logic [MW-1:0] m_index;
  logic [NW-1:0] n_index;
  logic [DW-1:0] d_index;
  act_t value_q,parameter_q;
  status_t status_q;
  position_add_req_t add_request;
  initial begin
    if(M==0 || N==0 || D==0 || M>65535 || N>65535 || D>65535 || M*N>65535 ||
       M*N*D>(64'd1<<ADDR_W) || 64'(POSITION_BASE)+N*D>(64'd1<<ADDR_W) ||
       64'(READ_BASE)+M*D>(64'd1<<ADDR_W))
      $fatal(1,"position_sequencer requires bounded dimensions and addressable manifest bases");
  end
  always_comb begin
    command.cmd_ready=!rst && state==IDLE && !status_q.protocol_error && !status_q.numeric_error;
    command.rsp_valid=!rst && state==RESPONSE;
    command.rsp='0; command.rsp_status=status_q;
    command.rsp_error=status_q.protocol_error || status_q.numeric_error;
    mem.req='0; mem.req.format=FMT_S16_F10;
    mem.req.bank=BANK_X;
    mem.req.addr=addr_t'((64'(m_index)*N+64'(n_index))*D+64'(d_index));
    if(state==P_ISSUE) begin mem.req.bank=BANK_PARAM;
      mem.req.addr=addr_t'(64'(POSITION_BASE)+64'(n_index)*D+64'(d_index)); end
    if(state==E_ISSUE) begin mem.req.bank=BANK_PARAM;
      mem.req.addr=addr_t'(64'(READ_BASE)+64'(m_index)*D+64'(d_index)); end
    if(state==WRITE_ISSUE) begin mem.req.write=1; mem.req.wdata={80'b0,value_q}; end
    mem.req_valid=!rst && (state==X_ISSUE || state==P_ISSUE || state==E_ISSUE || state==WRITE_ISSUE);
    mem.rsp_ready=!rst && (state==X_WAIT || state==P_WAIT || state==E_WAIT || state==WRITE_WAIT);
    add_request='{left:value_q,right:parameter_q};
    addition.req=add_request; addition.req_tag='0;
    addition.req_valid=!rst && (state==ADD_P_ISSUE || state==ADD_E_ISSUE);
    addition.rsp_ready=!rst && (state==ADD_P_WAIT || state==ADD_E_WAIT);
  end
  task automatic protocol_failure;
    begin status_q.protocol_error<=1; state<=RESPONSE; end
  endtask
  always_ff @(posedge clk) begin
    if(rst) begin state<=IDLE; m_index<=0; n_index<=0; d_index<=0;
      value_q<='0; parameter_q<='0; status_q<='0; end
    else case(state)
      IDLE: if(command.cmd_valid && command.cmd_ready) begin
        m_index<=0; n_index<=0; d_index<=0; status_q<='0;
        if(command.cmd!='0) protocol_failure(); else state<=X_ISSUE;
      end
      X_ISSUE: if(mem.req_ready) state<=X_WAIT;
      P_ISSUE: if(mem.req_ready) state<=P_WAIT;
      E_ISSUE: if(mem.req_ready) state<=E_WAIT;
      X_WAIT,P_WAIT,E_WAIT: if(mem.rsp_valid) begin
        if(mem.rsp_error) protocol_failure();
        else case(state)
          X_WAIT: begin value_q<=act_t'(mem.rsp_rdata[15:0]); state<=P_ISSUE; end
          P_WAIT: begin parameter_q<=act_t'(mem.rsp_rdata[15:0]); state<=ADD_P_ISSUE; end
          E_WAIT: begin parameter_q<=act_t'(mem.rsp_rdata[15:0]); state<=ADD_E_ISSUE; end
          default: protocol_failure();
        endcase
      end
      ADD_P_ISSUE: if(addition.req_ready) state<=ADD_P_WAIT;
      ADD_E_ISSUE: if(addition.req_ready) state<=ADD_E_WAIT;
      ADD_P_WAIT,ADD_E_WAIT: if(addition.rsp_valid) begin
        status_q<=status_q | addition.rsp_status;
        if(addition.rsp_error || addition.rsp_status.protocol_error ||
           addition.rsp_status.numeric_error || addition.rsp_tag!=0) begin
          if(addition.rsp_tag!=0 || (addition.rsp_error &&
             !addition.rsp_status.protocol_error && !addition.rsp_status.numeric_error))
            status_q.protocol_error<=1;
          state<=RESPONSE;
        end else begin value_q<=act_t'(addition.rsp);
          state<=state==ADD_P_WAIT ? E_ISSUE:WRITE_ISSUE; end
      end
      WRITE_ISSUE: if(mem.req_ready) state<=WRITE_WAIT;
      WRITE_WAIT: if(mem.rsp_valid) begin
        if(mem.rsp_error) protocol_failure();
        else if(64'(d_index)<D-1) begin d_index<=d_index+1; state<=X_ISSUE; end
        else if(64'(n_index)<N-1) begin d_index<=0; n_index<=n_index+1; state<=X_ISSUE; end
        else if(64'(m_index)<M-1) begin d_index<=0; n_index<=0; m_index<=m_index+1; state<=X_ISSUE; end
        else state<=RESPONSE;
      end
      RESPONSE: if(command.rsp_ready) state<=IDLE;
      default: protocol_failure();
    endcase
  end
endmodule
