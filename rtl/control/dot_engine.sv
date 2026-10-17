module dot_engine(input logic clk,rst,bcjr_cmd_if.callee command,
  bcjr_mem_if.requester mem,bcjr_arith_if.requester mac);
  import bcjrformer_contract_pkg::*;import fixed_math_pkg::*;
  typedef enum logic [3:0] {IDLE,A_ISSUE,A_WAIT,B_ISSUE,B_WAIT,MAC_ISSUE,MAC_WAIT,RESPONSE} state_t;
  state_t state;
  dot_cmd_t descriptor_q,incoming;
  count_t term_q;
  addr_t a_address_q,b_address_q;
  logic [23:0] a_q;
  act_t b_q;
  accum_t accumulator_q;
  status_t status_q;
  mac_req_t mac_request;
  always_comb begin
    incoming=dot_cmd_t'(command.cmd);
    command.cmd_ready=!rst && state==IDLE && !fatal(status_q);
    command.rsp_valid=!rst && state==RESPONSE;command.rsp=accumulator_q;
    command.rsp_status=status_q;command.rsp_error=fatal(status_q);
    mem.req='0;mem.req.bank=state==B_ISSUE ? descriptor_q.b.bank:descriptor_q.a.bank;
    mem.req.addr=state==B_ISSUE ? b_address_q:a_address_q;
    mem.req.format=state==A_ISSUE && descriptor_q.mode==DOT_U24_S16 ? FMT_U24_F22:FMT_S16_F10;
    mem.req_valid=!rst && (state==A_ISSUE || state==B_ISSUE);
    mem.rsp_ready=!rst && (state==A_WAIT || state==B_WAIT);
    mac_request='{mode:descriptor_q.mode,a:a_q,b:b_q,acc:accumulator_q};
    mac.req=mac_request;mac.req_tag=0;mac.req_valid=!rst && state==MAC_ISSUE;
    mac.rsp_ready=!rst && state==MAC_WAIT;
  end
  always_ff @(posedge clk) begin
    if(rst) begin state<=IDLE;descriptor_q<='0;term_q<=0;a_address_q<=0;b_address_q<=0;
      a_q<=0;b_q<=0;accumulator_q<=0;status_q<='0;end
    else case(state)
      IDLE:if(command.cmd_valid && command.cmd_ready) begin
        descriptor_q<=incoming;term_q<=0;a_address_q<=incoming.a.addr;b_address_q<=incoming.b.addr;
        accumulator_q<=incoming.acc_init;status_q<='0;
        if(incoming.length==0 || !act_bank(incoming.b.bank) ||
          (incoming.mode==DOT_U24_S16 ? incoming.a.bank!=BANK_PROB:!act_bank(incoming.a.bank)) ||
          !extent(incoming.a.addr,64'(incoming.length-1)*64'(incoming.a_stride)+1) ||
          !extent(incoming.b.addr,64'(incoming.length-1)*64'(incoming.b_stride)+1)) begin
          status_q.protocol_error<=1;state<=RESPONSE;end
        else if(incoming.mode==DOT_S16_S16 &&
          incoming.acc_init!=accum_t'(score_t'(incoming.acc_init))) begin status_q.numeric_error<=1;state<=RESPONSE;end
        else state<=A_ISSUE;
      end
      A_ISSUE:if(mem.req_ready) state<=A_WAIT;
      B_ISSUE:if(mem.req_ready) state<=B_WAIT;
      A_WAIT,B_WAIT:if(mem.rsp_valid) begin
        if(mem.rsp_error) begin status_q.protocol_error<=1;state<=RESPONSE;end
        else if(state==A_WAIT) begin a_q<=descriptor_q.mode==DOT_U24_S16 ? mem.rsp_rdata[23:0]:{8'b0,mem.rsp_rdata[15:0]};state<=B_ISSUE;end
        else begin b_q<=act_t'(mem.rsp_rdata[15:0]);state<=MAC_ISSUE;end
      end
      MAC_ISSUE:if(mac.req_ready) state<=MAC_WAIT;
      MAC_WAIT:if(mac.rsp_valid) begin
        status_q<=status_q | child_status(mac.rsp_status,mac.rsp_error,mac.rsp_tag!=0);
        if(mac.rsp_error || fatal(mac.rsp_status) || mac.rsp_tag!=0) state<=RESPONSE;
        else begin accumulator_q<=accum_t'(mac.rsp);
          if(term_q==descriptor_q.length-1) state<=RESPONSE;
          else begin term_q<=term_q+1;
            a_address_q<=a_address_q+descriptor_q.a_stride;
            b_address_q<=b_address_q+descriptor_q.b_stride;state<=A_ISSUE;end
        end
      end
      RESPONSE:if(command.rsp_ready) state<=IDLE;
      default:begin status_q.protocol_error<=1;state<=RESPONSE;end
    endcase
  end
endmodule
