module mac_unit(input logic clk,rst,bcjr_arith_if.responder operation);
  import bcjrformer_contract_pkg::*;import fixed_math_pkg::*;
  mac_req_t operands;conversion_t result;accum_t value;status_t status;
  always_comb begin
    operands=mac_req_t'(operation.req);
    result=convert(wide_t'(operands.acc)+
      (operands.mode==DOT_U24_S16 ? wide_t'({1'b0,operands.a}):wide_t'(act_t'(operands.a[15:0])))*
      wide_t'(operands.b),0,operands.mode==DOT_U24_S16 ? 64:48,1,0);
    value=accum_t'(result.value);status=result.status;
    if(operands.mode==DOT_S16_S16 && operands.a[23:16]!=0) status.protocol_error=1;
    if(operands.mode==DOT_S16_S16 && operands.acc!=accum_t'(score_t'(operands.acc))) status.numeric_error=1;
  end
  arithmetic_register #(.RSP_T(accum_t)) response(clk,rst,operation,value,status);
endmodule
