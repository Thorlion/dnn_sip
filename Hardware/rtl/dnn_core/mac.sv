module mac #(
    parameter DATA_W = 16,
    parameter DECIMAL_BIT = 8       // Number of decimal bits
)(
    input  logic signed [1:0]           mult_sel_1,         // SELECT AMONG 0, LOCAL INPUT AND BROADCAST INPUT
    input  logic signed                 mult_sel_2,         // SELECT BETWEEN 1 AND MLKout
    input  logic signed [1:0]           acc_sel,            // SELECT AMONG 0, MLOout, EOAout, SEOAout
    
    input  logic signed [DATA_W-1:0]    MLIout,             // 16-bit fixed-point INPUT
    input  logic signed [DATA_W-1:0]    MLIout_all,         // 16-bit fixed-point INPUT
    input  logic signed [DATA_W-1:0]    MLKout,             // 16-bit fixed-point INPUT
    input  logic signed [DATA_W-1:0]    MLOout,             // 16-bit fixed-point INPUT
    input  logic signed [DATA_W-1:0]    EOAout,             // 16-bit fixed-point INPUT
    input  logic signed [DATA_W-1:0]    SEOAout,            // 16-bit fixed-point INPUT

    output logic signed [DATA_W-1:0]    acc_result          // 16-bit fixed-point OUTPUT
);
    localparam logic signed [DATA_W-1:0] FIXED_ONE = 1 << DECIMAL_BIT;
    logic signed [DATA_W-1:0]   mult_oper_1, mult_oper_2;
    logic signed [DATA_W-1:0] acc_oper;
    logic signed [DATA_W*2-1:0] acc_aligned;
    // Keep the addition at full product precision so Vivado can infer one
    // DSP multiply-add, rather than a DSP multiplier followed by a fabric adder.
    (* use_dsp = "yes" *) logic signed [DATA_W*2-1:0] mac_result;

    // Select Operands for multiplication
    always_comb begin
        // SELECT OPERAND 1 FOR MULTIPLICATION
        case (mult_sel_1)
            2'b00: mult_oper_1 = '0;                // 0
            2'b01: mult_oper_1 = MLIout;            // MLIout
            2'b10: mult_oper_1 = MLIout_all;        // Broadcast input from MLI[0]
            default: mult_oper_1 = '0;
        endcase

        // SELECT OPERAND 2 FOR MULTIPLICATION
        case (mult_sel_2)
            1'b0: mult_oper_2 = FIXED_ONE;          // Fixed-point unity
            1'b1: mult_oper_2 = MLKout;             // Lane's held weight
            default: mult_oper_2 = '0;
        endcase
    end

    // Select the existing live feedback operand; no new register or cycle is
    // introduced on the self/neighbor EOA accumulation path.
    always_comb begin
        case (acc_sel)
            2'b00: acc_oper = '0;
            2'b01: acc_oper = MLOout;
            2'b10: acc_oper = EOAout;
            2'b11: acc_oper = SEOAout;
            default: acc_oper = '0;
        endcase
    end

    always_comb begin
        // Widen before shifting: shifting a DATA_W-bit value first would lose
        // its upper bits. Adding a multiple of 2**DECIMAL_BIT does not change
        // the discarded fractional bits, preserving truncation and wraparound.
        acc_aligned = {{DATA_W{acc_oper[DATA_W-1]}}, acc_oper} << DECIMAL_BIT;
        mac_result = (mult_oper_1 * mult_oper_2) + acc_aligned;
        case (acc_sel)
            2'b00, 2'b01, 2'b10, 2'b11:
                acc_result = mac_result[DECIMAL_BIT +: DATA_W];
            default: acc_result = '0;
        endcase
    end

endmodule
