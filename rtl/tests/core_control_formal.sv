// Control-only service models. No stage performs numerical computation.
module core_control_formal #(parameter int CASE=0)(
  input logic clk,
  input logic host_go, memory_go, stage_go, finish_check,
  output logic test_done=0,
  output logic saw_stall=0,
  output logic saw_reset=0
);
  import bcjrformer_contract_pkg::*;
  logic past_valid=0, reset_trigger=0, reset_done=0;
  logic rst;
  bcjr_host_if #(.INDEX_W(1)) host();
  bcjr_cmd_if #(empty_t,empty_t) embed(), position(), encoder(), final_project();
  bcjr_cmd_if #(empty_t,aggregation_rsp_t) aggregate();
  bcjr_mem_if mem();
  core_ctrl #(.PARAM_WORDS(2),.FEATURE_WORDS(2),.MASK_WORDS(2),.OUTPUT_WORDS(2))
    dut(clk,rst,host,embed,position,encoder,final_project,aggregate,mem);
  typedef enum logic [3:0] {PARAM_SEND,PARAM_RESPONSE,COMMIT,FRAME,
    FEATURES,MASKS,WAIT_FRAME,STOP} host_state_t;
  host_state_t host_state;
  logic param_index, feature_index, mask_index;
  logic [1:0] frames_done;
  logic commit_injected;
  logic reload_started;
  logic memory_pending, memory_response;
  logic [1:0] memory_delay;
  mem_req_t memory_request;
  logic [4:0] stage_pending, stage_response;
  logic [4:0] stage_command, stage_ready, stage_rsp_ready;
  logic [1:0] stage_delay[5];
  logic [2:0] expected_stage;
  logic [2:0] feature_commits, mask_commits, output_transfers;
  logic [2:0] parameter_acks;
  logic fatal_seen;
  logic mem_fault;

  assign rst=!past_valid || reset_trigger;
  assign mem_fault=(CASE==6 && memory_request.bank==BANK_FEATURE && memory_request.addr==1) ||
    (CASE==13 && memory_request.bank==BANK_PARAM) ||
    (CASE==14 && memory_request.bank==BANK_OUTPUT && memory_request.addr==1);
  assign mem.req_ready=memory_go && !memory_pending && !rst;
  assign mem.rsp_valid=memory_response && !rst;
  assign mem.rsp_error=mem_fault;
  // Signed output patterns are deliberately unrelated to a computed inference.
  assign mem.rsp_rdata=memory_request.write ? 96'd0 :
    (memory_request.addr==0 ? {{80{1'b1}},16'hfffb} : 96'h1234);
  assign stage_command={aggregate.cmd_valid,final_project.cmd_valid,encoder.cmd_valid,
    position.cmd_valid,embed.cmd_valid};
  assign stage_ready={aggregate.cmd_ready,final_project.cmd_ready,encoder.cmd_ready,
    position.cmd_ready,embed.cmd_ready};
  assign stage_rsp_ready={aggregate.rsp_ready,final_project.rsp_ready,encoder.rsp_ready,
    position.rsp_ready,embed.rsp_ready};
  assign embed.cmd_ready=stage_go && !stage_pending[0] && !rst;
  assign position.cmd_ready=stage_go && !stage_pending[1] && !rst;
  assign encoder.cmd_ready=stage_go && !stage_pending[2] && !rst;
  assign final_project.cmd_ready=stage_go && !stage_pending[3] && !rst;
  assign aggregate.cmd_ready=stage_go && !stage_pending[4] && !rst;
  assign embed.rsp_valid=stage_response[0] && !rst;
  assign position.rsp_valid=stage_response[1] && !rst;
  assign encoder.rsp_valid=stage_response[2] && !rst;
  assign final_project.rsp_valid=stage_response[3] && !rst;
  assign aggregate.rsp_valid=stage_response[4] && !rst;
  assign embed.rsp='0; assign position.rsp='0;
  assign encoder.rsp='0; assign final_project.rsp='0;
  assign aggregate.rsp='{code:(CASE==1 && frames_done==0) || CASE==12 ?
    COMPLETION_EMPTY_POSITION : COMPLETION_OK, position:CASE==12 ? 16'd2 : 16'd1};
  assign embed.rsp_error=0; assign position.rsp_error=0;
  assign encoder.rsp_error=CASE==7; assign final_project.rsp_error=0;
  assign aggregate.rsp_error=0;
  assign embed.rsp_status='{protocol_error:0,numeric_error:0,saturated:1,rounded:0};
  assign position.rsp_status='{protocol_error:0,numeric_error:0,saturated:0,rounded:1};
  assign encoder.rsp_status='{protocol_error:0,numeric_error:CASE==7,saturated:0,rounded:0};
  assign final_project.rsp_status='0; assign aggregate.rsp_status='0;

  always_comb begin
    host.param_valid=host_state==PARAM_SEND || (CASE==19 && host_state==FRAME && !reload_started);
    host.param_addr=CASE==4 ? 32'd1 : CASE==16 && param_index ? 32'd0 :
      CASE==17 && parameter_acks==2 ? 32'd2 :
      CASE==19 && host_state==FRAME ? 32'd0 : 32'(param_index);
    host.param_data=CASE==19 && host_state==FRAME ? -16'sd7 : param_index ? 16'sd11 : -16'sd7;
    host.param_rsp_ready=host_go && !(CASE==18 && !commit_injected);
    host.parameter_commit=host_state==COMMIT;
    if(CASE==8 && memory_pending && memory_request.bank==BANK_PARAM && !commit_injected)
      host.parameter_commit=1;
    if(CASE==15 && stage_pending[2] && !commit_injected) host.parameter_commit=1;
    if(CASE==11 && host.completion_valid && !commit_injected) host.parameter_commit=1;
    if(CASE==18 && host.param_rsp_valid && !commit_injected) host.parameter_commit=1;
    if(CASE==20 && host.logit_valid && !commit_injected) host.parameter_commit=1;
    host.frame_valid=host_state==FRAME;
    host.feature_valid=host_state==FEATURES;
    host.feature_data=feature_index ? 16'sd3 : -16'sd9;
    host.feature_last=CASE==2 ? 1'b1 : feature_index;
    host.mask_valid=host_state==MASKS;
    host.mask_bit=mask_index;
    host.mask_last=CASE==3 ? 1'b0 : mask_index;
    host.logit_ready=host_go && !(CASE==10 && !reset_done) && !(CASE==20 && !commit_injected);
    host.completion_ready=host_go && !(CASE==11 && !commit_injected);
  end

  always @(posedge clk) begin
    past_valid<=1;
    reset_trigger<=0;
    if(reset_trigger) begin reset_done<=1; saw_reset<=1; end
    if(!rst && !reset_done && ((CASE==9 && memory_pending) ||
       (CASE==10 && host.logit_valid))) reset_trigger<=1;
    if(rst) begin
      host_state<=CASE==5 ? COMMIT : PARAM_SEND;
      param_index<=0; feature_index<=0; mask_index<=0; frames_done<=0;
      commit_injected<=0; reload_started<=0; memory_pending<=0; memory_response<=0;
      memory_delay<=0; memory_request<='0; stage_pending<=0; stage_response<=0;
      expected_stage<=0; feature_commits<=0; mask_commits<=0;
      output_transfers<=0; parameter_acks<=0; fatal_seen<=0; test_done<=0;
      for(integer s=0;s<5;s++) stage_delay[s]<=0;
      assert(!host.param_ready && !host.frame_ready && !host.feature_ready && !host.mask_ready);
      assert(!host.logit_valid && !host.completion_valid && !host.param_rsp_valid);
      assert(!mem.req_valid && !mem.rsp_ready && stage_command==0 && stage_rsp_ready==0);
    end else begin
      if(finish_check) assert(test_done);
      if(host.parameter_commit && host_state!=COMMIT) commit_injected<=1;
      if(mem.req_valid && mem.req_ready) begin
        memory_pending<=1; memory_delay<=2; memory_request<=mem.req;
        assert(!memory_pending);
        if(mem.req.bank!=BANK_MASK) assert(mem.req.format==FMT_S16_F10);
        if(mem.req.write) begin
          assert(mem.req.wdata[95:16]==0);
          if(mem.req.bank==BANK_PARAM) begin
            assert(mem.req.addr==32'(parameter_acks));
            assert(mem.req.wdata[15:0]==(mem.req.addr==0 ? 16'hfff9 : 16'd11));
          end else if(mem.req.bank==BANK_FEATURE) begin
            assert(mem.req.addr==32'(feature_commits));
            assert(mem.req.wdata[15:0]==(mem.req.addr==0 ? 16'hfff7 : 16'd3));
          end else begin
            assert(mem.req.bank==BANK_MASK && mem.req.format==FMT_BIT);
            assert(mem.req.addr==32'(mask_commits) && mem.req.wdata==96'(mask_commits));
          end
        end else begin
          assert(mem.req.bank==BANK_OUTPUT && expected_stage==5 && stage_pending==0);
          assert(mem.req.wdata==0 && mem.req.addr==32'(output_transfers));
        end
      end
      if(memory_pending && !memory_response) begin
        if(memory_delay==0) memory_response<=1;
        else memory_delay<=memory_delay-1;
      end
      if(mem.rsp_valid && mem.rsp_ready) begin
        memory_pending<=0; memory_response<=0;
        if(!mem.rsp_error && memory_request.write) begin
          if(memory_request.bank==BANK_FEATURE) feature_commits<=feature_commits+1;
          if(memory_request.bank==BANK_MASK) mask_commits<=mask_commits+1;
        end
      end
      for(integer s=0;s<5;s++) begin
        if(stage_command[s] && stage_ready[s]) begin
          assert(s==int'(expected_stage));
          assert(stage_pending==0);
          assert(feature_commits==2 && mask_commits==2 && parameter_acks==2);
          expected_stage<=expected_stage+1;
          stage_pending[s]<=1; stage_delay[s]<=2;
        end
        if(stage_pending[s] && !stage_response[s]) begin
          if(stage_delay[s]==0) stage_response[s]<=1;
          else stage_delay[s]<=stage_delay[s]-1;
        end
        if(stage_response[s] && stage_rsp_ready[s]) begin
          stage_pending[s]<=0; stage_response[s]<=0;
        end
      end
      case(host_state)
        PARAM_SEND: if(host.param_valid && host.param_ready) host_state<=PARAM_RESPONSE;
        PARAM_RESPONSE: if(host.param_rsp_valid && host.param_rsp_ready) begin
          parameter_acks<=parameter_acks+1;
          if(host.param_rsp_error || CASE==8 || CASE==18) host_state<=WAIT_FRAME;
          else if(CASE==17 && parameter_acks==1) host_state<=PARAM_SEND;
          else if(param_index) host_state<=COMMIT;
          else begin param_index<=1; host_state<=PARAM_SEND; end
        end
        COMMIT: host_state<=CASE==5 ? WAIT_FRAME : FRAME;
        FRAME: if(CASE==19 && host.param_valid && host.param_ready) begin
          assert(!host.frame_ready);
          reload_started<=1; param_index<=0; parameter_acks<=0; host_state<=PARAM_RESPONSE;
        end else if(host.frame_ready) begin host_state<=FEATURES;
          feature_index<=0; mask_index<=0; expected_stage<=0;
          feature_commits<=0; mask_commits<=0; output_transfers<=0; end
        FEATURES: if(host.feature_ready) begin
          if(feature_index) host_state<=MASKS; else feature_index<=1;
        end
        MASKS: if(host.mask_ready) begin
          if(mask_index) host_state<=WAIT_FRAME; else mask_index<=1;
        end
        default: ;
      endcase
      if(host.frame_ready) assert(parameter_acks==2);
      if(host.param_rsp_valid) assert(!memory_pending);
      if(host.logit_valid) begin
        assert(expected_stage==5);
        assert(host.logit_index==1'(output_transfers));
        assert(host.logit_last==(output_transfers==1));
        assert(host.logit_data==(output_transfers==0 ? -16'sd5 : 16'sh1234));
        if(host.logit_ready) output_transfers<=output_transfers+1;
      end
      if(host.completion_valid) begin
        assert(!memory_pending && stage_pending==0);
        if(CASE==1 && frames_done==0) begin
          assert(host.completion_code==COMPLETION_EMPTY_POSITION);
          assert(host.completion_position==1 && host.completion_error);
          assert(output_transfers==0 && !host.status.protocol_error && !host.status.numeric_error);
        end else if(CASE==0 || CASE==1 || CASE==9 || CASE==10 || CASE==19 || (CASE==11 && frames_done==0)) begin
          assert(host.completion_code==COMPLETION_OK && !host.completion_error);
          assert(output_transfers==2 && host.completion_position==0);
          assert(host.status.saturated && host.status.rounded);
        end else begin
          assert(host.completion_code==COMPLETION_FATAL && host.completion_error);
          assert(host.completion_position==0);
          assert(host.status.protocol_error || host.status.numeric_error);
          if(CASE==7) assert(host.status.numeric_error);
          if(CASE==14 || CASE==20) assert(output_transfers==1);
          else if(CASE!=11) assert(output_transfers==0);
        end
        if(host.completion_ready) begin
          frames_done<=frames_done+1;
          if((CASE==0 || CASE==1) && frames_done==0) host_state<=FRAME;
          else begin host_state<=STOP; test_done<=1; end
          if(CASE==11 && frames_done==0) begin host_state<=STOP; test_done<=0; end
          if(host.completion_code==COMPLETION_FATAL) fatal_seen<=1;
        end
      end
      if(fatal_seen) assert(!host.frame_ready && !host.param_ready && !mem.req_valid && stage_command==0);
      assert((stage_command & (stage_command-1'b1))==0);
      if(host.logit_valid && !host.logit_ready || host.completion_valid && !host.completion_ready ||
         host.param_rsp_valid && !host.param_rsp_ready || mem.req_valid && !mem.req_ready ||
         |(stage_command & ~stage_ready)) saw_stall<=1;
      if(past_valid && !$past(rst)) begin
        if($past(mem.req_valid && !mem.req_ready)) begin
          assert(mem.req_valid && mem.req==$past(mem.req)); end
        if($past(host.param_rsp_valid && !host.param_rsp_ready))
          assert(host.param_rsp_valid && host.param_rsp_error==$past(host.param_rsp_error));
        if($past(host.logit_valid && !host.logit_ready)) begin
          assert(host.logit_valid && {host.logit_data,host.logit_index,host.logit_last}==
            $past({host.logit_data,host.logit_index,host.logit_last})); end
        if($past(host.completion_valid && !host.completion_ready)) begin
          assert(host.completion_valid && {host.completion_code,host.completion_error,
            host.completion_position,host.status}==
            $past({host.completion_code,host.completion_error,host.completion_position,host.status})); end
        for(integer s=0;s<5;s++) if($past(stage_command[s] && !stage_ready[s])) assert(stage_command[s]);
      end
    end
  end
endmodule
