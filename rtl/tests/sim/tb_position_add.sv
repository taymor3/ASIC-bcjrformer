// Small lab bring-up: actual saturating adder and registered ready/valid boundary.
module tb_position_add;
  timeunit 1ns;
  timeprecision 1ps;
  import bcjrformer_contract_pkg::*;

  logic clk = 0;
  logic rst = 1;
  bcjr_arith_if #(position_add_req_t, act_t) operation();
  position_add_unit dut(clk, rst, operation);
  int passed = 0;
  bit inject_mismatch;

  always #5ns clk = ~clk;

  task automatic check_response(input act_t expected, input status_t flags,
                                input logic [7:0] tag);
    if (operation.rsp_valid !== 1'b1 || operation.rsp !== expected ||
        operation.rsp_status !== flags || operation.rsp_tag !== tag ||
        operation.rsp_error !== 1'b0)
      $fatal(1, "FAIL case=%0d expected=%0d actual=%0d valid=%b status=%b expected_status=%b tag=%h expected_tag=%h error=%b",
             passed, expected, operation.rsp, operation.rsp_valid,
             operation.rsp_status, flags, operation.rsp_tag, tag,
             operation.rsp_error);
  endtask

  task automatic addition_case(input int left_value, input int right_value,
                               input int expected_value, input bit saturated,
                               input int stall_cycles);
    act_t expected;
    status_t flags;
    logic [7:0] tag;
    flags = '0;
    flags.saturated = saturated;
    expected = act_t'(expected_value);
    tag = 8'(passed + 1);
    if (inject_mismatch && passed == 0) expected = expected + 16'sd1;

    // Drive on falling edges, accept at rising edges, inspect after NBA updates.
    @(negedge clk);
    operation.req = '{left:act_t'(left_value), right:act_t'(right_value)};
    operation.req_tag = tag;
    operation.req_valid = 1;
    operation.rsp_ready = 0;
    do @(posedge clk); while (operation.req_ready !== 1'b1);
    @(negedge clk);
    operation.req_valid = 0;
    // Changing request pins must not change the already captured response.
    operation.req = '0;
    operation.req_tag = '0;
    check_response(expected, flags, tag);
    repeat (stall_cycles) begin
      if (operation.req_ready !== 1'b0)
        $fatal(1, "FAIL: accepted-operation slot was not retained during response stall");
      @(negedge clk);
      check_response(expected, flags, tag);
    end
    operation.rsp_ready = 1;
    @(posedge clk);
    @(negedge clk);
    operation.rsp_ready = 0;
    if (operation.rsp_valid !== 1'b0 || operation.req_ready !== 1'b1)
      $fatal(1, "FAIL: response duplicated or unit did not become ready");
    passed++;
    $display("PASS add: raw %0d + %0d -> %0d; saturated=%0b; stall=%0d",
             left_value, right_value, expected_value, saturated, stall_cycles);
  endtask

  task automatic reset_pending_case;
    @(negedge clk);
    operation.req = '{left:16'sd1024, right:16'sd2048};
    operation.req_tag = 8'hA5;
    operation.req_valid = 1;
    operation.rsp_ready = 0;
    do @(posedge clk); while (operation.req_ready !== 1'b1);
    @(negedge clk);
    operation.req_valid = 0;
    if (operation.rsp_valid !== 1'b1)
      $fatal(1, "FAIL: reset scenario did not reach a pending response");
    rst = 1;
    @(posedge clk);
    #1ns;
    if (operation.rsp_valid !== 1'b0 || operation.req_ready !== 1'b0)
      $fatal(1, "FAIL: interface active during reset");
    @(negedge clk);
    rst = 0;
    repeat (2) begin
      @(negedge clk);
      if (operation.rsp_valid !== 1'b0 || operation.req_ready !== 1'b1)
        $fatal(1, "FAIL: stale response or lost readiness after reset");
    end
    $display("PASS reset: pending response canceled");
  endtask

  initial begin
    operation.req_valid = 0;
    operation.req = '0;
    operation.req_tag = '0;
    operation.rsp_ready = 0;
    inject_mismatch = $test$plusargs("INJECT_MISMATCH");
    if ($test$plusargs("WAVES")) begin
      $dumpfile("position_add.vcd");
      $dumpvars(0, tb_position_add);
    end
    repeat (3) @(posedge clk);
    @(negedge clk);
    rst = 0;
    addition_case(0, 0, 0, 0, 0);
    addition_case(1024, 2048, 3072, 0, 0); // 1.0 + 2.0 = 3.0
    addition_case(-1024, 256, -768, 0, 2); // -1.0 + 0.25 = -0.75
    addition_case(32767, 0, 32767, 0, 1);
    addition_case(-32768, 0, -32768, 0, 1);
    addition_case(32767, 1, 32767, 1, 3);
    addition_case(-32768, -1, -32768, 1, 3);
    addition_case(32767, -32768, -1, 0, 0);
    reset_pending_case();
    addition_case(512, 512, 1024, 0, 0); // Verify reuse after reset.
    $display("PASS tb_position_add: %0d additions, stalls, flags, tags and reset checked", passed);
    $finish;
  end

  initial begin
    #100us;
    $fatal(1, "FAIL tb_position_add: watchdog timeout");
  end
endmodule
