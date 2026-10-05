module Decoder_MC #(
    parameter INST_W = 32
)(
    input  logic [INST_W-1:0] inst,
    
    //20 bits (25->6)
    output logic [4:0]  rd,
    output logic [4:0]  ra,
    output logic [4:0]  rb,
    output logic [4:0]  rtemp,
    //16bits (15->0)
    output logic [15:0] imm16,
    //6bits MSB (31->26)
    output logic [2:0]  alu_op,
    output logic [1:0]  alu_oper1_sel,
    output logic [2:0]  alu_oper2_sel,
    output logic        rf_wen,           // Register File write enable
    output logic        br_signal,        // Branch jump signal
    output logic        cbr_signal,       // Conditional branch jump signal

    output logic [3:0]  type_access,
    // Bit 0: RA, bit 1: RB, bit 2: both RD and RTEMP (memory addresses).
    // CBR's RA dependency is represented separately by cbr_signal.
    output logic [2:0]  operand_use
);
    logic [5:0] opcode;
    assign opcode = inst[31:26];
    
    assign rd = inst[25:21];
    assign ra = inst[20:16];
    assign rb = inst[15:11];
    assign rtemp = inst[10:6];
    assign imm16 = inst[15:0];
    
    assign br_signal = (opcode == 6'b010011) ? 1'b1 : 1'b0;     // OPCODE = 6'd19
    assign cbr_signal = (opcode == 6'b010100) ? 1'b1 : 1'b0;    // OPCODE = 6'd20
    assign operand_use[0] = (rf_wen && alu_oper1_sel == 0) || type_access != 0;
    assign operand_use[1] = (rf_wen && alu_oper2_sel == 0) || type_access != 0;
    assign operand_use[2] = type_access != 0;

    always_comb begin
        case(opcode)
            6'b100000: type_access = 4'b0001;   // OPCODE = 6'd32 => Chuyển data từ OM sang DNN
            6'b100001: type_access = 4'b0010;   // OPCODE = 6'd33 => Chuyển data từ OM sang P0 (đích là OM, chuyển 1 data)
            6'b100010: type_access = 4'b0011;   // OPCODE = 6'd34 => Chuyển data từ OM sang P1 (đích là OM, chuyển 1 data)
            6'b100011: type_access = 4'b0100;   // OPCODE = 6'd35 => Chuyển data từ DNN sang OM
            6'b100100: type_access = 4'b0101;   // OPCODE = 6'd36 => Chuyển data từ OM sang P0 (đích là OM, boardcast)
            6'b100101: type_access = 4'b0110;   // OPCODE = 6'd37 => Chuyển data từ OM sang P1 (đích là OM, boardcast)
            6'b100110: type_access = 4'b0111;   // OPCODE = 6'd38 => Chuyển data từ OM sang P0 (đích là DNN, chuyển 1 data)
            6'b100111: type_access = 4'b1000;   // OPCODE = 6'd39 => Chuyển data từ OM sang P1 (đích là DNN, chuyển 1 data)
            default: type_access = 4'b0000;
        endcase
    end

    always_comb begin
        case(opcode)
            // RD = RA + RB
            6'b000000: begin    // OPCODE = 6'd0
                rf_wen = 1'b1;
                alu_op = '0;
                alu_oper1_sel = '0;
                alu_oper2_sel = '0;
            end

            // RD = RA - RB
            6'b000001: begin    // OPCODE = 6'd1
                rf_wen = 1'b1;
                alu_op = 3'b001;      // ALU_OP = 3'd1
                alu_oper1_sel = '0;
                alu_oper2_sel = '0;
            end

            // RD = RA x RB
            6'b000010: begin    // OPCODE = 6'd2
                rf_wen = 1'b1;
                alu_op = 3'b010;      // ALU_OP = 3'd2
                alu_oper1_sel = '0;
                alu_oper2_sel = '0;
            end

            // RD = RA & RB
            6'b000011: begin    // OPCODE = 6'd3
                rf_wen = 1'b1;
                alu_op = 3'b100;      // ALU_OP = 3'd4
                alu_oper1_sel = '0;
                alu_oper2_sel = '0;
            end

            // RD = RA | RB
            6'b000100: begin    // OPCODE = 6'd4
                rf_wen = 1'b1;
                alu_op = 3'b101;      // ALU_OP = 3'd5
                alu_oper1_sel = '0;
                alu_oper2_sel = '0;
            end

            // RD = RA + 1
            6'b000101: begin    // OPCODE = 6'd5
                rf_wen = 1'b1;
                alu_op = 3'b000;      // ALU_OP = 3'd0
                alu_oper2_sel = 3'b011;     // ALU_OPER2_SEL = 3'd3
                alu_oper1_sel = '0;
            end

            // RD = RA - 1
            6'b000110: begin    // OPCODE = 6'd6
                rf_wen = 1'b1;
                alu_op = 3'b001;      // ALU_OP = 3'd1
                alu_oper2_sel = 3'b011;     // ALU_OPER2_SEL = 3'd3
                alu_oper1_sel = '0;
            end

            // RD = RA >> imm16
            6'b000111: begin    // OPCODE = 6'd7
                rf_wen = 1'b1;
                alu_op = 3'b011;      // ALU_OP = 3'd3
                alu_oper2_sel = 3'b001;     // ALU_OPER2_SEL = 3'd1
                alu_oper1_sel = '0;
            end

            // RD = RA + imm16
            6'b001000: begin    // OPCODE = 6'd8
                rf_wen = 1'b1;
                alu_op = 3'b000;      // ALU_OP = 3'd0
                alu_oper2_sel = 3'b001;     // ALU_OPER2_SEL = 3'd1
                alu_oper1_sel = '0;
            end

            // RD = RA - imm16
            6'b001001: begin    // OPCODE = 6'd9
                rf_wen = 1'b1;
                alu_op = 3'b001;      // ALU_OP = 3'd1
                alu_oper2_sel = 3'b001;     // ALU_OPER2_SEL = 3'd1 
                alu_oper1_sel = '0;
            end

            // RD = RA x imm16
            6'b001010: begin    // OPCODE = 6'd10
                rf_wen = 1'b1;
                alu_op = 3'b010;      // ALU_OP = 3'd2
                alu_oper2_sel = 3'b001;     // ALU_OPER2_SEL = 3'd1
                alu_oper1_sel = '0;
            end

            // RD = RA & imm16
            6'b001011: begin    // OPCODE = 6'd11
                rf_wen = 1'b1;
                alu_op = 3'b100;      // ALU_OP = 3'd4
                alu_oper2_sel = 3'b001;     // ALU_OPER2_SEL = 3'd1
                alu_oper1_sel = '0;
            end

            // RD = RA | imm16
            6'b001100: begin    // OPCODE = 6'd12
                rf_wen = 1'b1;
                alu_op = 3'b101;      // ALU_OP = 3'd5
                alu_oper2_sel = 3'b001;     // ALU_OPER2_SEL = 3'd1
                alu_oper1_sel = '0;
            end

            // RD = RA
            6'b001101: begin    // OPCODE = 6'd13
                rf_wen = 1'b1;
                alu_op = 3'b000;      // ALU_OP = 3'd0
                alu_oper2_sel = 3'b010;     // ALU_OPER2_SEL = 3'd2
                alu_oper1_sel = '0;
            end

            // RD = imm16
            6'b001110: begin    // OPCODE = 6'd14
                rf_wen = 1'b1;
                alu_op = 3'b000;      // ALU_OP = 3'd0
                alu_oper2_sel = 3'b001;     // ALU_OPER2_SEL = 3'd1
                alu_oper1_sel = 2'b10;     // ALU_OPER1_SEL = 2'd2
            end

            // RD = (imm16<16)
            6'b001111: begin    // OPCODE = 6'd15
                rf_wen = 1'b1;
                alu_op = 3'b000;      // ALU_OP = 3'd0
                alu_oper2_sel = 3'b100;    // ALU_OPER2_SEL = 3'd4
                alu_oper1_sel = 2'b10;     // ALU_OPER1_SEL = 2'd2
            end
            default: begin
                rf_wen          = '0;
                alu_op          = '0;
                alu_oper2_sel   = '0;
                alu_oper1_sel   = '0;
            end
        endcase
    end

endmodule
