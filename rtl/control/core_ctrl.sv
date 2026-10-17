// Host/control RTL only: numerical work is delegated to the five stage services.
module core_ctrl #(
  parameter longint unsigned PARAM_WORDS = 0,
  parameter longint unsigned FEATURE_WORDS = 0,
  parameter longint unsigned MASK_WORDS = 0,
  parameter longint unsigned OUTPUT_WORDS = 0
)(
  input logic clk, rst,
  bcjr_host_if.core host,
  bcjr_cmd_if.caller embed, position, encoder, final_project,
  bcjr_cmd_if.caller aggregate,
  bcjr_mem_if.requester mem
);
  import bcjrformer_contract_pkg::*;
  typedef enum logic [3:0] {
    IDLE, PARAM_ISSUE, PARAM_WAIT, PARAM_ACK,
    FEATURE_ACCEPT, FEATURE_ISSUE, FEATURE_WAIT,
    MASK_ACCEPT, MASK_ISSUE, MASK_WAIT,
    STAGE_ISSUE, STAGE_WAIT, OUTPUT_ISSUE, OUTPUT_WAIT,
    OUTPUT_SEND, COMPLETE
  } state_t;
  state_t state;
  logic image_valid, fatal_lock, abort_q, late_commit_q;
  logic param_error_q;
  localparam int PARAM_COUNT_W=PARAM_WORDS>0 ? $clog2(PARAM_WORDS+1) : 1;
  localparam longint unsigned LOAD_WORDS=FEATURE_WORDS>MASK_WORDS ? FEATURE_WORDS : MASK_WORDS;
  localparam int LOAD_INDEX_W=LOAD_WORDS>1 ? $clog2(LOAD_WORDS) : 1;
  localparam int OUTPUT_INDEX_W=OUTPUT_WORDS>1 ? $clog2(OUTPUT_WORDS) : 1;
  logic [PARAM_COUNT_W-1:0] param_count;
  logic [LOAD_INDEX_W-1:0] load_index;
  logic [OUTPUT_INDEX_W-1:0] output_index;
  logic [2:0] stage_index;
  mem_req_t request_q;
  act_t output_q;
  status_t status_q;
  completion_code_t completion_q;
  count_t completion_position_q;
  logic stage_ready, stage_valid, stage_error;
  status_t stage_status;
  aggregation_rsp_t aggregate_result;
  logic illegal_commit, abort_now;

  // Zero defaults deliberately do not select a model. Integration must provide
  // actual lengths and matching memory capacities, all in native elements.
  initial begin
    if (PARAM_WORDS==0 || FEATURE_WORDS==0 || MASK_WORDS==0 ||
        OUTPUT_WORDS==0 || OUTPUT_WORDS>65535 ||
        PARAM_WORDS>(64'd1<<ADDR_W) || FEATURE_WORDS>(64'd1<<ADDR_W) ||
        MASK_WORDS>(64'd1<<ADDR_W))
      $fatal(1,"core_ctrl needs positive, addressable manifest lengths");
    // Interface parameter references are constant in simulation and synthesis.
    // Unlike $bits(interface.member), read_slang supports this check in both.
    if (host.INDEX_W<OUTPUT_INDEX_W)
      $fatal(1,"host INDEX_W cannot represent every output position");
`ifndef SYNTHESIS
    if ($bits(aggregate.rsp)!=$bits(aggregation_rsp_t))
      $fatal(1,"aggregate must use aggregation_rsp_t");
`endif
  end

  always_comb begin
    illegal_commit=host.parameter_commit && state!=IDLE && state!=COMPLETE;
    abort_now=abort_q || illegal_commit;
    stage_ready=1'b0; stage_valid=1'b0; stage_error=1'b0; stage_status='0;
    aggregate_result=aggregation_rsp_t'(aggregate.rsp);
    case(stage_index)
      0: begin stage_ready=embed.cmd_ready; stage_valid=embed.rsp_valid;
        stage_error=embed.rsp_error; stage_status=embed.rsp_status; end
      1: begin stage_ready=position.cmd_ready; stage_valid=position.rsp_valid;
        stage_error=position.rsp_error; stage_status=position.rsp_status; end
      2: begin stage_ready=encoder.cmd_ready; stage_valid=encoder.rsp_valid;
        stage_error=encoder.rsp_error; stage_status=encoder.rsp_status; end
      3: begin stage_ready=final_project.cmd_ready; stage_valid=final_project.rsp_valid;
        stage_error=final_project.rsp_error; stage_status=final_project.rsp_status; end
      4: begin stage_ready=aggregate.cmd_ready; stage_valid=aggregate.rsp_valid;
        stage_error=aggregate.rsp_error; stage_status=aggregate.rsp_status; end
      default: ;
    endcase
    host.param_ready=!rst && !fatal_lock && state==IDLE && !host.parameter_commit;
    host.param_rsp_valid=!rst && state==PARAM_ACK;
    host.param_rsp_error=param_error_q;
    host.frame_ready=!rst && !fatal_lock && state==IDLE && image_valid &&
      !host.param_valid && !host.parameter_commit;
    host.feature_ready=!rst && state==FEATURE_ACCEPT && !abort_now;
    host.mask_ready=!rst && state==MASK_ACCEPT && !abort_now;
    host.logit_valid=!rst && state==OUTPUT_SEND;
    host.logit_data=output_q;
    host.logit_index=output_index;
    host.logit_last=output_index==OUTPUT_WORDS-1;
    host.completion_valid=!rst && state==COMPLETE;
    host.completion_error=completion_q!=COMPLETION_OK;
    host.completion_code=completion_q;
    host.completion_position=OUTPUT_INDEX_W'(completion_position_q);
    host.status=status_q;
    host.busy=!rst && (state!=IDLE || fatal_lock);

    embed.cmd='0; position.cmd='0; encoder.cmd='0;
    final_project.cmd='0; aggregate.cmd='0;
    embed.cmd_valid=!rst && state==STAGE_ISSUE && stage_index==0;
    position.cmd_valid=!rst && state==STAGE_ISSUE && stage_index==1;
    encoder.cmd_valid=!rst && state==STAGE_ISSUE && stage_index==2;
    final_project.cmd_valid=!rst && state==STAGE_ISSUE && stage_index==3;
    aggregate.cmd_valid=!rst && state==STAGE_ISSUE && stage_index==4;
    embed.rsp_ready=!rst && state==STAGE_WAIT && stage_index==0;
    position.rsp_ready=!rst && state==STAGE_WAIT && stage_index==1;
    encoder.rsp_ready=!rst && state==STAGE_WAIT && stage_index==2;
    final_project.rsp_ready=!rst && state==STAGE_WAIT && stage_index==3;
    aggregate.rsp_ready=!rst && state==STAGE_WAIT && stage_index==4;
    mem.req=request_q;
    mem.req_valid=!rst && (state==PARAM_ISSUE ||
      state==FEATURE_ISSUE || state==MASK_ISSUE || state==OUTPUT_ISSUE);
    mem.rsp_ready=!rst && (state==PARAM_WAIT || state==FEATURE_WAIT ||
      state==MASK_WAIT || state==OUTPUT_WAIT);
  end

  task automatic fatal_completion;
    begin
      state<=COMPLETE;
      completion_q<=COMPLETION_FATAL;
      completion_position_q<='0;
      fatal_lock<=1'b1;
      image_valid<=1'b0;
    end
  endtask
  task automatic protocol_failure;
    begin status_q.protocol_error<=1'b1; fatal_completion(); end
  endtask

  always_ff @(posedge clk) begin
    if(rst) begin
      state<=IDLE; image_valid<=1'b0; fatal_lock<=1'b0;
      abort_q<=1'b0; late_commit_q<=1'b0; param_error_q<=1'b0;
      param_count<=0; load_index<=0; output_index<=0; stage_index<=0;
      request_q<='0; output_q<='0; status_q<='0;
      completion_q<=COMPLETION_OK; completion_position_q<='0;
    end else begin
      // Only a commit strobe is an unhandshaked host operation. Defer its error
      // until an accepted memory/stage transaction has drained. Stalled host
      // acknowledgements and outputs remain unchanged, even after this fault.
      if(illegal_commit && !fatal_lock) abort_q<=1'b1;
      case(state)
        IDLE: if(!fatal_lock) begin
          if(host.parameter_commit) begin
            if(host.param_valid || param_count!=PARAM_WORDS) protocol_failure();
            else begin image_valid<=1'b1; param_count<=0; end
          end else if(host.param_valid && host.param_ready) begin
            image_valid<=1'b0; param_error_q<=1'b0;
            if(64'(host.param_addr)!=param_count || param_count>=PARAM_WORDS) begin
              param_error_q<=1'b1; status_q.protocol_error<=1'b1;
              fatal_lock<=1'b1; state<=PARAM_ACK;
            end else begin
              request_q<='{write:1'b1,bank:BANK_PARAM,addr:host.param_addr,
                format:FMT_S16_F10,wdata:{80'b0,host.param_data}};
              state<=PARAM_ISSUE;
            end
          end else if(host.frame_valid && host.frame_ready) begin
            status_q<='0; abort_q<=1'b0; output_index<=0;
            load_index<=0; completion_q<=COMPLETION_OK;
            completion_position_q<='0; state<=FEATURE_ACCEPT;
          end
        end
        PARAM_ISSUE: if(mem.req_ready) state<=PARAM_WAIT;
        PARAM_WAIT: if(mem.rsp_valid) begin
          param_error_q<=mem.rsp_error;
          if(mem.rsp_error) begin status_q.protocol_error<=1'b1;
            fatal_lock<=1'b1; image_valid<=1'b0; end
          else param_count<=param_count+1;
          state<=PARAM_ACK;
        end
        PARAM_ACK: if(host.param_rsp_ready) begin
          if(param_error_q || fatal_lock || abort_now) protocol_failure();
          else state<=IDLE;
        end
        FEATURE_ACCEPT: if(abort_now) protocol_failure();
        else if(host.feature_valid && host.feature_ready) begin
          if(host.feature_last!=(load_index==FEATURE_WORDS-1)) protocol_failure();
          else begin
            request_q<='{write:1'b1,bank:BANK_FEATURE,addr:addr_t'(load_index),
              format:FMT_S16_F10,wdata:{80'b0,host.feature_data}};
            state<=FEATURE_ISSUE;
          end
        end
        FEATURE_ISSUE: if(mem.req_ready) state<=FEATURE_WAIT;
        FEATURE_WAIT: if(mem.rsp_valid) begin
          if(mem.rsp_error || abort_now) protocol_failure();
          else if(load_index==FEATURE_WORDS-1) begin load_index<=0; state<=MASK_ACCEPT; end
          else begin load_index<=load_index+1; state<=FEATURE_ACCEPT; end
        end
        MASK_ACCEPT: if(abort_now) protocol_failure();
        else if(host.mask_valid && host.mask_ready) begin
          if(host.mask_last!=(load_index==MASK_WORDS-1)) protocol_failure();
          else begin
            request_q<='{write:1'b1,bank:BANK_MASK,addr:addr_t'(load_index),
              format:FMT_BIT,wdata:96'(host.mask_bit)};
            state<=MASK_ISSUE;
          end
        end
        MASK_ISSUE: if(mem.req_ready) state<=MASK_WAIT;
        MASK_WAIT: if(mem.rsp_valid) begin
          if(mem.rsp_error || abort_now) protocol_failure();
          else if(load_index==MASK_WORDS-1) begin stage_index<=0; state<=STAGE_ISSUE; end
          else begin load_index<=load_index+1; state<=MASK_ACCEPT; end
        end
        STAGE_ISSUE: if(stage_ready) state<=STAGE_WAIT;
        STAGE_WAIT: if(stage_valid) begin
          status_q<=status_q | stage_status;
          if(abort_now || stage_error || stage_status.protocol_error || stage_status.numeric_error) begin
            if(abort_now || (stage_error && !stage_status.protocol_error && !stage_status.numeric_error))
              status_q.protocol_error<=1'b1;
            fatal_completion();
          end else if(stage_index<4) begin stage_index<=stage_index+1; state<=STAGE_ISSUE; end
          else if(aggregate_result.code==COMPLETION_EMPTY_POSITION &&
                  64'(aggregate_result.position)<OUTPUT_WORDS) begin
            completion_q<=COMPLETION_EMPTY_POSITION;
            completion_position_q<=aggregate_result.position; state<=COMPLETE;
          end else if(aggregate_result.code!=COMPLETION_OK) begin
            status_q.protocol_error<=1'b1; fatal_completion();
          end else begin
            output_index<=0;
            request_q<='{write:1'b0,bank:BANK_OUTPUT,addr:'0,format:FMT_S16_F10,wdata:'0};
            state<=OUTPUT_ISSUE;
          end
        end
        OUTPUT_ISSUE: if(mem.req_ready) state<=OUTPUT_WAIT;
        OUTPUT_WAIT: if(mem.rsp_valid) begin
          if(mem.rsp_error || abort_now) protocol_failure();
          else begin output_q<=act_t'(mem.rsp_rdata[15:0]); state<=OUTPUT_SEND; end
        end
        OUTPUT_SEND: if(host.logit_ready) begin
          if(abort_now) protocol_failure();
          else if(output_index==OUTPUT_WORDS-1) begin
            completion_q<=COMPLETION_OK; completion_position_q<='0; state<=COMPLETE;
          end else begin
            output_index<=output_index+1;
            request_q<='{write:1'b0,bank:BANK_OUTPUT,addr:addr_t'(output_index+1),
              format:FMT_S16_F10,wdata:'0}; state<=OUTPUT_ISSUE;
          end
        end
        COMPLETE: begin
          // A late illegal commit must not mutate a held completion. Report
          // that separate host fault after the preceding report is accepted.
          if(host.parameter_commit && !fatal_lock) late_commit_q<=1'b1;
          if(host.completion_ready) begin
            if(!fatal_lock && (late_commit_q || host.parameter_commit)) begin
              late_commit_q<=1'b0; protocol_failure();
            end else state<=IDLE;
          end
        end
        default: protocol_failure();
      endcase
    end
  end
endmodule
