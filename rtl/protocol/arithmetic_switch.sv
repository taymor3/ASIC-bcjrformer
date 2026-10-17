module arithmetic_switch #(
  parameter int unsigned CLIENTS = 1,
  parameter type REQ_T = bcjrformer_contract_pkg::act_t,
  parameter type RSP_T = bcjrformer_contract_pkg::act_t
)(
  input logic clk, rst,
  bcjr_arith_if.responder clients [CLIENTS], bcjr_arith_if.requester service
);
  localparam int DATA_REQ_W = $bits(REQ_T);
  localparam int DATA_RSP_W = $bits(RSP_T);
  localparam int REQ_W = DATA_REQ_W+8;
  localparam int RSP_W = DATA_RSP_W+13; // error/status/tag
  logic [CLIENTS-1:0] valid_i, ready_o, rsp_valid_o, rsp_ready_i;
  logic [CLIENTS-1:0][REQ_W-1:0] request_i;
  logic [CLIENTS-1:0][RSP_W-1:0] response_o;
  logic [REQ_W-1:0] request_o;
  logic [RSP_W-1:0] service_response;
  for (genvar i=0; i<CLIENTS; i++) begin : client_wires
    assign valid_i[i] = clients[i].req_valid;
    assign clients[i].req_ready = ready_o[i];
    assign request_i[i] = {clients[i].req_tag, clients[i].req};
    assign clients[i].rsp_valid = rsp_valid_o[i];
    assign rsp_ready_i[i] = clients[i].rsp_ready;
    assign {clients[i].rsp_error, clients[i].rsp_status, clients[i].rsp_tag, clients[i].rsp} = response_o[i];
`ifndef SYNTHESIS
    initial if ($bits(clients[i].req)!=DATA_REQ_W || $bits(clients[i].rsp)!=DATA_RSP_W)
      $fatal(1, "Arithmetic switch payload width mismatch");
`endif
  end
  assign {service.req_tag,service.req} = request_o;
  assign service_response = {service.rsp_error, service.rsp_status, service.rsp_tag, service.rsp};
`ifndef SYNTHESIS
  initial if ($bits(service.req)!=DATA_REQ_W || $bits(service.rsp)!=DATA_RSP_W)
    $fatal(1, "Arithmetic switch service width mismatch");
`endif
  transaction_router #(.CLIENTS(CLIENTS), .REQ_W(REQ_W), .RSP_W(RSP_W)) router (
    .clk, .rst, .client_valid(valid_i), .client_ready(ready_o), .client_request(request_i),
    .client_response_valid(rsp_valid_o), .client_response_ready(rsp_ready_i), .client_response(response_o),
    .service_valid(service.req_valid), .service_ready(service.req_ready), .service_request(request_o),
    .service_response_valid(service.rsp_valid), .service_response_ready(service.rsp_ready), .service_response
  );
endmodule
