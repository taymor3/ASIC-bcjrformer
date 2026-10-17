// Synthesis preflight fixture: exercise the actual controller's interface guard.
module host_width_elaboration #(
  parameter int INDEX_W=2,
  parameter int OUTPUT_WORDS=3
)(input logic clk,rst);
  import bcjrformer_contract_pkg::*;
  bcjr_host_if #(.INDEX_W(INDEX_W)) host();
  bcjr_cmd_if #(empty_t,empty_t) embed(),position(),encoder(),final_project();
  bcjr_cmd_if #(empty_t,aggregation_rsp_t) aggregate();
  bcjr_mem_if mem();
  core_ctrl #(.PARAM_WORDS(1),.FEATURE_WORDS(1),.MASK_WORDS(1),.OUTPUT_WORDS(OUTPUT_WORDS))
    dut(clk,rst,host,embed,position,encoder,final_project,aggregate,mem);
endmodule
