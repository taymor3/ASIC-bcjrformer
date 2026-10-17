// Taylor P7(x/32), followed by five squarings. No function-value ROM.
module exp_unit(input logic clk,rst,bcjr_arith_if.responder operation);
  import bcjrformer_contract_pkg::*;import fixed_math_pkg::*;
  typedef enum logic [2:0] {IDLE,HORNER,SQUARE,FINISH,RESPONSE} state_t;
  state_t state;
  localparam logic signed [63:0] COEFFICIENTS[8]='{
    64'sd281474976710656,64'sd281474976710656,64'sd140737488355328,64'sd46912496118443,
    64'sd11728124029611,64'sd2345624805922,64'sd390937467654,64'sd55848209665};
  logic signed [63:0] argument_q,accumulator_q;
  logic [2:0] index_q,squares_q;logic [7:0] tag_q;
  probability_t result_q;status_t status_q;score_t incoming;
  conversion_t product,result;
  always_comb begin
    incoming=score_t'(operation.req);
    product=convert(wide_t'(accumulator_q)*wide_t'(state==SQUARE ? accumulator_q:argument_q),48,64,1,0);
    result=convert(wide_t'(accumulator_q),26,24,0,0);
    operation.req_ready=!rst && state==IDLE;
    operation.rsp_valid=!rst && state==RESPONSE;operation.rsp=result_q;operation.rsp_tag=tag_q;
    operation.rsp_status=status_q;operation.rsp_error=fatal(status_q);
  end
  always_ff @(posedge clk) begin
    if(rst) begin state<=IDLE;argument_q<=0;accumulator_q<=0;index_q<=0;squares_q<=0;
      tag_q<=0;result_q<=0;status_q<='0;end
    else case(state)
      IDLE:if(operation.req_valid && operation.req_ready) begin
        tag_q<=operation.req_tag;status_q<='0;status_q.rounded<=incoming!=0;result_q<=0;
        if(incoming>0) begin status_q<='{numeric_error:1,default:0};state<=RESPONSE;end
        else if(incoming<-(48'sd16<<<20)) state<=RESPONSE;
        else begin
          // Q20 input -> Q48 value of x/32, exactly.
          argument_q<=64'(incoming)<<<23;accumulator_q<=COEFFICIENTS[7];
          index_q<=6;squares_q<=0;state<=HORNER;
        end
      end
      HORNER:if(fatal(product.status)) begin status_q.numeric_error<=1;state<=RESPONSE;end
        else begin accumulator_q<=64'(product.value)+COEFFICIENTS[index_q];
          if(index_q==0) state<=SQUARE;else index_q<=index_q-1;end
      SQUARE:if(fatal(product.status)) begin status_q.numeric_error<=1;state<=RESPONSE;end
        else begin accumulator_q<=64'(product.value);
          if(squares_q==4) state<=FINISH;else squares_q<=squares_q+1;end
      FINISH:begin result_q<=probability_t'(result.value);status_q<=status_q | result.status;state<=RESPONSE;end
      RESPONSE:if(operation.rsp_ready) state<=IDLE;
      default:begin status_q.protocol_error<=1;state<=RESPONSE;end
    endcase
  end
endmodule
