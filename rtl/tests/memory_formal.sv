// Independent transaction/data scoreboard over the actual connected RTL.
module memory_formal #(
  parameter int CLIENTS=3,
  parameter int PARAM_DELAY=2, SCRATCH_DELAY=3,
  parameter int TEST_BANK=-1,
  parameter bit CHECK_DATA=1'b1
)(
  input logic clk, rst,
  input logic [CLIENTS-1:0] valid, ready_response,
  input logic [CLIENTS-1:0][$bits(bcjrformer_contract_pkg::mem_req_t)-1:0] requests,
  input logic [4:0] tracked_bank,
  input logic tracked_address,
  output logic cover_readback=0,
  output logic cover_error=0,
  output logic cover_stall=0,
  output logic cover_reset_readback=0
);
  import bcjrformer_contract_pkg::*;
  localparam longint unsigned DEPTHS [18]='{default:2};
  logic [CLIENTS-1:0] ready, valid_response, error_response;
  mem_data_t response [CLIENTS];
  wire [4:0] tracked = TEST_BANK<0 ? tracked_bank : 5'(TEST_BANK);
  mem_req_t injected [CLIENTS];
  bcjr_mem_if clients[CLIENTS]();
  bcjr_mem_if params(), scratch();
  for(genvar i=0;i<CLIENTS;i++) begin : wires_to_clients
    assign clients[i].req_valid=valid[i];
    always_comb begin
      injected[i]=mem_req_t'(requests[i]);
      if(TEST_BANK>=0) begin
        // Data cases use well-formed requests; unrestricted control case covers faults.
        injected[i].bank=bank_t'(TEST_BANK);
        injected[i].addr={31'b0,injected[i].addr[0]};
        case(TEST_BANK)
          2: begin injected[i].format=FMT_BIT; injected[i].wdata={95'b0,injected[i].wdata[0]}; end
          13: begin injected[i].format=FMT_S48_F20; injected[i].wdata={48'b0,injected[i].wdata[47:0]}; end
          14,15: begin injected[i].format=FMT_U24_F22; injected[i].wdata={72'b0,injected[i].wdata[23:0]}; end
          default: begin injected[i].format=FMT_S16_F10; injected[i].wdata={80'b0,injected[i].wdata[15:0]}; end
        endcase
        if((TEST_BANK==0 || TEST_BANK==2) && i!=0) injected[i].write=0;
      end
    end
    assign clients[i].req=injected[i];
    assign clients[i].rsp_ready=ready_response[i];
    assign ready[i]=clients[i].req_ready;
    assign valid_response[i]=clients[i].rsp_valid;
    assign error_response[i]=clients[i].rsp_error;
    assign response[i]=clients[i].rsp_rdata;
  end
  memory_fabric #(.CLIENTS(CLIENTS),.BANK_DEPTHS(DEPTHS)) fabric(clk,rst,clients,params,scratch);
  parameter_mem #(.DEPTH(2),.RESPONSE_DELAY(PARAM_DELAY)) parameter_store(clk,rst,params);
  scratch_mem #(.BANK_DEPTHS(DEPTHS),.RESPONSE_DELAY(SCRATCH_DELAY)) scratch_store(clk,rst,scratch);

  function automatic bit allowed(input mem_req_t r, input int owner);
    bit ok;
    ok=int'(r.bank)<=17 && r.addr<2;
    case(r.bank)
      BANK_MASK: ok=ok && r.format==FMT_BIT && (!r.write || r.wdata[95:1]==0);
      BANK_SCORE: ok=ok && r.format==FMT_S48_F20 && (!r.write || r.wdata[95:48]==0);
      BANK_EXP, BANK_PROB: ok=ok && r.format==FMT_U24_F22 && (!r.write || r.wdata[95:24]==0);
      default: ok=ok && r.format==FMT_S16_F10 && (!r.write || r.wdata[95:16]==0);
    endcase
    if(r.write && (r.bank==BANK_PARAM || r.bank==BANK_MASK) && owner!=0) ok=0;
    return ok;
  endfunction
  function automatic mem_data_t canonical(input mem_req_t r);
    case(r.bank)
      BANK_MASK: return {95'b0,r.wdata[0]};
      BANK_SCORE: return {{48{r.wdata[47]}},r.wdata[47:0]};
      BANK_EXP, BANK_PROB: return {72'b0,r.wdata[23:0]};
      default: return {{80{r.wdata[15]}},r.wdata[15:0]};
    endcase
  endfunction
  // A fixed arbitrary location: the proof universally ranges over every bank/word.
  // Avoid duplicating the entire memory in the reference checker.
  mem_data_t golden;
  bit known=0;
  bit reset_after_write=0;
  logic past_valid=0, live, dispatched, expected_error, check_data;
  mem_req_t expected_request, storage_request;
  mem_data_t expected_data;
  int owner;
  logic [5:0] age;
  localparam int DELAY_W=$clog2((PARAM_DELAY>SCRATCH_DELAY ? PARAM_DELAY:SCRATCH_DELAY)+1);
  logic [DELAY_W-1:0] storage_delay;
  logic storage_pending;
  always @(posedge clk) begin
    past_valid<=1;
    if(!past_valid) assume(rst);
    assume(tracked<=17);
    if(past_valid) begin
      assume(tracked_bank==$past(tracked_bank));
      assume(tracked_address==$past(tracked_address));
    end
    if(rst) begin
      if(known) reset_after_write<=1;
      live<=0; dispatched<=0; expected_error<=0; check_data<=0;
      expected_request<='0; storage_request<='0; expected_data<='0;
      owner<=0; age<=0; storage_pending<=0; storage_delay<=0;
      assert(ready==0 && valid_response==0 && !params.req_valid && !scratch.req_valid);
    end else if(past_valid) begin
      if(live) begin
        if(age!=63) age<=age+1;
        assert(ready==0);
        if(age>=1+(PARAM_DELAY>SCRATCH_DELAY ? PARAM_DELAY:SCRATCH_DELAY))
          assert(valid_response[owner]);
      end
      assert(!(params.req_valid && scratch.req_valid));
      if(params.req_valid || scratch.req_valid) begin
        assert(live && !expected_error && !dispatched);
        assert(params.req_valid ? expected_request.bank==BANK_PARAM : expected_request.bank!=BANK_PARAM);
        assert((params.req_valid ? params.req : scratch.req)==expected_request);
      end
      if((params.req_valid && params.req_ready) || (scratch.req_valid && scratch.req_ready)) begin
        dispatched<=1;
        storage_pending<=1;
        storage_request<=expected_request;
        storage_delay<=DELAY_W'(expected_request.bank==BANK_PARAM ? PARAM_DELAY-1:SCRATCH_DELAY-1);
      end
      if(storage_pending) begin
        if(storage_delay>0) storage_delay<=storage_delay-1;
        else begin
          storage_pending<=0;
          if(CHECK_DATA && storage_request.write && storage_request.bank==tracked && storage_request.addr==32'(tracked_address)) begin
            golden<=canonical(storage_request);
            known<=1;
          end
        end
      end
      for(int i=0;i<CLIENTS;i++) begin
        if(valid[i] && ready[i]) begin
          mem_req_t r;
          r=injected[i];
          assert(!live);
          live<=1; dispatched<=0; owner<=i; age<=0;
          expected_request<=r; expected_error<=!allowed(r,i);
          check_data<=!allowed(r,i) || r.write || (CHECK_DATA && allowed(r,i) && r.bank==tracked && r.addr==32'(tracked_address) && known);
          expected_data<=allowed(r,i) && !r.write ? golden:'0;
        end
        if(valid_response[i]) begin
          assert(live && owner==i);
          assert(error_response[i]==expected_error);
          if(CHECK_DATA && check_data) assert(response[i]==expected_data);
          // Successful acknowledgment cannot precede the modeled storage access.
          if(!expected_error) assert(dispatched && !storage_pending);
          if(expected_error) cover_error<=1;
          if(check_data && !expected_error && !expected_request.write) cover_readback<=1;
          if(check_data && !expected_error && !expected_request.write && reset_after_write) cover_reset_readback<=1;
          if(!ready_response[i]) cover_stall<=1;
          if(ready_response[i]) begin live<=0; dispatched<=0; end
        end
      end
      if(!$past(rst)) begin
        for(int i=0;i<CLIENTS;i++) begin
          if($past(valid_response[i] && !ready_response[i])) begin
            assert(valid_response[i]);
            assert(response[i]==$past(response[i]));
            assert(error_response[i]==$past(error_response[i]));
          end
        end
      end
    end
  end
endmodule
