module MC_alu #(
    parameter DATA_W = 32
)(
    input  logic [DATA_W-1:0] operand_1,  // RA(0), RD(1), 0(2)
    input  logic [DATA_W-1:0] operand_2,   // RB(0), imm16(1), 0(2), 1(3), imm16<<16(4)
    input  logic [2:0] alu_op,
    output logic [DATA_W-1:0] result
); 
    logic [DATA_W*2-1:0] mult_res_temp;
    
    always_comb begin
        case(alu_op)
            3'b000: result = operand_1 + operand_2;     // OP = 1 -> ADD
            3'b001: result = operand_1 - operand_2;     // OP = 2 -> SUB
            3'b010: begin                               // OP = 3 -> MUL
                mult_res_temp = operand_1 * operand_2;
                result = mult_res_temp[31:0];
            end
            3'b011: result = operand_1 >>> operand_2;   // OP = 4 -> SRA
            3'b100: result = operand_1 & operand_2;     // OP = 5 -> AND
            3'b101: result = operand_1 | operand_2;     // OP = 6 -> OR
            default: result = 'z;
        endcase
    end
endmodule