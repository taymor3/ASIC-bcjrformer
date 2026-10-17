// Interface draft only. Numerical formats require calibration.
// Compile this package before the interfaces and declaration-only .svh file.
package bcjrformer_contract_pkg;
  // Integration choice, not a selected model dimension. Regenerate/change this
  // constant if any bank or parameter image cannot fit a 32-bit word address.
  parameter int unsigned ADDR_W = 32;
  typedef logic [ADDR_W-1:0] addr_t;
  typedef logic [15:0] count_t;
  typedef logic signed [15:0] act_t;       // signed 16, 10 fractional bits
  typedef logic signed [31:0] gelu_t;      // signed32/F22 Taylor function result
  typedef logic signed [47:0] score_t;     // signed 48, 20 fractional bits
  typedef logic [23:0] probability_t;      // unsigned 24, 22 fractional bits
  typedef logic signed [63:0] accum_t;     // mode selects fractional bits
  typedef logic [63:0] denominator_t;      // unsigned 64, 22 fractional bits
  typedef logic [39:0] reciprocal_t;       // unsigned 40, 32 fractional bits
  typedef logic [47:0] variance_t;         // unsigned 48, 32 fractional bits
  localparam variance_t NORMALIZATION_MINIMUM = 48'd42950;
  typedef logic [31:0] rsqrt_t;            // unsigned 32, 20 fractional bits
  typedef logic [95:0] mem_data_t;
  typedef logic empty_t;                  // reserved payload, always zero

  // Internal Stage 2 add/convert request; not a new top-level shared service.
  // act_t remains provisional; the numerical datapath is still deferred.
  typedef struct packed { act_t left; act_t right; } position_add_req_t;

  typedef struct packed {
    logic protocol_error; // fatal: illegal descriptor, bank, address or packet
    logic numeric_error;  // fatal: overflow or arithmetic domain error
    logic saturated;      // nonfatal: clipping occurred
    logic rounded;        // nonfatal: conversion changed represented value
  } status_t;

  // Proposed Phase-1 control contract; independent of arithmetic calibration.
  typedef enum logic [1:0] {
    COMPLETION_OK = 2'd0,
    COMPLETION_EMPTY_POSITION = 2'd1, // recoverable; parameters retained
    COMPLETION_FATAL = 2'd2          // drain/report, then reset required
  } completion_code_t;
  typedef struct packed {
    completion_code_t code;
    count_t position; // meaningful only for COMPLETION_EMPTY_POSITION
  } aggregation_rsp_t;

  // Logical bank IDs are an explicit new interface encoding, not SRAM macros.
  typedef enum logic [4:0] {
    BANK_PARAM = 5'd0, BANK_FEATURE = 5'd1, BANK_MASK = 5'd2,
    BANK_X = 5'd3, BANK_U = 5'd4, BANK_Q = 5'd5, BANK_KEY = 5'd6,
    BANK_VALUE = 5'd7, BANK_Z = 5'd8, BANK_ATTN_OUT = 5'd9,
    BANK_TOKEN = 5'd10, BANK_FFN_HIDDEN = 5'd11,
    BANK_VECTOR = 5'd12, BANK_SCORE = 5'd13, BANK_EXP = 5'd14,
    BANK_PROB = 5'd15, BANK_LOGIT = 5'd16, BANK_OUTPUT = 5'd17
  } bank_t;
  typedef enum logic [1:0] {
    FMT_S16_F10 = 2'd0, FMT_BIT = 2'd1,
    FMT_S48_F20 = 2'd2, FMT_U24_F22 = 2'd3
  } mem_format_t;
  typedef struct packed { bank_t bank; addr_t addr; } ptr_t;
  typedef struct packed {
    logic write;
    bank_t bank;
    addr_t addr;          // native elements, never byte addresses
    mem_format_t format;
    mem_data_t wdata;     // valid low bits; ALL unused high bits zero
  } mem_req_t;

  typedef struct packed {
    count_t layer_index;
    addr_t layer_param_base;
  } layer_cmd_t;
  typedef struct packed {
    count_t length;
    ptr_t src;
    ptr_t dst;
    addr_t gamma_base;
    addr_t beta_base;
  } layernorm_cmd_t;
  typedef struct packed {
    count_t in_count;
    count_t out_count;
    ptr_t src;
    ptr_t dst;
    addr_t weight_base;
    addr_t bias_base;
  } linear_cmd_t;
  typedef struct packed {
    count_t length;
    ptr_t left;
    ptr_t right;
    ptr_t dst;
  } residual_cmd_t;
  typedef struct packed { count_t head_index; count_t query_index; } row_cmd_t;
  typedef struct packed { logic padded_query; } softmax_cmd_t;
  typedef struct packed {
    ptr_t src;
    ptr_t dst;
    addr_t layer_param_base;
  } ffn_cmd_t;
  typedef enum logic {
    DOT_S16_S16 = 1'b0,   // signed48/F20 range; sign extended to physical 64
    DOT_U24_S16 = 1'b1    // signed64/F32 range
  } dot_mode_t;
  typedef struct packed {
    count_t length;
    ptr_t a;
    addr_t a_stride;
    ptr_t b;
    addr_t b_stride;
    dot_mode_t mode;
    accum_t acc_init;
  } dot_cmd_t;
  typedef struct packed {
    dot_mode_t mode;
    logic [23:0] a;       // mode 0: signed a[15:0], a[23:16]=0
    act_t b;             // mode 1: A is unsigned full 24 bits
    accum_t acc;
  } mac_req_t;
endpackage
