// Independent magnitude-based definition versus the production floor/remainder converter.
module conversion_proof(input logic signed [47:0] x,output logic correct);
  import bcjrformer_contract_pkg::*;import fixed_math_pkg::*;
  conversion_t result;
  logic [48:0] magnitude,quotient;
  logic signed [49:0] rounded;
  logic signed [15:0] clipped;
  logic saturated;
  always_comb begin
    result=convert(wide_t'(x),10,16,1,1);
    magnitude=x<0 ? 49'(-50'(x)):49'(x);
    quotient=magnitude>>10;
    if(magnitude[9:0]>512 || (magnitude[9:0]==512 && quotient[0])) quotient=quotient+1;
    rounded=x<0 ? -50'({1'b0,quotient}):50'({1'b0,quotient});
    saturated=rounded< -32768 || rounded>32767;
    clipped=rounded< -32768 ? -16'sd32768:rounded>32767 ? 16'sd32767:16'(rounded);
    correct=result.value==wide_t'(clipped) && result.status.saturated==saturated &&
      result.status.rounded==(magnitude[9:0]!=0) && !result.status.protocol_error && !result.status.numeric_error;
  end
endmodule
