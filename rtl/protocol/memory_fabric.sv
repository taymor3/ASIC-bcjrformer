module memory_fabric #(
  parameter int unsigned CLIENTS = 13,
  // Integration must supply all depths. Zero means disabled, never a guessed model.
  parameter longint unsigned BANK_DEPTHS [18] = '{default:0}
)(
  input logic clk, rst, bcjr_mem_if.responder clients [CLIENTS],
  bcjr_mem_if.requester parameters, scratch
);
  import bcjrformer_contract_pkg::*;
  localparam int OWNER_W = CLIENTS > 1 ? $clog2(CLIENTS) : 1;
  localparam int REQ_W = $bits(mem_req_t);
  logic [CLIENTS-1:0] valid_i, ready_o, rsp_valid_o, rsp_ready_i;
  logic [CLIENTS-1:0][REQ_W-1:0] request_i;
  logic [CLIENTS-1:0][$bits(mem_data_t):0] response_o;
  logic request_valid, request_ready, response_valid, response_ready;
  logic [$bits(mem_data_t):0] response_data;
  mem_req_t request_q;
  logic legal, local_error, write_bits_ok;
  logic [OWNER_W-1:0] captured_owner;
  mem_format_t expected_format;
  for (genvar i=0; i<CLIENTS; i++) begin : client_wires
    assign valid_i[i] = clients[i].req_valid;
    assign clients[i].req_ready = ready_o[i];
    assign request_i[i] = clients[i].req;
    assign clients[i].rsp_valid = rsp_valid_o[i];
    assign rsp_ready_i[i] = clients[i].rsp_ready;
    assign {clients[i].rsp_error, clients[i].rsp_rdata} = response_o[i];
  end
  // Record origin at capture so only client 0 (the core loader) can write PARAM/MASK.
  always_ff @(posedge clk) begin
    if (rst) captured_owner <= '0;
    else for (int i=0; i<CLIENTS; i++)
      if (valid_i[i] && ready_o[i]) captured_owner <= OWNER_W'(i);
  end
  always_comb begin
    expected_format = FMT_S16_F10;
    write_bits_ok = request_q.wdata[95:16]=='0;
    case (request_q.bank)
      BANK_MASK: begin expected_format=FMT_BIT; write_bits_ok=request_q.wdata[95:1]=='0; end
      BANK_SCORE: begin expected_format=FMT_S48_F20; write_bits_ok=request_q.wdata[95:48]=='0; end
      BANK_EXP, BANK_PROB: begin expected_format=FMT_U24_F22; write_bits_ok=request_q.wdata[95:24]=='0; end
      default: ;
    endcase
    legal = 1'b0;
    if (int'(request_q.bank) <= int'(BANK_OUTPUT)) begin
      legal = (64'(request_q.addr) < BANK_DEPTHS[int'(request_q.bank)]) &&
              request_q.format == expected_format;
    end
    if (request_q.write && !write_bits_ok) legal=1'b0;
    if (request_q.write && (request_q.bank==BANK_PARAM || request_q.bank==BANK_MASK) && captured_owner!='0)
      legal=1'b0;
    parameters.req_valid = 1'b0;
    scratch.req_valid = 1'b0;
    parameters.req = request_q;
    scratch.req = request_q;
    parameters.rsp_ready = 1'b0;
    scratch.rsp_ready = 1'b0;
    request_ready = 1'b0;
    response_valid = local_error;
    response_data = local_error ? {1'b1,mem_data_t'('0)} : '0;
    if (!rst && !local_error) begin
      if (!legal) request_ready = 1'b1; // consume internally; never dispatch invalid work
      else if (request_q.bank==BANK_PARAM) begin
        parameters.req_valid=request_valid;
        request_ready=parameters.req_ready;
        response_valid=parameters.rsp_valid;
        response_data={parameters.rsp_error,parameters.rsp_rdata};
        parameters.rsp_ready=response_ready;
      end else begin
        scratch.req_valid=request_valid;
        request_ready=scratch.req_ready;
        response_valid=scratch.rsp_valid;
        response_data={scratch.rsp_error,scratch.rsp_rdata};
        scratch.rsp_ready=response_ready;
      end
    end
  end
  always_ff @(posedge clk) begin
    if (rst) local_error <= 1'b0;
    else begin
      if (request_valid && request_ready && !legal) local_error <= 1'b1;
      else if (response_valid && response_ready) local_error <= 1'b0;
    end
  end
  transaction_router #(.CLIENTS(CLIENTS),.REQ_W(REQ_W),.RSP_W($bits(mem_data_t)+1)) router (
    .clk,.rst,.client_valid(valid_i),.client_ready(ready_o),.client_request(request_i),
    .client_response_valid(rsp_valid_o),.client_response_ready(rsp_ready_i),.client_response(response_o),
    .service_valid(request_valid),.service_ready(request_ready),.service_request(request_q),
    .service_response_valid(response_valid),.service_response_ready(response_ready),.service_response(response_data)
  );
endmodule
