// Independent control scoreboard; memory/norm/linear/add services are test-only.
module stage12_control_formal #(parameter int MODE=0,CASE=0,
  parameter longint unsigned TEST_M=2,TEST_N=2,TEST_D=2)(
  input logic clk, memory_go, service_go, response_go, finish_check,
  output logic test_done=0,saw_stall=0,saw_reset=0
);
  import bcjrformer_contract_pkg::*;
  bcjr_cmd_if #(empty_t,empty_t) command();
  bcjr_cmd_if #(layernorm_cmd_t,empty_t) norm();
  bcjr_cmd_if #(linear_cmd_t,empty_t) linear();
  bcjr_arith_if #(position_add_req_t,act_t) addition();
  bcjr_mem_if mem();
  logic past_valid=0,reset_trigger=0,reset_done=0,rst;
  logic sent,run_index;
  logic [2:0] phase;
  logic token;
  logic [1:0] element;
  logic [3:0] scalar_index;
  logic write_next;
  logic memory_pending,memory_response,memory_delay,memory_fault;
  mem_req_t memory_request;
  mem_data_t memory_data;
  logic norm_pending,norm_response,norm_delay,norm_second;
  logic linear_pending,linear_response,linear_delay;
  logic add_pending,add_response,add_delay;
  act_t add_result;
  layernorm_cmd_t norm_request;
  linear_cmd_t linear_request;
  position_add_req_t add_request;
  logic fault_observed;
  logic [31:0] p_offset,e_offset;
  assign rst=!past_valid || reset_trigger;
  generate if(MODE==0) begin : embedding
    embedding_ctrl #(.F(2),.D(3),.TOKENS(2),.GAMMA_F_BASE(10),.BETA_F_BASE(20),
      .WEIGHT_BASE(30),.BIAS_BASE(40),.GAMMA_D_BASE(50),.BETA_D_BASE(60))
      dut(clk,rst,command,norm,linear,mem);
    assign addition.req_valid=0; assign addition.req='0;
    assign addition.req_tag=0; assign addition.rsp_ready=0;
  end else begin : position
    position_sequencer #(.M(TEST_M),.N(TEST_N),.D(TEST_D),.POSITION_BASE(100),.READ_BASE(200))
      dut(clk,rst,command,mem,addition);
    assign norm.cmd_valid=0; assign norm.cmd='0; assign norm.rsp_ready=0;
    assign linear.cmd_valid=0; assign linear.cmd='0; assign linear.rsp_ready=0;
  end endgenerate
  assign command.cmd_valid=!sent && !test_done;
  assign command.cmd=CASE==4;
  assign command.rsp_ready=response_go;
  assign mem.req_ready=memory_go && !memory_pending && !rst;
  assign mem.rsp_valid=memory_response && !rst;
  assign mem.rsp_rdata=memory_data;
  assign mem.rsp_error=memory_fault;
  assign norm.cmd_ready=service_go && !norm_pending && !rst;
  assign norm.rsp_valid=norm_response && !rst;
  assign norm.rsp='0;
  assign norm.rsp_error=CASE==3;
  assign norm.rsp_status='{protocol_error:0,numeric_error:CASE==3,saturated:0,rounded:1};
  assign linear.cmd_ready=service_go && !linear_pending && !rst;
  assign linear.rsp_valid=linear_response && !rst;
  assign linear.rsp='0;
  assign linear.rsp_error=CASE==7 || CASE==9;
  assign linear.rsp_status='{protocol_error:0,numeric_error:CASE==9,saturated:1,rounded:0};
  assign addition.req_ready=service_go && !add_pending && !rst;
  assign addition.rsp_valid=add_response && !rst;
  assign addition.rsp=add_result;
  assign addition.rsp_tag=CASE==7 ? 8'd1:8'd0;
  assign addition.rsp_error=CASE==3;
  assign addition.rsp_status='{protocol_error:0,numeric_error:CASE==3,saturated:1,rounded:1};
  assign p_offset=32'((64'(scalar_index)/TEST_D%TEST_N)*TEST_D+64'(scalar_index)%TEST_D);
  assign e_offset=32'((64'(scalar_index)/(TEST_N*TEST_D))*TEST_D+64'(scalar_index)%TEST_D);
  always @(posedge clk) begin
    past_valid<=1; reset_trigger<=0;
    if(reset_trigger) begin reset_done<=1; saw_reset<=1; end
    if(!rst && !reset_done && (CASE==5 && memory_pending ||
      CASE==6 && (norm_pending || add_pending))) reset_trigger<=1;
    if(rst) begin
      sent<=0;run_index<=0;phase<=0;token<=0;element<=0;scalar_index<=0;write_next<=0;
      memory_pending<=0;memory_response<=0;memory_delay<=0;memory_fault<=0;
      memory_request<='0;memory_data<='0;norm_pending<=0;norm_response<=0;norm_delay<=0;norm_second<=0;
      linear_pending<=0;linear_response<=0;linear_delay<=0;
      add_pending<=0;add_response<=0;add_delay<=0;add_result<='0;fault_observed<=0;test_done<=0;
      assert(!command.cmd_ready && !command.rsp_valid && !mem.req_valid && !mem.rsp_ready);
      assert(!norm.cmd_valid && !linear.cmd_valid && !addition.req_valid);
    end else begin
      if(finish_check) assert(test_done);
      if(command.cmd_valid && command.cmd_ready) begin
        sent<=1; phase<=0;token<=0;element<=0;scalar_index<=0;write_next<=0;fault_observed<=0;
      end
      if(mem.req_valid && mem.req_ready) begin
        assert(sent && !memory_pending && !norm_pending && !linear_pending && !add_pending);
        assert(mem.req.format==FMT_S16_F10 && mem.req.wdata[95:16]==0);
        memory_pending<=1;memory_delay<=1;memory_request<=mem.req;
        memory_fault<=CASE==1 || CASE==2 && mem.req.write || MODE==1 && CASE==9 && phase==3;
        if(MODE==0) begin
          assert(phase==0 || phase==4);
          assert(mem.req.write==write_next);
          if(phase==0) begin
            assert(mem.req.bank==(write_next ? BANK_TOKEN:BANK_FEATURE));
            assert(mem.req.addr==(write_next ? 32'(element):32'(token)*2+32'(element)));
            if(write_next) assert(mem.req.wdata[15:0]==16'(-1-32'(token)*2-32'(element)));
            memory_data<=96'(-1-$signed(32'(mem.req.addr)));
          end else begin
            assert(mem.req.bank==(write_next ? BANK_X:BANK_VECTOR));
            assert(mem.req.addr==(write_next ? 32'(token)*3+32'(element):32'(element)));
            if(write_next) assert(mem.req.wdata[15:0]==16'(100+32'(token)*8+32'(element)));
            memory_data<=96'(100+32'(token)*8+32'(element));
          end
        end else begin
          assert(phase==0 || phase==1 || phase==3 || phase==5);
          assert(mem.req.write==(phase==5));
          assert(mem.req.bank==(phase==1 || phase==3 ? BANK_PARAM:BANK_X));
          assert(mem.req.addr==(phase==1 ? 100+p_offset:phase==3 ? 200+e_offset:32'(scalar_index)));
          if(phase==5) assert(mem.req.wdata[15:0]==16'(43+32'(scalar_index)+p_offset+e_offset));
          memory_data<=phase==1 ? 96'(10+p_offset):phase==3 ? 96'(30+e_offset):96'(3+32'(scalar_index));
        end
        if(!mem.req.write) assert(mem.req.wdata==0);
      end
      if(memory_pending && !memory_response) begin
        if(!memory_delay) memory_response<=1;else memory_delay<=0;
      end
      if(mem.rsp_valid && mem.rsp_ready) begin
        memory_pending<=0;memory_response<=0;
        if(memory_fault) fault_observed<=1;
        else if(MODE==0) begin
          if(!write_next) write_next<=1;
          else begin write_next<=0;
            if(element==(phase==0 ? 1:2)) begin element<=0;
              if(phase==0) phase<=1;
              else if(token) phase<=5;
              else begin token<=1;phase<=0;end
            end else element<=element+1;
          end
        end else if(phase==5) begin
          if(64'(scalar_index)==TEST_M*TEST_N*TEST_D-1) phase<=6;
          else begin scalar_index<=scalar_index+1;phase<=0;end
        end else phase<=phase+1;
      end
      if(norm.cmd_valid && norm.cmd_ready) begin
        assert(MODE==0 && (phase==1 || phase==3) && !memory_pending && !linear_pending);
        norm_request=layernorm_cmd_t'(norm.cmd);
        assert(norm_request.length==(phase==1 ? 2:3));
        assert(norm_request.src.bank==(phase==1 ? BANK_TOKEN:BANK_VECTOR));
        assert(norm_request.dst==norm_request.src && norm_request.src.addr==0);
        assert(norm_request.gamma_base==(phase==1 ? 10:50) && norm_request.beta_base==(phase==1 ? 20:60));
        norm_second<=phase==3;norm_pending<=1;norm_delay<=1;
      end
      if(norm_pending && !norm_response) begin if(!norm_delay) norm_response<=1;else norm_delay<=0;end
      if(norm.rsp_valid && norm.rsp_ready) begin norm_pending<=0;norm_response<=0;
        if(norm.rsp_error) fault_observed<=1;else phase<=norm_second ? 4:2;
      end
      if(linear.cmd_valid && linear.cmd_ready) begin
        assert(MODE==0 && phase==2 && !norm_pending && !memory_pending);
        linear_request=linear_cmd_t'(linear.cmd);
        assert(linear_request.in_count==2 && linear_request.out_count==3);
        assert(linear_request.src==ptr_t'{bank:BANK_TOKEN,addr:32'd0});
        assert(linear_request.dst==ptr_t'{bank:BANK_VECTOR,addr:32'd0});
        assert(linear_request.weight_base==30 && linear_request.bias_base==40);
        linear_pending<=1;linear_delay<=1;
      end
      if(linear_pending && !linear_response) begin if(!linear_delay) linear_response<=1;else linear_delay<=0;end
      if(linear.rsp_valid && linear.rsp_ready) begin linear_pending<=0;linear_response<=0;
        if(linear.rsp_error) fault_observed<=1;else phase<=3;
      end
      if(addition.req_valid && addition.req_ready) begin
        assert(MODE==1 && (phase==2 || phase==4) && !memory_pending);
        add_request=position_add_req_t'(addition.req);
        assert(addition.req_tag==0);
        assert(add_request.left==16'(3+32'(scalar_index)+(phase==4 ? 10+p_offset:0)));
        assert(add_request.right==16'(phase==2 ? 10+p_offset:30+e_offset));
        // Test-only exact small addition. No production conversion method is selected.
        add_result<=act_t'(add_request.left+add_request.right);add_pending<=1;add_delay<=1;
      end
      if(add_pending && !add_response) begin if(!add_delay) add_response<=1;else add_delay<=0;end
      if(addition.rsp_valid && addition.rsp_ready) begin add_pending<=0;add_response<=0;
        if(addition.rsp_error || addition.rsp_tag!=0) fault_observed<=1;else phase<=phase+1;
      end
      if(command.rsp_valid) begin
        assert(sent && !memory_pending && !norm_pending && !linear_pending && !add_pending);
        if(CASE==4 || fault_observed) begin
          assert(command.rsp_error && (command.rsp_status.protocol_error || command.rsp_status.numeric_error));
        end else begin
          assert(phase==(MODE==0 ? 5:6));
          assert(!command.rsp_error && command.rsp_status.saturated && command.rsp_status.rounded);
        end
        if(command.rsp_ready) begin
          if((CASE==0 || CASE==8) && !run_index) begin run_index<=1;sent<=0;end
          else test_done<=1;
        end
      end
      if(test_done && (CASE==4 || fault_observed)) assert(!command.cmd_ready && !mem.req_valid &&
        !norm.cmd_valid && !linear.cmd_valid && !addition.req_valid);
      if(mem.req_valid && !mem.req_ready || command.rsp_valid && !command.rsp_ready ||
        norm.cmd_valid && !norm.cmd_ready || linear.cmd_valid && !linear.cmd_ready ||
        addition.req_valid && !addition.req_ready) saw_stall<=1;
      if(past_valid && !$past(rst)) begin
        if($past(mem.req_valid && !mem.req_ready)) assert(mem.req_valid && mem.req==$past(mem.req));
        if($past(norm.cmd_valid && !norm.cmd_ready)) assert(norm.cmd_valid && norm.cmd==$past(norm.cmd));
        if($past(linear.cmd_valid && !linear.cmd_ready)) assert(linear.cmd_valid && linear.cmd==$past(linear.cmd));
        if($past(addition.req_valid && !addition.req_ready)) assert(addition.req_valid &&
          {addition.req,addition.req_tag}==$past({addition.req,addition.req_tag}));
        if($past(command.rsp_valid && !command.rsp_ready)) assert(command.rsp_valid &&
          {command.rsp,command.rsp_error,command.rsp_status}==$past({command.rsp,command.rsp_error,command.rsp_status}));
        if($past(command.cmd_valid && command.cmd_ready)) assert(command.rsp_status==0 || CASE==4);
      end
    end
  end
endmodule
