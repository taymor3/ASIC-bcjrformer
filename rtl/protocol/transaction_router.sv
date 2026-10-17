// One buffered request; retained owner through response acceptance.
module transaction_router #(
  parameter int unsigned CLIENTS = 1,
  parameter int unsigned REQ_W = 1,
  parameter int unsigned RSP_W = 1
)(
  input logic clk, rst,
  input logic [CLIENTS-1:0] client_valid,
  output logic [CLIENTS-1:0] client_ready,
  input logic [CLIENTS*REQ_W-1:0] client_request,
  output logic [CLIENTS-1:0] client_response_valid,
  input logic [CLIENTS-1:0] client_response_ready,
  output logic [CLIENTS*RSP_W-1:0] client_response,
  output logic service_valid,
  input logic service_ready,
  output logic [REQ_W-1:0] service_request,
  input logic service_response_valid,
  output logic service_response_ready,
  input logic [RSP_W-1:0] service_response
);
  localparam int OWNER_W = CLIENTS > 1 ? $clog2(CLIENTS) : 1;
  typedef enum logic [1:0] {IDLE, ISSUE, WAIT_RESPONSE} state_t;
  state_t state;
  logic [OWNER_W-1:0] owner, selected;
  logic found;
  logic [REQ_W-1:0] request_q;
  logic [REQ_W-1:0] selected_request;
  always_comb begin
    found = 1'b0;
    selected = '0;
    for (int i=0; i<CLIENTS; i++) begin
      if (!found && client_valid[i]) begin
        found = 1'b1;
        selected = OWNER_W'(i);
      end
    end
    selected_request='0;
    for (int i=0; i<CLIENTS; i++)
      if (selected==OWNER_W'(i)) selected_request=client_request[i*REQ_W +: REQ_W];
    client_ready = '0;
    client_response_valid = '0;
    client_response = '0;
    service_valid = 1'b0;
    service_request = request_q;
    service_response_ready = 1'b0;
    if (!rst) begin
      case (state)
        IDLE: if (found) client_ready[selected] = 1'b1;
        ISSUE: service_valid = 1'b1;
        WAIT_RESPONSE: begin
          for (int i=0; i<CLIENTS; i++) begin
            if(owner==OWNER_W'(i)) begin
              client_response_valid[i] = service_response_valid;
              client_response[i*RSP_W +: RSP_W] = service_response;
              service_response_ready = client_response_ready[i];
            end
          end
        end
        default: ;
      endcase
    end
  end
  always_ff @(posedge clk) begin
    if (rst) begin
      state <= IDLE;
      owner <= '0;
      request_q <= '0;
    end else begin
      case (state)
        IDLE: if (found && client_ready[selected]) begin
          owner <= selected;
          request_q <= selected_request;
          state <= ISSUE;
        end
        ISSUE: if (service_valid && service_ready) state <= WAIT_RESPONSE;
        WAIT_RESPONSE: if (service_response_valid && service_response_ready) state <= IDLE;
        default: state <= IDLE;
      endcase
    end
  end
  initial begin
    if (CLIENTS < 1 || REQ_W < 1 || RSP_W < 1) $fatal(1, "Invalid router parameters");
  end
endmodule
