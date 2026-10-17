module mac_unit(input logic clk,rst,bcjr_arith_if.responder operation);
  import bcjrformer_contract_pkg::*;import fixed_math_pkg::*;
  mac_req_t operands;conversion_t result;accum_t value;status_t status;
  wide_t a_value;
  always_comb begin
    operands=mac_req_t'(operation.req);
    a_value=operands.mode==DOT_U24_S16 ? wide_t'({1'b0,operands.a[23:0]}):
      operands.mode==DOT_S32_S16 ? wide_t'(gelu_t'(operands.a)):
      wide_t'(act_t'(operands.a[15:0]));
    result=convert(wide_t'(operands.acc)+
      a_value*wide_t'(operands.b),0,operands.mode==DOT_S16_S16 ? 48:64,1,0);
    value=accum_t'(result.value);status=result.status;
    if(operands.mode==DOT_S16_S16 && operands.a[31:16]!=0) status.protocol_error=1;
    if(operands.mode==DOT_U24_S16 && operands.a[31:24]!=0) status.protocol_error=1;
    if(operands.mode!=DOT_S16_S16 && operands.mode!=DOT_U24_S16 && operands.mode!=DOT_S32_S16)
      status.protocol_error=1;
    if(operands.mode==DOT_S16_S16 && operands.acc!=accum_t'(score_t'(operands.acc))) status.numeric_error=1;
  end
  arithmetic_register #(.RSP_T(accum_t)) response(clk,rst,operation,value,status);
endmodule
