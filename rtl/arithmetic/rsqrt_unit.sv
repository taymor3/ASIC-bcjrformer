// Integer reciprocal square root, rounded against the exact midpoint inequality.
module rsqrt_unit #(parameter bcjrformer_contract_pkg::variance_t MINIMUM=bcjrformer_contract_pkg::NORMALIZATION_MINIMUM)(
  input logic clk,rst,bcjr_arith_if.responder operation);
  import bcjrformer_contract_pkg::*;import fixed_math_pkg::*;
  variance_t variance;logic [95:0] quotient;logic [47:0] root,candidate;
  wide_t midpoint;rsqrt_t value;status_t status;
  always_comb begin
    variance=variance_t'(operation.req);quotient=0;root=0;candidate=0;midpoint=0;value=0;status='0;
    if(variance<MINIMUM || variance==0 || variance>(48'd4096<<32)) status.numeric_error=1;
    else begin
      quotient=(96'd1<<72)/96'(variance);
      for(int bit_index=47;bit_index>=0;bit_index--) begin
        candidate=root | (48'd1<<bit_index);
        if(96'(candidate)*96'(candidate)<=quotient) root=candidate;
      end
      midpoint=wide_t'({1'b0,variance})*(2*wide_t'({1'b0,root})+1)*(2*wide_t'({1'b0,root})+1);
      status.rounded=wide_t'({1'b0,variance})*wide_t'({1'b0,root})*wide_t'({1'b0,root})!=(160'sd1<<72);
      if(midpoint<(160'sd1<<74) || (midpoint==(160'sd1<<74) && root[0])) root=root+1;
      if(root>48'hffffffff) status.numeric_error=1;else value=rsqrt_t'(root);
    end
  end
  initial if(MINIMUM!=NORMALIZATION_MINIMUM)
    $fatal(1,"RSQRT minimum must match the shared normalization domain");
  arithmetic_register #(.RSP_T(rsqrt_t)) response(clk,rst,operation,value,status);
endmodule
