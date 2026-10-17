// Actual composed encoder/layer controllers; numerical child services are models.
module encoder_layer_formal #(parameter int CASE=0)(
  input logic clk,service_go,response_go,finish_check,
  output logic test_done=0,saw_stall=0,saw_reset=0
);
  import bcjrformer_contract_pkg::*;
  bcjr_cmd_if #(empty_t,empty_t) command();
  bcjr_cmd_if #(layer_cmd_t,empty_t) encoder_layer(),layer_call();
  bcjr_cmd_if #(layernorm_cmd_t,empty_t) norm();
  bcjr_cmd_if #(layer_cmd_t,empty_t) attention();
  bcjr_cmd_if #(residual_cmd_t,empty_t) residual();
  bcjr_cmd_if #(ffn_cmd_t,empty_t) ffn();
  logic past_valid=0,reset_trigger=0,reset_done=0,rst;
  logic sent,run_q,fault_seen;
  logic [1:0] expected_layer;
  logic [3:0] ordinal;
  logic [3:0] pending,valid_reply,cmd_valid,cmd_ready,rsp_ready;
  logic [3:0] delay_q;
  logic [3:0] fault_q;
  layer_cmd_t injected,attention_descriptor;
  layernorm_cmd_t norm_descriptor;
  residual_cmd_t residual_descriptor;
  ffn_cmd_t ffn_descriptor;
  logic [1:0] target;
  logic token;
  addr_t base;
  encoder_ctrl #(.K(3),.LAYER_STRIDE(64),.LAYER_WORDS(20),.FIRST_LAYER_BASE(100))
    encoder(clk,rst,command,encoder_layer);
  layer_ctrl #(.TOKENS(2),.D(3),.K(3),.LAYER_WORDS(20),.LN1_GAMMA_OFFSET(0),
    .LN1_BETA_OFFSET(4),.LN2_GAMMA_OFFSET(8),.LN2_BETA_OFFSET(12))
    layer(clk,rst,layer_call,norm,attention,residual,ffn);
  assign rst=!past_valid || reset_trigger;
  assign command.cmd_valid=!sent && !test_done;
  assign command.cmd=CASE==3;
  assign command.rsp_ready=response_go;
  always_comb begin
    injected=layer_cmd_t'(encoder_layer.cmd);
    if(CASE==7) injected.layer_index=3;
    if(CASE==8) injected.layer_param_base=32'hfffffff8;
  end
  assign layer_call.cmd=injected;assign layer_call.cmd_valid=encoder_layer.cmd_valid;
  assign encoder_layer.cmd_ready=layer_call.cmd_ready;
  assign encoder_layer.rsp_valid=layer_call.rsp_valid;
  assign encoder_layer.rsp=layer_call.rsp;
  assign encoder_layer.rsp_error=layer_call.rsp_error;
  assign encoder_layer.rsp_status=layer_call.rsp_status;
  assign layer_call.rsp_ready=encoder_layer.rsp_ready;
  assign cmd_valid={ffn.cmd_valid,residual.cmd_valid,attention.cmd_valid,norm.cmd_valid};
  assign cmd_ready={ffn.cmd_ready,residual.cmd_ready,attention.cmd_ready,norm.cmd_ready};
  assign rsp_ready={ffn.rsp_ready,residual.rsp_ready,attention.rsp_ready,norm.rsp_ready};
  assign norm.cmd_ready=service_go && !pending[0] && !rst;
  assign attention.cmd_ready=service_go && !pending[1] && !rst;
  assign residual.cmd_ready=service_go && !pending[2] && !rst;
  assign ffn.cmd_ready=service_go && !pending[3] && !rst;
  assign norm.rsp_valid=valid_reply[0] && !rst;
  assign attention.rsp_valid=valid_reply[1] && !rst;
  assign residual.rsp_valid=valid_reply[2] && !rst;
  assign ffn.rsp_valid=valid_reply[3] && !rst;
  assign norm.rsp='0;assign attention.rsp='0;assign residual.rsp='0;assign ffn.rsp='0;
  assign norm.rsp_error=fault_q[0];assign attention.rsp_error=fault_q[1];
  assign residual.rsp_error=fault_q[2];assign ffn.rsp_error=fault_q[3];
  assign norm.rsp_status='{protocol_error:0,numeric_error:fault_q[0],saturated:0,rounded:1};
  assign attention.rsp_status='0;
  assign residual.rsp_status='{protocol_error:0,numeric_error:0,saturated:1,rounded:0};
  assign ffn.rsp_status='{protocol_error:CASE==2 && fault_q[3],numeric_error:0,saturated:0,rounded:0};
  // Independent flattened schedule for two tokens: LN1,LN1,A,R1,R1,LN2,LN2,F,R2,F,R2.
  always_comb begin
    base=32'(100+32'(expected_layer)*64);
    target=0;token=0;
    case(ordinal)
      0:begin target=0;token=0;end 1:begin target=0;token=1;end
      2:begin target=1;token=0;end
      3:begin target=2;token=0;end 4:begin target=2;token=1;end
      5:begin target=0;token=0;end 6:begin target=0;token=1;end
      7:begin target=3;token=0;end 8:begin target=2;token=0;end
      9:begin target=3;token=1;end 10:begin target=2;token=1;end
      default: ;
    endcase
  end
  always @(posedge clk) begin
    past_valid<=1;reset_trigger<=0;
    if(reset_trigger) begin reset_done<=1;saw_reset<=1;end
    if(!rst && !reset_done && (CASE==4 && |pending || CASE==5 && command.rsp_valid)) reset_trigger<=1;
    if(rst) begin sent<=0;run_q<=0;fault_seen<=0;expected_layer<=0;ordinal<=0;
      pending<=0;valid_reply<=0;delay_q<=0;fault_q<=0;test_done<=0;
      assert(!command.cmd_ready && !command.rsp_valid && cmd_valid==0 && rsp_ready==0);
      assert(!encoder_layer.cmd_valid && !layer_call.cmd_ready && !layer_call.rsp_valid);
    end else begin
      if(finish_check) assert(test_done);
      if(command.cmd_valid && command.cmd_ready) begin sent<=1;expected_layer<=0;ordinal<=0;fault_seen<=0;end
      if(encoder_layer.cmd_valid && encoder_layer.cmd_ready) begin
        assert(sent && pending==0);
        assert(layer_cmd_t'(encoder_layer.cmd).layer_index==16'(expected_layer));
        assert(layer_cmd_t'(encoder_layer.cmd).layer_param_base==base);
        ordinal<=0;
      end
      if(layer_call.rsp_valid && layer_call.rsp_ready) begin
        assert(pending==0);
        if(layer_call.rsp_error) fault_seen<=1;
        else begin assert(ordinal==11);expected_layer<=expected_layer+1;end
      end
      assert((cmd_valid & (cmd_valid-1'b1))==0);
      for(integer c=0;c<4;c++) begin
        if(cmd_valid[c] && cmd_ready[c]) begin
          assert(pending==0 && ordinal<11 && c==int'(target));
          assert(CASE!=7 && CASE!=8);
          pending[c]<=1;delay_q[c]<=1;
          fault_q[c]<=CASE==1 && c==0 || CASE==2 && c==3 && expected_layer==1 && token ||
            CASE==6 && c==1;
          if(c==0) begin
            norm_descriptor=layernorm_cmd_t'(norm.cmd);
            assert(norm_descriptor.length==3);
            assert(norm_descriptor.src==ptr_t'{bank:BANK_X,addr:32'(token)*3});
            assert(norm_descriptor.dst==ptr_t'{bank:BANK_U,addr:32'(token)*3});
            assert(norm_descriptor.gamma_base==base+(ordinal<2 ? 0:8));
            assert(norm_descriptor.beta_base==base+(ordinal<2 ? 4:12));
          end
          if(c==1) begin attention_descriptor=layer_cmd_t'(attention.cmd);
            assert(attention_descriptor.layer_index==16'(expected_layer) && attention_descriptor.layer_param_base==base);end
          if(c==2) begin residual_descriptor=residual_cmd_t'(residual.cmd);
            assert(residual_descriptor.length==3);
            assert(residual_descriptor.left==ptr_t'{bank:BANK_X,addr:32'(token)*3});
            assert(residual_descriptor.dst==residual_descriptor.left);
            assert(residual_descriptor.right==ptr_t'{bank:ordinal<5 ? BANK_ATTN_OUT:BANK_VECTOR,
              addr:ordinal<5 ? 32'(token)*3:32'd0});end
          if(c==3) begin ffn_descriptor=ffn_cmd_t'(ffn.cmd);
            assert(ffn_descriptor.src==ptr_t'{bank:BANK_U,addr:32'(token)*3});
            assert(ffn_descriptor.dst==ptr_t'{bank:BANK_VECTOR,addr:32'd0} && ffn_descriptor.layer_param_base==base);end
        end
        if(pending[c] && !valid_reply[c]) begin
          if(!delay_q[c]) valid_reply[c]<=1;else delay_q[c]<=0;end
        if(valid_reply[c] && rsp_ready[c]) begin pending[c]<=0;valid_reply[c]<=0;
          if(fault_q[c]) fault_seen<=1;else ordinal<=ordinal+1;end
      end
      if(command.rsp_valid) begin
        assert(pending==0 && !layer_call.rsp_valid);
        if(fault_seen || CASE==3) assert(command.rsp_error &&
          (command.rsp_status.protocol_error || command.rsp_status.numeric_error));
        else begin assert(!command.rsp_error && expected_layer==3);
          assert(command.rsp_status.rounded && command.rsp_status.saturated);end
        if(command.rsp_ready) begin
          if(CASE==0 && !run_q) begin run_q<=1;sent<=0;end else test_done<=1;
        end
      end
      if(test_done && (fault_seen || CASE==3)) assert(!command.cmd_ready && cmd_valid==0 && !encoder_layer.cmd_valid);
      if(command.rsp_valid && !command.rsp_ready || |(cmd_valid & ~cmd_ready)) saw_stall<=1;
      if(past_valid && !$past(rst)) begin
        if($past(encoder_layer.cmd_valid && !encoder_layer.cmd_ready)) assert(encoder_layer.cmd_valid && encoder_layer.cmd==$past(encoder_layer.cmd));
        if($past(norm.cmd_valid && !norm.cmd_ready)) assert(norm.cmd_valid && norm.cmd==$past(norm.cmd));
        if($past(attention.cmd_valid && !attention.cmd_ready)) assert(attention.cmd_valid && attention.cmd==$past(attention.cmd));
        if($past(residual.cmd_valid && !residual.cmd_ready)) assert(residual.cmd_valid && residual.cmd==$past(residual.cmd));
        if($past(ffn.cmd_valid && !ffn.cmd_ready)) assert(ffn.cmd_valid && ffn.cmd==$past(ffn.cmd));
        if($past(command.rsp_valid && !command.rsp_ready)) assert(command.rsp_valid &&
          {command.rsp_error,command.rsp_status}==$past({command.rsp_error,command.rsp_status}));
      end
    end
  end
endmodule
