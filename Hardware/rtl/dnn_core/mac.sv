module mac #(
    parameter DATA_W = 16,
    parameter DECIMAL_BIT = 8       // Number of decimal bits
)(
    input  logic signed [1:0]           mult_sel_1,         // SELECT AMONG 0, MLIout AND MLOout
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
    logic signed [DATA_W-1:0]   mult_oper_1, mult_oper_2;
    logic signed [DATA_W*2-1:0] mult_result;    // STORE RESULT OF MULTIPLICATION

    // Select Operands for multiplication
    always_comb begin
        // SELECT OPERAND 1 FOR MULTIPLICATION
        case (mult_sel_1)
            2'b00: mult_oper_1 = '0;                // 0
            2'b01: mult_oper_1 = MLIout;            // MLIout
            2'b10: mult_oper_1 = MLIout_all;        // MLOout from port 0 MLI[0]
            default: mult_oper_1 = '0;
        endcase

        // SELECT OPERAND 2 FOR MULTIPLICATION
        case (mult_sel_2)
            1'b0: mult_oper_2 = 16'b1;              // 1
            1'b1: mult_oper_2 = MLKout;             // MLIout
            default: mult_oper_2 = '0;
        endcase
    end

    // MULTIPLICATION
    always_comb begin
        mult_result = mult_oper_1 * mult_oper_2;

        // SCALE THE RESULT BACK TO fixed-point 
        mult_result = mult_result >> DECIMAL_BIT; // SCALE Q16.16 to Q8.8 (shift right)
    end

    // SELECT OPERAND FOR THE ACC BLOCK AND ADD THE ACCUMULATION WITH THE RESULT FROM MULTIPLICATION
    always_comb begin
        case (acc_sel)
            2'b00: acc_result = mult_result[15:0];                // JUST RESULT FROM MULTIPICATION
            2'b01: acc_result = MLOout + mult_result[15:0];       // ADD MLIout
            2'b10: acc_result = EOAout + mult_result[15:0];       // ADD EOAout
            2'b11: acc_result = SEOAout + mult_result[15:0];      // ADD SEOAout
            default: acc_result = '0;
        endcase
    end

endmodule