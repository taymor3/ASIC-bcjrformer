// Maclaurin x*Phi(x), k=0..57 (degree 116), |x|<=6; bounded tails outside.
// Q64 recurrence avoids coefficient underflow and cancellation loss. No ROM.
module gelu_unit(input logic clk,rst,bcjr_arith_if.responder operation);
  import bcjrformer_contract_pkg::*;import fixed_math_pkg::*;
  typedef enum logic [2:0] {IDLE,INITIALIZE,TERM,FINISH,RESPONSE} state_t;
  state_t state;
  localparam logic [63:0] PHI_ZERO_Q64=64'd7359186146747302452;
  act_t input_q,incoming;logic [31:0] square_q;logic [6:0] index_q;
  logic signed [127:0] term_q,sum_q;
  logic [7:0] tag_q;gelu_t result_q;status_t status_q;
  wide_t numerator,denominator,next_term,next_sum,initial_term;
  conversion_t result;
  function automatic wide_t divide_nearest(wide_t n,wide_t d);
    wide_t magnitude,quotient,remainder;
    magnitude=n<0 ? -n:n;quotient=magnitude/d;remainder=magnitude%d;
    if(2*remainder>d || (2*remainder==d && quotient[0])) quotient=quotient+1;
    return n<0 ? -quotient:quotient;
  endfunction
  always_comb begin
    incoming=act_t'(operation.req);
    initial_term=divide_nearest(wide_t'({1'b0,PHI_ZERO_Q64})*wide_t'({1'b0,square_q}),160'sd1<<20);
    numerator=-wide_t'(term_q)*wide_t'({1'b0,square_q})*wide_t'(2*64'(index_q)-1);
    denominator=wide_t'(2*64'(index_q)*(2*64'(index_q)+1))<<<20;
    next_term=divide_nearest(numerator,denominator==0 ? 160'sd1:denominator);
    next_sum=wide_t'(sum_q)+next_term;
    result=convert(wide_t'(sum_q)+(wide_t'(input_q)<<<53),42,32,1,0);
    operation.req_ready=!rst && state==IDLE;
    operation.rsp_valid=!rst && state==RESPONSE;operation.rsp=result_q;operation.rsp_tag=tag_q;
    operation.rsp_status=status_q;operation.rsp_error=fatal(status_q);
  end
  always_ff @(posedge clk) begin
    if(rst) begin state<=IDLE;input_q<=0;square_q<=0;index_q<=0;term_q<=0;sum_q<=0;
      tag_q<=0;result_q<=0;status_q<='0;end
    else case(state)
      IDLE:if(operation.req_valid && operation.req_ready) begin
        input_q<=incoming;tag_q<=operation.req_tag;status_q<='0;status_q.rounded<=incoming!=0;
        if(incoming>6144) begin result_q<=gelu_t'(incoming)<<<12;state<=RESPONSE;end
        else if(incoming< -6144) begin result_q<=0;state<=RESPONSE;end
        else begin square_q<=32'(incoming)*32'(incoming);state<=INITIALIZE;end
      end
      INITIALIZE:begin term_q<=128'(initial_term);sum_q<=128'(initial_term);index_q<=1;state<=TERM;end
      TERM:if(next_term>=(160'sd1<<127) || next_term<-(160'sd1<<127) ||
          next_sum>=(160'sd1<<127) || next_sum<-(160'sd1<<127)) begin
        status_q.numeric_error<=1;result_q<=0;state<=RESPONSE;
      end else begin term_q<=128'(next_term);sum_q<=128'(next_sum);
        if(index_q==57) state<=FINISH;else index_q<=index_q+1;end
      FINISH:begin result_q<=gelu_t'(result.value);status_q<=status_q | result.status;state<=RESPONSE;end
      RESPONSE:if(operation.rsp_ready) state<=IDLE;
      default:begin status_q.protocol_error<=1;state<=RESPONSE;end
    endcase
  end
endmodule
