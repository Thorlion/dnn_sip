// Draft convolution DALU matching the three input muxes, MULT and ACC.
// All operands/results are signed fixed point with DECIMAL_BIT fractional bits.
// Defaults match the existing MAC: 16-bit data, 8 fractional bits.
// Parameter range: DATA_W >= 2, 0 <= DECIMAL_BIT <= DATA_W-2 (unity must fit).
//
// Multiplier input 1: i_mult_sel_1 = 0: zero, 1: MLI.
// Multiplier input 2: i_mult_sel_2 = 0: fixed-point unity, 1: MLK.
// Accumulator input: i_acc_sel = 00: zero, 01: MLO, 10: EOA, 11: SEOA.
//
// Product scaling discards fractional low bits and overflowing high bits.
// The addition wraps to DATA_W bits, matching the existing MAC arithmetic.
// This is combinational; EOA/SEOA registers and their enables are external.
module dalu #(
    parameter int unsigned DATA_W = 16,
    parameter int unsigned DECIMAL_BIT = 8
)(
    input  logic                         i_mult_sel_1,
    input  logic                         i_mult_sel_2,
    input  logic [1:0]                   i_acc_sel,

    input  logic signed [DATA_W-1:0]     i_mli_out,
    input  logic signed [DATA_W-1:0]     i_mlk_out,
    input  logic signed [DATA_W-1:0]     i_mlo_out,
    input  logic signed [DATA_W-1:0]     i_eoa_out,
    input  logic signed [DATA_W-1:0]     i_seoa, // unused in this design?

    output logic signed [DATA_W-1:0]     o_acc_result
);
    // Encode real-number 1.0 in the same format as the kernel operand.
    localparam logic signed [DATA_W-1:0] FIXED_ONE = 1 << DECIMAL_BIT;

    logic signed [DATA_W-1:0] w_mult_operand_1;
    logic signed [DATA_W-1:0] w_mult_operand_2;
    logic signed [DATA_W-1:0] w_acc_operand;
    logic signed [2*DATA_W-1:0] w_product;
    logic signed [DATA_W-1:0] w_scaled_product;

    assign w_mult_operand_1 = i_mult_sel_1 ? i_mli_out : '0;
    assign w_mult_operand_2 = i_mult_sel_2 ? i_mlk_out : FIXED_ONE;

    always_comb begin
        case (i_acc_sel)
            2'b00: w_acc_operand = '0;
            2'b01: w_acc_operand = i_mlo_out;
            2'b10: w_acc_operand = i_eoa_out;
            2'b11: w_acc_operand = i_seoa;
            default: w_acc_operand = '0;
        endcase
    end

    assign w_product = w_mult_operand_1 * w_mult_operand_2;
    assign w_scaled_product = w_product[DECIMAL_BIT +: DATA_W];
    assign o_acc_result = w_scaled_product + w_acc_operand;
endmodule
