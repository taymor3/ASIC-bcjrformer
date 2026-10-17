// Wire bundles and direction declarations only; no behavioral logic.
interface bcjr_cmd_if #(
  parameter type CMD_T = bcjrformer_contract_pkg::empty_t,
  parameter type RSP_T = bcjrformer_contract_pkg::empty_t
);
  logic cmd_valid, cmd_ready;
  CMD_T cmd;
  logic rsp_valid, rsp_ready, rsp_error;
  RSP_T rsp;
  bcjrformer_contract_pkg::status_t rsp_status;
  modport caller(output cmd_valid, cmd, rsp_ready,
                 input cmd_ready, rsp_valid, rsp, rsp_error, rsp_status);
  modport callee(input cmd_valid, cmd, rsp_ready,
                 output cmd_ready, rsp_valid, rsp, rsp_error, rsp_status);
endinterface

interface bcjr_mem_if;
  logic req_valid, req_ready;
  bcjrformer_contract_pkg::mem_req_t req;
  logic rsp_valid, rsp_ready, rsp_error;
  bcjrformer_contract_pkg::mem_data_t rsp_rdata;
  modport requester(output req_valid, req, rsp_ready,
                    input req_ready, rsp_valid, rsp_rdata, rsp_error);
  modport responder(input req_valid, req, rsp_ready,
                    output req_ready, rsp_valid, rsp_rdata, rsp_error);
endinterface

interface bcjr_arith_if #(
  parameter type REQ_T = bcjrformer_contract_pkg::act_t,
  parameter type RSP_T = bcjrformer_contract_pkg::act_t
);
  logic req_valid, req_ready;
  REQ_T req;
  logic [7:0] req_tag;
  logic rsp_valid, rsp_ready, rsp_error;
  RSP_T rsp;
  logic [7:0] rsp_tag;
  bcjrformer_contract_pkg::status_t rsp_status;
  modport requester(output req_valid, req, req_tag, rsp_ready,
                    input req_ready, rsp_valid, rsp, rsp_tag, rsp_error, rsp_status);
  modport responder(input req_valid, req, req_tag, rsp_ready,
                    output req_ready, rsp_valid, rsp, rsp_tag, rsp_error, rsp_status);
endinterface

interface bcjr_host_if #(parameter int unsigned INDEX_W = 1);
  import bcjrformer_contract_pkg::*;
  logic param_valid, param_ready;
  addr_t param_addr;
  act_t param_data;
  // New explicit write acknowledgment closes the documented commit ordering.
  logic param_rsp_valid, param_rsp_ready, param_rsp_error;
  logic parameter_commit;
  logic frame_valid, frame_ready;
  logic feature_valid, feature_ready, feature_last;
  act_t feature_data;
  logic mask_valid, mask_ready, mask_bit, mask_last;
  logic logit_valid, logit_ready, logit_last;
  act_t logit_data;
  logic [INDEX_W-1:0] logit_index;
  logic completion_valid, completion_ready, completion_error;
  completion_code_t completion_code;
  logic [INDEX_W-1:0] completion_position;
  logic busy;
  status_t status;
  modport core(
    input param_valid, param_addr, param_data, param_rsp_ready, parameter_commit,
          frame_valid, feature_valid, feature_data, feature_last,
          mask_valid, mask_bit, mask_last, logit_ready, completion_ready,
    output param_ready, param_rsp_valid, param_rsp_error, frame_ready,
           feature_ready, mask_ready, logit_valid, logit_data, logit_index,
           logit_last, completion_valid, completion_error, completion_code,
           completion_position, busy, status);
  modport host(
    output param_valid, param_addr, param_data, param_rsp_ready, parameter_commit,
           frame_valid, feature_valid, feature_data, feature_last,
           mask_valid, mask_bit, mask_last, logit_ready, completion_ready,
    input param_ready, param_rsp_valid, param_rsp_error, frame_ready,
          feature_ready, mask_ready, logit_valid, logit_data, logit_index,
          logit_last, completion_valid, completion_error, completion_code,
          completion_position, busy, status);
endinterface
