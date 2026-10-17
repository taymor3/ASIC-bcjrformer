module layernorm_ctrl #(parameter bcjrformer_contract_pkg::variance_t EPSILON=bcjrformer_contract_pkg::NORMALIZATION_MINIMUM)(
  input logic clk,rst,bcjr_cmd_if.callee command,bcjr_mem_if.requester mem,bcjr_arith_if.requester rsqrt);
  import bcjrformer_contract_pkg::*;import fixed_math_pkg::*;
  typedef enum logic [3:0] {IDLE,SUM_ISSUE,SUM_WAIT,MEAN,SQUARE_ISSUE,SQUARE_WAIT,VARIANCE,
    RSQRT_ISSUE,RSQRT_WAIT,VALUE_ISSUE,VALUE_WAIT,GAMMA_ISSUE,GAMMA_WAIT,BETA_ISSUE,BETA_WAIT,WRITE_RESULT} state_t;
  // Write/response are separate states in a wider enum to keep committed-write barriers explicit.
  typedef enum logic [1:0] {CALCULATE,WRITE_ISSUE,WRITE_WAIT,RESPONSE} finish_t;
  state_t state;finish_t finish_state;
  layernorm_cmd_t descriptor_q,incoming;count_t index_q;
  logic signed [47:0] sum_q;logic signed [31:0] mean_q,normalized_q;
  logic [95:0] squares_q;variance_t variance_q;rsqrt_t scale_q;
  act_t gamma_q,value_q;status_t status_q;
  wide_t centered,square_sum,affine;
  conversion_t mean_value,var_value,norm_value,act_value,sum_value;
  // Divide the full numerator once. A rounded reciprocal of length biases the
  // mean even for constant rows; RSQRT amplifies that error near epsilon.
  function automatic conversion_t divide_rne(wide_t numerator,logic [63:0] denominator,
    int width,bit signed_output);
    wide_t magnitude,divisor,quotient,remainder;
    conversion_t result;
    result='0; magnitude=numerator<0 ? -numerator:numerator;
    divisor=wide_t'({1'b0,denominator});quotient=0;remainder=0;
    if(denominator==0) result.status.protocol_error=1;
    else begin
      quotient=magnitude/divisor;remainder=magnitude%divisor;
      if(2*remainder>divisor || (2*remainder==divisor && quotient[0])) quotient=quotient+1;
      result=convert(numerator<0 ? -quotient:quotient,0,width,signed_output,0);
      result.status.rounded=remainder!=0;
    end
    return result;
  endfunction
  initial if(EPSILON<NORMALIZATION_MINIMUM || EPSILON>(48'd4096<<32)) $fatal(1,"invalid LayerNorm epsilon");
  always_comb begin
    incoming=layernorm_cmd_t'(command.cmd);
    centered=(wide_t'(act_t'(mem.rsp_rdata[15:0]))<<<10)-wide_t'(mean_q);
    square_sum=wide_t'({1'b0,squares_q})+centered*centered;
    sum_value=convert(wide_t'(sum_q)+wide_t'(act_t'(mem.rsp_rdata[15:0])),0,48,1,0);
    mean_value=divide_rne(wide_t'(sum_q)<<<10,64'(descriptor_q.length),32,1);
    var_value=divide_rne(wide_t'({1'b0,squares_q}),64'(descriptor_q.length)<<8,48,0);
    norm_value=convert(centered*wide_t'({1'b0,scale_q}),20,32,1,0);
    affine=wide_t'(normalized_q)*wide_t'(gamma_q)+(wide_t'(act_t'(mem.rsp_rdata[15:0]))<<<20);
    act_value=convert(affine,20,16,1,1);
    command.cmd_ready=!rst && finish_state==CALCULATE && state==IDLE && !fatal(status_q);
    command.rsp_valid=!rst && finish_state==RESPONSE;command.rsp='0;
    command.rsp_error=fatal(status_q);command.rsp_status=status_q;
    mem.req='0;mem.req.format=FMT_S16_F10;mem.req.bank=descriptor_q.src.bank;
    mem.req.addr=addr_t'(64'(descriptor_q.src.addr)+64'(index_q));
    if(state==GAMMA_ISSUE) begin mem.req.bank=BANK_PARAM;mem.req.addr=addr_t'(64'(descriptor_q.gamma_base)+64'(index_q));end
    if(state==BETA_ISSUE) begin mem.req.bank=BANK_PARAM;mem.req.addr=addr_t'(64'(descriptor_q.beta_base)+64'(index_q));end
    if(finish_state==WRITE_ISSUE) begin mem.req.bank=descriptor_q.dst.bank;
      mem.req.addr=addr_t'(64'(descriptor_q.dst.addr)+64'(index_q));mem.req.write=1;mem.req.wdata={80'b0,value_q};end
    mem.req_valid=!rst && (finish_state==WRITE_ISSUE || (finish_state==CALCULATE &&
      (state==SUM_ISSUE || state==SQUARE_ISSUE || state==VALUE_ISSUE || state==GAMMA_ISSUE || state==BETA_ISSUE)));
    mem.rsp_ready=!rst && (finish_state==WRITE_WAIT || (finish_state==CALCULATE &&
      (state==SUM_WAIT || state==SQUARE_WAIT || state==VALUE_WAIT || state==GAMMA_WAIT || state==BETA_WAIT)));
    rsqrt.req=variance_q;rsqrt.req_tag=0;
    rsqrt.req_valid=!rst && finish_state==CALCULATE && state==RSQRT_ISSUE;
    rsqrt.rsp_ready=!rst && finish_state==CALCULATE && state==RSQRT_WAIT;
  end
  task automatic fail(bit protocol_fault);begin
    if(protocol_fault) status_q.protocol_error<=1;else status_q.numeric_error<=1;
    finish_state<=RESPONSE;
  end endtask
  always_ff @(posedge clk) begin
    if(rst) begin state<=IDLE;finish_state<=CALCULATE;descriptor_q<='0;index_q<=0;sum_q<=0;mean_q<=0;
      normalized_q<=0;squares_q<=0;variance_q<=0;scale_q<=0;gamma_q<=0;value_q<=0;status_q<='0;end
    else if(finish_state==RESPONSE) begin if(command.rsp_ready) begin finish_state<=CALCULATE;state<=IDLE;end end
    else if(finish_state==WRITE_ISSUE) begin if(mem.req_ready) finish_state<=WRITE_WAIT;end
    else if(finish_state==WRITE_WAIT) begin if(mem.rsp_valid) begin
      if(mem.rsp_error) fail(1);
      else if(index_q==descriptor_q.length-1) finish_state<=RESPONSE;
      else begin index_q<=index_q+1;finish_state<=CALCULATE;state<=VALUE_ISSUE;end
    end end
    else case(state)
      IDLE:if(command.cmd_valid && command.cmd_ready) begin
        descriptor_q<=incoming;index_q<=0;sum_q<=0;squares_q<=0;status_q<='0;
        if(!act_bank(incoming.src.bank) || !act_destination(incoming.dst.bank) ||
          !extent(incoming.src.addr,64'(incoming.length)) || !extent(incoming.dst.addr,64'(incoming.length)) ||
          !extent(incoming.gamma_base,64'(incoming.length)) || !extent(incoming.beta_base,64'(incoming.length)) ||
          (overlap(incoming.src,64'(incoming.length),incoming.dst,64'(incoming.length)) && incoming.src!=incoming.dst)) fail(1);
        else state<=SUM_ISSUE;
      end
      SUM_ISSUE:if(mem.req_ready) state<=SUM_WAIT;
      SUM_WAIT:if(mem.rsp_valid) begin
        if(mem.rsp_error) fail(1);else if(fatal(sum_value.status)) fail(0);
        else begin sum_q<=48'(sum_value.value);
          if(index_q==descriptor_q.length-1) state<=MEAN;
          else begin index_q<=index_q+1;state<=SUM_ISSUE;end
        end
      end
      MEAN:begin
        status_q<=status_q | mean_value.status;
        if(fatal(mean_value.status)) fail(0);
        else begin mean_q<=32'(mean_value.value);index_q<=0;state<=SQUARE_ISSUE;end
      end
      SQUARE_ISSUE:if(mem.req_ready) state<=SQUARE_WAIT;
      SQUARE_WAIT:if(mem.rsp_valid) begin
        if(mem.rsp_error) fail(1);else if(square_sum>=(160'sd1<<<96)) fail(0);
        else begin squares_q<=96'(square_sum);
          if(index_q==descriptor_q.length-1) state<=VARIANCE;
          else begin index_q<=index_q+1;state<=SQUARE_ISSUE;end
        end
      end
      VARIANCE:begin
        status_q<=status_q | var_value.status;
        if(fatal(var_value.status) || var_value.value+wide_t'({1'b0,EPSILON})>wide_t'(48'd4096<<32)) fail(0);
        else begin variance_q<=variance_t'(var_value.value+wide_t'({1'b0,EPSILON}));state<=RSQRT_ISSUE;end
      end
      RSQRT_ISSUE:if(rsqrt.req_ready) state<=RSQRT_WAIT;
      RSQRT_WAIT:if(rsqrt.rsp_valid) begin
        status_q<=status_q | child_status(rsqrt.rsp_status,rsqrt.rsp_error,rsqrt.rsp_tag!=0);
        if(rsqrt.rsp_error || fatal(rsqrt.rsp_status) || rsqrt.rsp_tag!=0) finish_state<=RESPONSE;
        else if(rsqrt.rsp==0) fail(0);
        else begin scale_q<=rsqrt_t'(rsqrt.rsp);index_q<=0;state<=VALUE_ISSUE;end
      end
      VALUE_ISSUE:if(mem.req_ready) state<=VALUE_WAIT;
      VALUE_WAIT:if(mem.rsp_valid) begin
        if(mem.rsp_error) fail(1);else begin status_q<=status_q | norm_value.status;
          if(fatal(norm_value.status)) fail(0);else begin normalized_q<=32'(norm_value.value);state<=GAMMA_ISSUE;end
        end
      end
      GAMMA_ISSUE:if(mem.req_ready) state<=GAMMA_WAIT;
      GAMMA_WAIT:if(mem.rsp_valid) begin
        if(mem.rsp_error) fail(1);else begin gamma_q<=act_t'(mem.rsp_rdata[15:0]);state<=BETA_ISSUE;end
      end
      BETA_ISSUE:if(mem.req_ready) state<=BETA_WAIT;
      BETA_WAIT:if(mem.rsp_valid) begin
        if(mem.rsp_error) fail(1);else begin value_q<=act_t'(act_value.value);status_q<=status_q | act_value.status;
          finish_state<=WRITE_ISSUE;state<=WRITE_RESULT;end
      end
      default:fail(1);
    endcase
  end
endmodule
