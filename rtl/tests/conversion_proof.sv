// Independent magnitude-based definition versus the production floor/remainder converter.
module conversion_proof #(parameter int WIDTH=48,SHIFT=10)(
  input logic signed [WIDTH-1:0] x,output logic correct);
  import bcjrformer_contract_pkg::*;import fixed_math_pkg::*;
  conversion_t result;
  logic [WIDTH:0] magnitude,quotient;
  logic signed [WIDTH+1:0] rounded;
  logic signed [15:0] clipped;
  logic saturated;
  localparam logic [SHIFT-1:0] HALF=SHIFT'(1)<<(SHIFT-1);
  always_comb begin
    result=convert(wide_t'(x),SHIFT,16,1,1);
    magnitude=x<0 ? (WIDTH+1)'(-(WIDTH+2)'(x)):(WIDTH+1)'(x);
    quotient=magnitude>>SHIFT;
    if(magnitude[SHIFT-1:0]>HALF || (magnitude[SHIFT-1:0]==HALF && quotient[0])) quotient=quotient+1;
    rounded=x<0 ? -(WIDTH+2)'({1'b0,quotient}):(WIDTH+2)'({1'b0,quotient});
    saturated=rounded< -32768 || rounded>32767;
    clipped=rounded< -32768 ? 16'sh8000:rounded>32767 ? 16'sd32767:16'(rounded);
    correct=result.value==wide_t'(clipped) && result.status.saturated==saturated &&
      result.status.rounded==(magnitude[SHIFT-1:0]!=0) && !result.status.protocol_error && !result.status.numeric_error;
  end
endmodule
