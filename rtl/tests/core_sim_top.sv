// Flat host boundary for cycle simulation of the actual integrated RTL.
module core_sim_top #(parameter longint unsigned F=2,M=2,N=2,D=2,H=1,K=2)(
  input logic clk,rst,param_valid,param_rsp_ready,parameter_commit,frame_valid,
    feature_valid,feature_last,mask_valid,mask_bit,mask_last,logit_ready,completion_ready,
  input bcjrformer_contract_pkg::addr_t param_addr,
  input bcjrformer_contract_pkg::act_t param_data,feature_data,
  output logic param_ready,param_rsp_valid,param_rsp_error,frame_ready,feature_ready,mask_ready,
    logit_valid,logit_last,completion_valid,completion_error,busy,
  output bcjrformer_contract_pkg::act_t logit_data,
  output logic [15:0] logit_index,completion_position,
  output bcjrformer_contract_pkg::completion_code_t completion_code,
  output bcjrformer_contract_pkg::status_t status,
  output logic scratch_write,
  output bcjrformer_contract_pkg::mem_req_t scratch_request
);
  import bcjrformer_contract_pkg::*;
  bcjr_host_if #(.INDEX_W(16)) host();
  assign host.param_valid=param_valid;assign host.param_addr=param_addr;assign host.param_data=param_data;
  assign host.param_rsp_ready=param_rsp_ready;assign host.parameter_commit=parameter_commit;
  assign host.frame_valid=frame_valid;assign host.feature_valid=feature_valid;assign host.feature_data=feature_data;
  assign host.feature_last=feature_last;assign host.mask_valid=mask_valid;assign host.mask_bit=mask_bit;assign host.mask_last=mask_last;
  assign host.logit_ready=logit_ready;assign host.completion_ready=completion_ready;
  assign param_ready=host.param_ready;assign param_rsp_valid=host.param_rsp_valid;assign param_rsp_error=host.param_rsp_error;
  assign frame_ready=host.frame_ready;assign feature_ready=host.feature_ready;assign mask_ready=host.mask_ready;
  assign logit_valid=host.logit_valid;assign logit_last=host.logit_last;assign logit_data=host.logit_data;assign logit_index=host.logit_index;
  assign completion_valid=host.completion_valid;assign completion_error=host.completion_error;assign completion_code=host.completion_code;
  assign completion_position=host.completion_position;assign busy=host.busy;assign status=host.status;
  bcjrformer_core #(.F(F),.M(M),.N(N),.D(D),.H(H),.K(K),.MEMORY_DELAY(2)) dut(clk,rst,host);
  assign scratch_write=dut.scratch.adapter.commit_write;
  assign scratch_request=dut.scratch.adapter.request_q;
endmodule
