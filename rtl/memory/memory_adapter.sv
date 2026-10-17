// Behavioral native-width backing storage. Replace behind this interface for SRAM.
module memory_adapter #(
  parameter bit PARAMETER_ONLY = 1'b0,
  parameter longint unsigned BANK_DEPTHS [18] = '{default:0},
  parameter int unsigned RESPONSE_DELAY = 1
)(input logic clk, rst, bcjr_mem_if.responder access);
  import bcjrformer_contract_pkg::*;
  typedef enum logic [1:0] {IDLE, WAIT_ACCESS, RESPONSE} state_t;
  state_t state;
  mem_req_t request_q;
  mem_data_t result_q, bank_read [18];
  logic error_q, legal, commit_write, write_bits_ok;
  localparam int DELAY_W = RESPONSE_DELAY>1 ? $clog2(RESPONSE_DELAY) : 1;
  logic [DELAY_W-1:0] delay_q;
  mem_format_t expected_format;
  always_comb begin
    write_bits_ok=request_q.wdata[95:16]=='0; expected_format=FMT_S16_F10;
    case (request_q.bank)
      BANK_MASK: begin write_bits_ok=request_q.wdata[95:1]=='0; expected_format=FMT_BIT; end
      BANK_SCORE: begin write_bits_ok=request_q.wdata[95:48]=='0; expected_format=FMT_S48_F20; end
      BANK_EXP, BANK_PROB: begin write_bits_ok=request_q.wdata[95:24]=='0; expected_format=FMT_U24_F22; end
      default: ;
    endcase
    legal=1'b0;
    if (int'(request_q.bank)<=int'(BANK_OUTPUT))
      legal=(64'(request_q.addr)<BANK_DEPTHS[int'(request_q.bank)]) &&
            (request_q.format==expected_format) &&
            (PARAMETER_ONLY ? request_q.bank==BANK_PARAM : request_q.bank!=BANK_PARAM);
    if (request_q.write && !write_bits_ok) legal=1'b0;
    commit_write=!rst && state==WAIT_ACCESS && delay_q==0 && legal && request_q.write;
    access.req_ready=!rst && state==IDLE;
    access.rsp_valid=!rst && state==RESPONSE;
    access.rsp_error=error_q;
    access.rsp_rdata=result_q;
  end
  for(genvar b=0;b<18;b++) begin : banks
    localparam int WIDTH = b==2 ? 1 : b==13 ? 48 : (b==14 || b==15) ? 24 : 16;
    localparam bit SIGNED_BANK = !(b==2 || b==14 || b==15);
    localparam bit ENABLED = BANK_DEPTHS[b]>0 && (PARAMETER_ONLY ? b==0 : b!=0);
    if(ENABLED) begin : storage
      localparam int INDEX_W = BANK_DEPTHS[b]>1 ? $clog2(BANK_DEPTHS[b]) : 1;
      logic [WIDTH-1:0] words [BANK_DEPTHS[b]];
      wire [INDEX_W-1:0] index = INDEX_W'(request_q.addr);
      wire [WIDTH-1:0] value = words[index];
      if(SIGNED_BANK) assign bank_read[b]={{($bits(mem_data_t)-WIDTH){value[WIDTH-1]}},value};
      else assign bank_read[b]={{($bits(mem_data_t)-WIDTH){1'b0}},value};
      always_ff @(posedge clk)
        if(commit_write && int'(request_q.bank)==b) words[index]<=request_q.wdata[WIDTH-1:0];
    end else begin : disabled
      assign bank_read[b]='0;
    end
  end
  always_ff @(posedge clk) begin
    if(rst) begin
      state<=IDLE; request_q<='0; result_q<='0; error_q<=1'b0; delay_q<=0;
    end else begin
      case(state)
        IDLE: if(access.req_valid && access.req_ready) begin
          request_q<=access.req;
          delay_q<=DELAY_W'(RESPONSE_DELAY-1);
          state<=WAIT_ACCESS;
        end
        WAIT_ACCESS: if(delay_q!=0) delay_q<=delay_q-1;
        else begin
          error_q<=!legal;
          result_q<=legal && !request_q.write ? bank_read[int'(request_q.bank)] : '0;
          state<=RESPONSE;
        end
        RESPONSE: if(access.rsp_valid && access.rsp_ready) state<=IDLE;
        default: state<=IDLE;
      endcase
    end
  end
  initial begin
    if(RESPONSE_DELAY<1) $fatal(1,"RESPONSE_DELAY must be at least one");
    foreach(BANK_DEPTHS[b])
      if(BANK_DEPTHS[b] > (64'b1 << ADDR_W)) $fatal(1,"Bank exceeds address range");
  end
endmodule
