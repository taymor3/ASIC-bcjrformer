module arithmetic_sim_top(input logic clk,rst,req_valid,rsp_ready,
  input logic [2:0] mode,input logic [127:0] req,input logic [7:0] tag,
  output logic req_ready,rsp_valid,rsp_error,output logic [127:0] rsp,
  output logic [7:0] rsp_tag,output bcjrformer_contract_pkg::status_t status);
  import bcjrformer_contract_pkg::*;
  bcjr_arith_if #(mac_req_t,accum_t) mac();
  bcjr_arith_if #(score_t,probability_t) exponential();
  bcjr_arith_if #(denominator_t,reciprocal_t) reciprocal();
  bcjr_arith_if #(variance_t,rsqrt_t) root();
  bcjr_arith_if #(act_t,gelu_t) gelu();
  bcjr_arith_if #(position_add_req_t,act_t) addition();
  mac_unit m(clk,rst,mac);exp_unit e(clk,rst,exponential);reciprocal_unit r(clk,rst,reciprocal);
  rsqrt_unit s(clk,rst,root);gelu_unit g(clk,rst,gelu);position_add_unit a(clk,rst,addition);
  assign mac.req=mac_req_t'(req);assign exponential.req=score_t'(req);assign reciprocal.req=denominator_t'(req);
  assign root.req=variance_t'(req);assign gelu.req=act_t'(req);assign addition.req=position_add_req_t'(req);
  assign mac.req_valid=req_valid && mode==0;assign exponential.req_valid=req_valid && mode==1;
  assign reciprocal.req_valid=req_valid && mode==2;assign root.req_valid=req_valid && mode==3;
  assign gelu.req_valid=req_valid && mode==4;assign addition.req_valid=req_valid && mode==5;
  assign mac.req_tag=tag;assign exponential.req_tag=tag;assign reciprocal.req_tag=tag;
  assign root.req_tag=tag;assign gelu.req_tag=tag;assign addition.req_tag=tag;
  assign mac.rsp_ready=rsp_ready && mode==0;assign exponential.rsp_ready=rsp_ready && mode==1;
  assign reciprocal.rsp_ready=rsp_ready && mode==2;assign root.rsp_ready=rsp_ready && mode==3;
  assign gelu.rsp_ready=rsp_ready && mode==4;assign addition.rsp_ready=rsp_ready && mode==5;
  always_comb begin
    req_ready=0;rsp_valid=0;rsp_error=0;rsp=0;rsp_tag=0;status='0;
    case(mode)
      0:begin req_ready=mac.req_ready;rsp_valid=mac.rsp_valid;rsp_error=mac.rsp_error;
        rsp={64'b0,mac.rsp};rsp_tag=mac.rsp_tag;status=mac.rsp_status;end
      1:begin req_ready=exponential.req_ready;rsp_valid=exponential.rsp_valid;rsp_error=exponential.rsp_error;
        rsp={104'b0,exponential.rsp};rsp_tag=exponential.rsp_tag;status=exponential.rsp_status;end
      2:begin req_ready=reciprocal.req_ready;rsp_valid=reciprocal.rsp_valid;rsp_error=reciprocal.rsp_error;
        rsp={88'b0,reciprocal.rsp};rsp_tag=reciprocal.rsp_tag;status=reciprocal.rsp_status;end
      3:begin req_ready=root.req_ready;rsp_valid=root.rsp_valid;rsp_error=root.rsp_error;
        rsp={96'b0,root.rsp};rsp_tag=root.rsp_tag;status=root.rsp_status;end
      4:begin req_ready=gelu.req_ready;rsp_valid=gelu.rsp_valid;rsp_error=gelu.rsp_error;
        rsp={96'b0,gelu.rsp};rsp_tag=gelu.rsp_tag;status=gelu.rsp_status;end
      5:begin req_ready=addition.req_ready;rsp_valid=addition.rsp_valid;rsp_error=addition.rsp_error;
        rsp={112'b0,addition.rsp};rsp_tag=addition.rsp_tag;status=addition.rsp_status;end
      default:;
    endcase
  end
endmodule
