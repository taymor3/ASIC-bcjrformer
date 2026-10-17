// Parent-control checks only. Child computations and mask memory are test models.
module attention_control_formal #(parameter int CASE=0,
  parameter longint unsigned TOKENS=2,HEADS=3,WIDTH=6)(
  input logic clk,service_go,memory_go,response_go,finish_check,
  output logic test_done=0,saw_stall=0,saw_reset=0
);
  import bcjrformer_contract_pkg::*;
  bcjr_cmd_if #(layer_cmd_t,empty_t) command(),qkv(),projection();
  bcjr_cmd_if #(row_cmd_t,empty_t) score(),weighted();
  bcjr_cmd_if #(softmax_cmd_t,empty_t) softmax();
  bcjr_mem_if mem();
  logic rst;
  attention_ctrl #(.TOKENS(TOKENS),.H(HEADS),.D(WIDTH),.K(3),.LAYER_WORDS(32))
    dut(clk,rst,command,qkv,score,softmax,weighted,projection,mem);
  localparam int RW=HEADS*TOKENS>1 ? $clog2(HEADS*TOKENS+1):1;
  logic [RW-1:0] row_q;
  logic [2:0] phase;
  logic past_valid=0,reset_trigger=0,reset_done=0,sent,run_q,fault_seen;
  logic [4:0] pending,reply,delay_q,fault_q,cmd_valid,cmd_ready,rsp_ready;
  logic memory_pending,memory_reply,memory_delay,mask_q,memory_fault;
  logic expected_mask;
  logic [31:0] expected_head,expected_query;
  layer_cmd_t input_descriptor,layer_descriptor;
  row_cmd_t row_descriptor;
  softmax_cmd_t softmax_descriptor;
  assign rst=!past_valid || reset_trigger;
  assign expected_head=32'(64'(row_q)/TOKENS);
  assign expected_query=32'(64'(row_q)%TOKENS);
  assign expected_mask=CASE==12 ? 1'b1 : CASE==13 ? 1'b0 : expected_query[0]^run_q;
  always_comb begin
    input_descriptor='{layer_index:run_q ? 16'd0:16'd1,layer_param_base:run_q ? 32'd200:32'd100};
    if(CASE==7) input_descriptor.layer_index=3;
    if(CASE==8) input_descriptor.layer_param_base=32'hfffffff8;
    // Input payload may change after acceptance; descendants must use the capture.
    if(sent) input_descriptor='{layer_index:16'hffff,layer_param_base:32'hffffffff};
  end
  assign command.cmd=input_descriptor;assign command.cmd_valid=!sent && !test_done;
  assign command.rsp_ready=response_go;
  assign cmd_valid={projection.cmd_valid,weighted.cmd_valid,softmax.cmd_valid,score.cmd_valid,qkv.cmd_valid};
  assign cmd_ready={projection.cmd_ready,weighted.cmd_ready,softmax.cmd_ready,score.cmd_ready,qkv.cmd_ready};
  assign rsp_ready={projection.rsp_ready,weighted.rsp_ready,softmax.rsp_ready,score.rsp_ready,qkv.rsp_ready};
  assign qkv.cmd_ready=service_go && !pending[0] && !rst;
  assign score.cmd_ready=service_go && !pending[1] && !rst;
  assign softmax.cmd_ready=service_go && !pending[2] && !rst;
  assign weighted.cmd_ready=service_go && !pending[3] && !rst;
  assign projection.cmd_ready=service_go && !pending[4] && !rst;
  assign qkv.rsp_valid=reply[0] && !rst;assign score.rsp_valid=reply[1] && !rst;
  assign softmax.rsp_valid=reply[2] && !rst;assign weighted.rsp_valid=reply[3] && !rst;
  assign projection.rsp_valid=reply[4] && !rst;
  assign qkv.rsp='0;assign score.rsp='0;assign softmax.rsp='0;assign weighted.rsp='0;assign projection.rsp='0;
  assign qkv.rsp_error=fault_q[0];assign score.rsp_error=fault_q[1];
  assign softmax.rsp_error=0;assign weighted.rsp_error=fault_q[3];assign projection.rsp_error=fault_q[4];
  assign qkv.rsp_status='{protocol_error:0,numeric_error:fault_q[0],saturated:0,rounded:1};
  assign score.rsp_status='{protocol_error:0,numeric_error:fault_q[1],saturated:0,rounded:0};
  assign softmax.rsp_status='{protocol_error:0,numeric_error:fault_q[2],saturated:1,rounded:0};
  assign weighted.rsp_status='{protocol_error:fault_q[3],numeric_error:0,saturated:0,rounded:0};
  assign projection.rsp_status='0;
  assign mem.req_ready=memory_go && !memory_pending && !rst;
  assign mem.rsp_valid=memory_reply && !rst;assign mem.rsp_error=memory_fault;
  assign mem.rsp_rdata={95'b0,mask_q};
  always @(posedge clk) begin
    past_valid<=1;reset_trigger<=0;
    if(reset_trigger) begin reset_done<=1;saw_reset<=1;end
    if(!rst && !reset_done && (CASE==9 && memory_pending || CASE==10 && pending[2] ||
       CASE==11 && command.rsp_valid)) reset_trigger<=1;
    if(rst) begin
      phase<=0;row_q<=0;sent<=0;run_q<=0;fault_seen<=0;pending<=0;reply<=0;delay_q<=0;fault_q<=0;
      memory_pending<=0;memory_reply<=0;memory_delay<=0;mask_q<=0;memory_fault<=0;test_done<=0;
      assert(!command.cmd_ready && !command.rsp_valid && cmd_valid==0 && rsp_ready==0 && !mem.req_valid && !mem.rsp_ready);
    end else begin
      if(finish_check) assert(test_done);
      if(command.cmd_valid && command.cmd_ready) begin sent<=1;phase<=0;row_q<=0;fault_seen<=0;end
      assert((cmd_valid & (cmd_valid-1'b1))==0);
      if(mem.req_valid && mem.req_ready) begin
        assert(sent && phase==1 && pending==0 && !memory_pending);
        assert(!mem.req.write && mem.req.bank==BANK_MASK && mem.req.format==FMT_BIT);
        assert(mem.req.addr==expected_query && mem.req.wdata==0);
        memory_pending<=1;memory_delay<=1;mask_q<=expected_mask;memory_fault<=CASE==3 && row_q==3;
      end
      if(memory_pending && !memory_reply) begin if(!memory_delay) memory_reply<=1;else memory_delay<=0;end
      if(mem.rsp_valid && mem.rsp_ready) begin memory_pending<=0;memory_reply<=0;
        if(memory_fault) fault_seen<=1;else phase<=2;end
      for(integer c=0;c<5;c++) begin
        if(cmd_valid[c] && cmd_ready[c]) begin
          assert(sent && pending==0 && !memory_pending && CASE!=7 && CASE!=8);
          assert(c==0 ? phase==0:c==4 ? phase==5:phase==3'(c+1));
          pending[c]<=1;delay_q[c]<=1;
          fault_q[c]<=CASE==1 && c==0 || CASE==2 && c==1 && row_q==2 ||
            CASE==4 && c==2 || CASE==5 && c==3 || CASE==6 && c==4;
          if(c==0 || c==4) begin
            layer_descriptor=layer_cmd_t'(c==0 ? qkv.cmd:projection.cmd);
            assert(layer_descriptor.layer_index==(run_q ? 0:1));
            assert(layer_descriptor.layer_param_base==(run_q ? 200:100));
            if(c==4) assert(64'(row_q)==HEADS*TOKENS);
          end
          if(c==1 || c==3) begin row_descriptor=row_cmd_t'(c==1 ? score.cmd:weighted.cmd);
            assert(row_descriptor.head_index==16'(expected_head) && row_descriptor.query_index==16'(expected_query));end
          if(c==2) begin softmax_descriptor=softmax_cmd_t'(softmax.cmd);
            assert(softmax_descriptor.padded_query==expected_mask);end
        end
        if(pending[c] && !reply[c]) begin if(!delay_q[c]) reply[c]<=1;else delay_q[c]<=0;end
        if(reply[c] && rsp_ready[c]) begin pending[c]<=0;reply[c]<=0;
          if(fault_q[c]) fault_seen<=1;
          else if(c==3) begin row_q<=row_q+1;
            phase<=64'(row_q)==HEADS*TOKENS-1 ? 5:1;end
          else phase<=phase+1;
        end
      end
      if(command.rsp_valid) begin
        assert(pending==0 && !memory_pending);
        if(fault_seen || CASE==7 || CASE==8) assert(command.rsp_error &&
          (command.rsp_status.protocol_error || command.rsp_status.numeric_error));
        else begin assert(!command.rsp_error && phase==6 && 64'(row_q)==HEADS*TOKENS);
          assert(command.rsp_status.rounded && command.rsp_status.saturated);end
        if(command.rsp_ready) begin
          if(CASE==0 && !run_q) begin run_q<=1;sent<=0;end else test_done<=1;
        end
      end
      if(test_done && (fault_seen || CASE==7 || CASE==8)) assert(!command.cmd_ready && cmd_valid==0 && !mem.req_valid);
      if(command.rsp_valid && !command.rsp_ready || |(cmd_valid & ~cmd_ready) || mem.req_valid && !mem.req_ready) saw_stall<=1;
      if(past_valid && !$past(rst)) begin
        if($past(mem.req_valid && !mem.req_ready)) assert(mem.req_valid && mem.req==$past(mem.req));
        if($past(qkv.cmd_valid && !qkv.cmd_ready)) assert(qkv.cmd_valid && qkv.cmd==$past(qkv.cmd));
        if($past(score.cmd_valid && !score.cmd_ready)) assert(score.cmd_valid && score.cmd==$past(score.cmd));
        if($past(softmax.cmd_valid && !softmax.cmd_ready)) assert(softmax.cmd_valid && softmax.cmd==$past(softmax.cmd));
        if($past(weighted.cmd_valid && !weighted.cmd_ready)) assert(weighted.cmd_valid && weighted.cmd==$past(weighted.cmd));
        if($past(projection.cmd_valid && !projection.cmd_ready)) assert(projection.cmd_valid && projection.cmd==$past(projection.cmd));
        if($past(command.rsp_valid && !command.rsp_ready)) assert(command.rsp_valid &&
          {command.rsp_error,command.rsp_status}==$past({command.rsp_error,command.rsp_status}));
      end
    end
  end
endmodule
