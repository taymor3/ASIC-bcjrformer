// Provisional numerical baseline: nearest-even conversion and explicit flags.
package fixed_math_pkg;
  import bcjrformer_contract_pkg::*;
  typedef logic signed [159:0] wide_t;
  typedef struct packed {wide_t value; status_t status;} conversion_t;
  function automatic conversion_t convert(wide_t x,int shift,int width,bit signed_output,bit clip);
    wide_t q,remainder,half,minimum,maximum;
    conversion_t r;
    r='0; q=x;
    if(shift>0) begin
      q=x>>>shift; remainder=x-(q<<<shift); half=160'sd1<<<(shift-1);
      r.status.rounded=remainder!=0;
      if(remainder>half || (remainder==half && q[0])) q=q+1;
    end
    minimum=signed_output ? -(160'sd1<<<(width-1)):160'sd0;
    maximum=(160'sd1<<<(signed_output ? width-1:width))-1;
    if(q<minimum || q>maximum) begin
      if(clip) begin r.status.saturated=1; q=q<minimum ? minimum:maximum; end
      else r.status.numeric_error=1;
    end
    r.value=q; return r;
  endfunction
  function automatic logic fatal(status_t s); return s.protocol_error || s.numeric_error; endfunction
  function automatic status_t child_status(status_t s,bit error,bit tag_error=0);
    status_t result;
    result=s;
    if(tag_error || (error && !fatal(s))) result.protocol_error=1;
    return result;
  endfunction
  function automatic bit act_bank(bank_t b);
    return b==BANK_PARAM || b==BANK_FEATURE || b==BANK_X || b==BANK_U ||
      b==BANK_Q || b==BANK_KEY || b==BANK_VALUE || b==BANK_Z || b==BANK_ATTN_OUT ||
      b==BANK_TOKEN || b==BANK_FFN_HIDDEN || b==BANK_VECTOR || b==BANK_LOGIT || b==BANK_OUTPUT;
  endfunction
  function automatic bit act_destination(bank_t b); return act_bank(b) && b!=BANK_PARAM; endfunction
  function automatic bit extent(addr_t base,logic [63:0] length);
    return length!=0 && 64'(base)+length<=(64'd1<<ADDR_W);
  endfunction
  function automatic bit overlap(ptr_t a,logic [63:0] an,ptr_t b,logic [63:0] bn);
    return a.bank==b.bank && 64'(a.addr)<64'(b.addr)+bn && 64'(b.addr)<64'(a.addr)+an;
  endfunction
  function automatic logic [39:0] inverse_count(logic [63:0] n);
    logic [63:0] q,r;
    if(n==0) return 0;
    q=(64'd1<<32)/n; r=(64'd1<<32)%n;
    if(2*r>n || (2*r==n && q[0])) q=q+1;
    return 40'(q);
  endfunction
  function automatic probability_t uniform_probability(logic [63:0] n);
    logic [63:0] q,r;
    if(n==0) return 0;
    q=(64'd1<<22)/n;r=(64'd1<<22)%n;
    if(2*r>n || (2*r==n && q[0])) q=q+1;
    return probability_t'(q);
  endfunction
  function automatic logic [31:0] head_scale(logic [63:0] n);
    logic [63:0] q,root,candidate;
    wide_t midpoint;
    if(n==0) return 0;
    q=(64'd1<<60)/n;root=0;
    for(int i=31;i>=0;i--) begin
      candidate=root | (64'd1<<i);
      if(candidate*candidate<=q) root=candidate;
    end
    midpoint=wide_t'({1'b0,n})*(2*wide_t'({1'b0,root})+1)*(2*wide_t'({1'b0,root})+1);
    if(midpoint<(160'sd1<<62) || (midpoint==(160'sd1<<62) && root[0])) root=root+1;
    return 32'(root);
  endfunction
endpackage
