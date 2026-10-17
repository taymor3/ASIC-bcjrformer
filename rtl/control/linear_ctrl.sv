module linear_ctrl(input logic clk,rst,bcjr_cmd_if.callee command,bcjr_cmd_if.caller dot,bcjr_mem_if.requester mem);
  import bcjrformer_contract_pkg::*;import fixed_math_pkg::*;
  typedef enum logic [3:0] {IDLE,BIAS_ISSUE,BIAS_WAIT,DOT_ISSUE,DOT_WAIT,WRITE_ISSUE,WRITE_WAIT,RESPONSE} state_t;
  state_t state;linear_cmd_t descriptor_q,incoming;dot_cmd_t dot_descriptor;
  count_t output_q;act_t bias_q,value_q;status_t status_q;conversion_t converted;
  addr_t weight_address_q;
  always_comb begin
    incoming=linear_cmd_t'(command.cmd);
    dot_descriptor='{length:descriptor_q.in_count,a:descriptor_q.src,a_stride:1,
      b:'{bank:BANK_PARAM,addr:weight_address_q},
      b_stride:1,mode:DOT_S16_S16,acc_init:accum_t'(bias_q)<<<10};
    converted=convert(wide_t'(accum_t'(dot.rsp)),10,16,1,1);
    command.cmd_ready=!rst && state==IDLE && !fatal(status_q);
    command.rsp_valid=!rst && state==RESPONSE;command.rsp='0;
    command.rsp_status=status_q;command.rsp_error=fatal(status_q);
    dot.cmd=dot_descriptor;dot.cmd_valid=!rst && state==DOT_ISSUE;dot.rsp_ready=!rst && state==DOT_WAIT;
    mem.req='0;mem.req.format=FMT_S16_F10;
    mem.req.bank=state==BIAS_ISSUE ? BANK_PARAM:descriptor_q.dst.bank;
    mem.req.addr=state==BIAS_ISSUE ? addr_t'(64'(descriptor_q.bias_base)+64'(output_q)):
      addr_t'(64'(descriptor_q.dst.addr)+64'(output_q));
    mem.req.write=state==WRITE_ISSUE;mem.req.wdata={80'b0,value_q};
    mem.req_valid=!rst && (state==BIAS_ISSUE || state==WRITE_ISSUE);
    mem.rsp_ready=!rst && (state==BIAS_WAIT || state==WRITE_WAIT);
  end
  always_ff @(posedge clk) begin
    if(rst) begin state<=IDLE;descriptor_q<='0;output_q<=0;weight_address_q<=0;bias_q<=0;value_q<=0;status_q<='0;end
    else case(state)
      IDLE:if(command.cmd_valid && command.cmd_ready) begin
        descriptor_q<=incoming;output_q<=0;weight_address_q<=incoming.weight_base;status_q<='0;
        if(!act_bank(incoming.src.bank) || !act_destination(incoming.dst.bank) ||
          !extent(incoming.src.addr,64'(incoming.in_count)) || !extent(incoming.dst.addr,64'(incoming.out_count)) ||
          !extent(incoming.weight_base,64'(incoming.in_count)*64'(incoming.out_count)) ||
          !extent(incoming.bias_base,64'(incoming.out_count)) ||
          overlap(incoming.src,64'(incoming.in_count),incoming.dst,64'(incoming.out_count))) begin
          status_q.protocol_error<=1;state<=RESPONSE;end else state<=BIAS_ISSUE;
      end
      BIAS_ISSUE:if(mem.req_ready) state<=BIAS_WAIT;
      BIAS_WAIT:if(mem.rsp_valid) begin
        if(mem.rsp_error) begin status_q.protocol_error<=1;state<=RESPONSE;end
        else begin bias_q<=act_t'(mem.rsp_rdata[15:0]);state<=DOT_ISSUE;end
      end
      DOT_ISSUE:if(dot.cmd_ready) state<=DOT_WAIT;
      DOT_WAIT:if(dot.rsp_valid) begin
        status_q<=status_q | child_status(dot.rsp_status,dot.rsp_error) | converted.status;
        if(dot.rsp_error || fatal(dot.rsp_status) || fatal(converted.status)) state<=RESPONSE;
        else begin value_q<=act_t'(converted.value);state<=WRITE_ISSUE;end
      end
      WRITE_ISSUE:if(mem.req_ready) state<=WRITE_WAIT;
      WRITE_WAIT:if(mem.rsp_valid) begin
        if(mem.rsp_error) begin status_q.protocol_error<=1;state<=RESPONSE;end
        else if(output_q==descriptor_q.out_count-1) state<=RESPONSE;
        else begin output_q<=output_q+1;weight_address_q<=weight_address_q+addr_t'(descriptor_q.in_count);state<=BIAS_ISSUE;end
      end
      RESPONSE:if(command.rsp_ready) state<=IDLE;
      default:begin status_q.protocol_error<=1;state<=RESPONSE;end
    endcase
  end
endmodule
