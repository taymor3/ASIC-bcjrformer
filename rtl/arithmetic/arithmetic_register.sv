// One accepted operation, one registered held response. No arithmetic placeholder.
module arithmetic_register #(
  parameter type RSP_T=bcjrformer_contract_pkg::act_t
)(input logic clk,rst,bcjr_arith_if.responder operation,
  input RSP_T result,input bcjrformer_contract_pkg::status_t result_status);
  import bcjrformer_contract_pkg::*;
  logic pending;RSP_T result_q;status_t status_q;logic [7:0] tag_q;
  assign operation.req_ready=!rst && !pending;
  assign operation.rsp_valid=!rst && pending;
  assign operation.rsp=result_q;assign operation.rsp_status=status_q;
  assign operation.rsp_error=status_q.protocol_error || status_q.numeric_error;
  assign operation.rsp_tag=tag_q;
  always_ff @(posedge clk) begin
    if(rst) begin pending<=0;result_q<='0;status_q<='0;tag_q<=0;end
    else if(operation.req_valid && operation.req_ready) begin
      pending<=1;result_q<=result;status_q<=result_status;tag_q<=operation.req_tag;
    end else if(operation.rsp_valid && operation.rsp_ready) pending<=0;
  end
endmodule
