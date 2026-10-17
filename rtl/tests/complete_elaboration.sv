// Multiple complete assemblies, not selected trained-model configurations.
module complete_elaboration;
  logic clk,rst;
  bcjr_host_if #(.INDEX_W(1)) single_host();
  bcjr_host_if #(.INDEX_W(2)) multi_host();
  bcjrformer_core #(.F(1),.M(1),.N(1),.D(1),.H(1),.K(1)) single(clk,rst,single_host);
  bcjrformer_core #(.F(2),.M(2),.N(3),.D(6),.H(3),.K(2),.MEMORY_DELAY(3)) multiple(clk,rst,multi_host);
endmodule
