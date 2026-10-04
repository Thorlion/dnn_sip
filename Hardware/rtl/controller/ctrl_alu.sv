module MC_alu #(
    parameter DATA_W = 32
)(
    input  logic clk, rst, wen,
    input  logic [DATA_W-1:0] operand_1,  // RA(0), RD(1), 0(2)
    input  logic [DATA_W-1:0] operand_2,   // RB(0), imm16(1), 0(2), 1(3), imm16<<16(4)
    input  logic [2:0] alu_op,
    output logic [DATA_W-1:0] result
); 
    logic [DATA_W-1:0] multiply_result, other_result;
    logic [DATA_W-1:0] multiply_stage, other_stage;
    logic multiply_selected;

    // Register the low product bits before the result mux. All ALU operations
    // have equal latency; the controller delays destination/valid tags with them.
    assign multiply_result = operand_1 * operand_2;
    
    always_comb begin
        case(alu_op)
            3'b000: other_result = operand_1 + operand_2;
            3'b001: other_result = operand_1 - operand_2;
            3'b011: other_result = operand_1 >>> operand_2;
            3'b100: other_result = operand_1 & operand_2;
            3'b101: other_result = operand_1 | operand_2;
            default: other_result = '0;
        endcase
    end

    regs #(.DATA_W(DATA_W)) MUL_STAGE (
        .clk(clk), .rst(rst), .wen(wen), .din(multiply_result), .dout(multiply_stage));
    regs #(.DATA_W(DATA_W)) OTHER_STAGE (
        .clk(clk), .rst(rst), .wen(wen), .din(other_result), .dout(other_stage));
    regs #(.DATA_W(1)) MUL_SELECT_STAGE (
        .clk(clk), .rst(rst), .wen(wen), .din(alu_op == 3'b010), .dout(multiply_selected));
    assign result = multiply_selected ? multiply_stage : other_stage;
endmodule
