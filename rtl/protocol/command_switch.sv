module command_switch #(
  parameter int unsigned CLIENTS = 1,
  parameter type CMD_T = bcjrformer_contract_pkg::empty_t,
  parameter type RSP_T = bcjrformer_contract_pkg::empty_t
)(
  input logic clk, rst,
  bcjr_cmd_if.callee clients [CLIENTS], bcjr_cmd_if.caller service
);
  localparam int REQ_W = $bits(CMD_T);
  localparam int DATA_W = $bits(RSP_T);
  localparam int RSP_W = DATA_W + 5; // fatal error + four status bits
  logic [CLIENTS-1:0] valid_i, ready_o, rsp_valid_o, rsp_ready_i;
  logic [CLIENTS-1:0][REQ_W-1:0] request_i;
  logic [CLIENTS-1:0][RSP_W-1:0] response_o;
  logic [RSP_W-1:0] service_response;
  for (genvar i=0; i<CLIENTS; i++) begin : client_wires
    assign valid_i[i] = clients[i].cmd_valid;
    assign clients[i].cmd_ready = ready_o[i];
    assign request_i[i] = clients[i].cmd;
    assign clients[i].rsp_valid = rsp_valid_o[i];
    assign rsp_ready_i[i] = clients[i].rsp_ready;
    assign {clients[i].rsp_error, clients[i].rsp_status, clients[i].rsp} = response_o[i];
`ifndef SYNTHESIS
    initial if ($bits(clients[i].cmd)!=REQ_W || $bits(clients[i].rsp)!=DATA_W)
      $fatal(1, "Command switch payload width mismatch");
`endif
  end
  assign service_response = {service.rsp_error, service.rsp_status, service.rsp};
`ifndef SYNTHESIS
  initial if ($bits(service.cmd)!=REQ_W || $bits(service.rsp)!=DATA_W)
    $fatal(1, "Command switch service width mismatch");
`endif
  transaction_router #(.CLIENTS(CLIENTS), .REQ_W(REQ_W), .RSP_W(RSP_W)) router (
    .clk, .rst, .client_valid(valid_i), .client_ready(ready_o), .client_request(request_i),
    .client_response_valid(rsp_valid_o), .client_response_ready(rsp_ready_i), .client_response(response_o),
    .service_valid(service.cmd_valid), .service_ready(service.cmd_ready), .service_request(service.cmd),
    .service_response_valid(service.rsp_valid), .service_response_ready(service.rsp_ready), .service_response
  );
endmodule
