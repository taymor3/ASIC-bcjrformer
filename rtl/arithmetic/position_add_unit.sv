module position_add_unit(input logic clk,rst,bcjr_arith_if.responder operation);
  import bcjrformer_contract_pkg::*;import fixed_math_pkg::*;
  position_add_req_t operands;conversion_t result;act_t value;
  always_comb begin
    operands=position_add_req_t'(operation.req);
    result=convert(wide_t'(operands.left)+wide_t'(operands.right),0,16,1,1);
    value=act_t'(result.value);
  end
  arithmetic_register #(.RSP_T(act_t)) response(clk,rst,operation,value,result.status);
endmodule
