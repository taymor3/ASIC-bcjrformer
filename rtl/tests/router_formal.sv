// Independent transaction scoreboard. Inputs unconstrained, including stalls/reset.
module router_formal(input logic clk);
  parameter integer CLIENTS=3;
  localparam integer REQ_W=12, RSP_W=17;
  (* anyseq *) logic rst;
  (* anyseq *) logic [CLIENTS-1:0] client_valid, client_response_ready;
  (* anyseq *) logic [CLIENTS*REQ_W-1:0] client_request;
  (* anyseq *) logic service_ready, service_response_valid;
  (* anyseq *) logic [RSP_W-1:0] service_response;
  wire [CLIENTS-1:0] client_ready, client_response_valid;
  wire [CLIENTS*RSP_W-1:0] client_response;
  wire service_valid, service_response_ready;
  wire [REQ_W-1:0] service_request;
  transaction_router #(.CLIENTS(CLIENTS),.REQ_W(REQ_W),.RSP_W(RSP_W)) dut(.*);
  logic live, dispatched;
  integer owner;
  logic [REQ_W-1:0] expected_request;
  logic past_valid=0;
  always @(posedge clk) begin
    past_valid<=1;
    if (!past_valid) assume(rst);
    if (rst) begin
      live<=0; dispatched<=0; owner<=0; expected_request<=0;
      assert(client_ready==0 && client_response_valid==0 && !service_valid && !service_response_ready);
    end else if (past_valid) begin
      assert((client_ready & (client_ready-1'b1))==0);
      assert((client_response_valid & (client_response_valid-1'b1))==0);
      if (live) assert(client_ready==0);
      if (live && !dispatched) assert(service_valid);
      if (!live) begin
        assert(!service_valid && client_response_valid==0 && !service_response_ready);
        for(integer i=0;i<CLIENTS;i=i+1) begin
          if(client_valid[i] && !(|(client_valid & ((1 << i)-1)))) assert(client_ready[i]);
        end
      end
      if (dispatched) begin
        assert(client_response_valid[owner]==service_response_valid);
        assert(service_response_ready==client_response_ready[owner]);
      end
      if (service_valid) begin
        assert(live && !dispatched);
        assert(service_request==expected_request);
      end
      if (service_valid && service_ready) dispatched<=1;
      for(integer i=0;i<CLIENTS;i=i+1) begin
        if(client_valid[i] && client_ready[i]) begin
          assert(!live);
          for(integer j=0;j<i;j=j+1) assert(!client_valid[j]);
          live<=1; dispatched<=0; owner<=i;
          expected_request<=client_request[i*REQ_W +: REQ_W];
        end
        if(client_response_valid[i]) begin
          assert(live && dispatched && owner==i);
          assert(client_response[i*RSP_W +: RSP_W]==service_response);
          assert(service_response_valid);
          if(client_response_ready[i]) begin live<=0; dispatched<=0; end
        end
      end
      if (service_response_ready) begin
        assert(live && dispatched);
        assert(client_response_ready[owner]);
      end
      if (past_valid && !$past(rst) && $past(service_valid && !service_ready)) begin
        assert(service_valid);
        assert(service_request==$past(service_request));
      end
      if (past_valid && !$past(rst) && $past(service_response_valid && !service_response_ready)) begin
        assume(service_response_valid);
        assume(service_response==$past(service_response));
      end
      if (past_valid && !$past(rst)) begin
        for(integer i=0;i<CLIENTS;i=i+1) begin
          if($past(client_response_valid[i] && !client_response_ready[i])) begin
            assert(client_response_valid[i]);
            assert(client_response[i*RSP_W +: RSP_W]==$past(client_response[i*RSP_W +: RSP_W]));
          end
        end
      end
    end
  end
endmodule
