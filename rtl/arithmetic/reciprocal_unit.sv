// Direct integer divider baseline. Area/timing optimization is a later review task.
module reciprocal_unit(input logic clk,rst,bcjr_arith_if.responder operation);
  import bcjrformer_contract_pkg::*;
  denominator_t denominator;logic [63:0] quotient,remainder;reciprocal_t value;status_t status;
  always_comb begin
    denominator=denominator_t'(operation.req);value=0;status='0;quotient=0;remainder=0;
    if(denominator<(64'd1<<22) || denominator>(64'd65535<<22)) status.numeric_error=1;
    else begin
      quotient=(64'd1<<54)/denominator;remainder=(64'd1<<54)%denominator;
      status.rounded=remainder!=0;
      if((remainder<<1)>denominator || ((remainder<<1)==denominator && quotient[0])) quotient=quotient+1;
      value=reciprocal_t'(quotient);
    end
  end
  arithmetic_register #(.RSP_T(reciprocal_t)) response(clk,rst,operation,value,status);
endmodule
