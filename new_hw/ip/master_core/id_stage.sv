import riscv_pkg::*;

/**
 * @brief Instruction Decode Stage (ID)
 * @details Decodes the fetched instruction and sets up control signals.
 *          Responsibilities:
 *          - Decodes opcode, register indices (rs1, rs2, rd), and immediates
 *          - Instantiates the Main Control Unit
 *          - Instantiates the Register File (read ports)
 *          - Instantiates the Immediate Generator
 *          - Passes control signals and data to ID/EX pipeline register
 * 
 * @param clk             System Clock
 * @param rst             System Reset (Active High)
 * @param instruction     Fetched Instruction from IF Stage
 * @param pc              Program Counter from IF Stage
 * @param reg_write_wb    Register Write Enable from WB Stage
 * @param write_data_wb   Data to write to Register File from WB Stage
 * @param rd_wb           Destination Register Address from WB Stage
 * @param read_data1      Data read from Register File (rs1)
 * @param read_data2      Data read from Register File (rs2)
 * @param imm_out         Sign-extended Immediate value
 * @param rs1             Source Register 1 Address
 * @param rs2             Source Register 2 Address
 * @param rd              Destination Register Address
 * @param opcode          Decoded Opcode
 * @param funct3          Decoded Funct3 field
 * @param funct7          Decoded Funct7 field
 * @param reg_write       Control: Register Write Enable
 * @param mem_write       Control: Memory Write Enable
 * @param alu_control     Control: ALU Operation Selector
 * @param op_a_sel        Control: ALU Source A Mux Select (0=rs1, 1=PC, 2=Zero)
 * @param op_b_sel        Control: ALU Source B Mux Select (0=Reg, 1=Imm)
 * @param wb_mux_sel      Control: Result Mux Select
 * @param branch          Control: Branch Enable
 * @param jump            Control: Jump Enable (JAL)
 * @param jalr            Control: Jump Register Enable (JALR)
 * @param o_wen_dma0      Control: DMA0 CSR Write Enable
 * @param o_wen_dma1      Control: DMA1 CSR Write Enable
 * @param o_slave_start   Control: SCR slave-start request
 * @param o_wait_row      Control: wait for one slave row-completion event
 */
module ID_Stage (
    input  logic             clk,
    input  logic             rst,
    input  logic [31:0]      instruction,
    input  logic [XLEN-1:0]  pc,
    input  logic             reg_write_wb,
    input  logic [XLEN-1:0]  write_data_wb,
    input  logic [4:0]       rd_wb,
    output logic [XLEN-1:0]  read_data1,
    output logic [XLEN-1:0]  read_data2,
    output logic [XLEN-1:0]  imm_out,     
    output logic [4:0]       rs1,
    output logic [4:0]       rs2,
    output logic [4:0]       rd,
    output opcode_t          opcode,
    output logic [2:0]       funct3,
    output logic [6:0]       funct7,
    output logic             reg_write,
    output logic             mem_write,
    output alu_op_t          alu_control,
    output logic [1:0]       op_a_sel,  
    output logic             op_b_sel,       
    output logic [1:0]       wb_mux_sel,
    output logic             branch,
    output logic             jump,
    output logic             jalr,
    output logic             o_wen_dma0,
    output logic             o_wen_dma1,
    output logic             o_slave_start,
    output logic             o_wait_row
);
    // --- Instruction Field Decoding ---
    assign opcode = opcode_t'(instruction[6:0]);
    // DMA_CONFIG and SCR consume only rs1; WAIT_ROW consumes no registers.
    // Unused fields must not create false register dependencies.
    assign rd     = ((opcode == OP_DMA_CONFIG) || (opcode == OP_SCR) ||
                     (opcode == OP_WAIT_ROW)) ?
                    5'd0 : instruction[11:7];
    assign funct3 = instruction[14:12];
    assign rs1    = (opcode == OP_WAIT_ROW) ? 5'd0 : instruction[19:15];
    assign rs2    = ((opcode == OP_DMA_CONFIG) || (opcode == OP_SCR) ||
                     (opcode == OP_WAIT_ROW)) ?
                    5'd0 : instruction[24:20];
    assign funct7 = instruction[31:25];

    ControlUnit control_unit_inst (
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .reg_write(reg_write),
        .alu_control(alu_control),
        .op_a_sel(op_a_sel),
        .op_b_sel(op_b_sel),
        .mem_write(mem_write),
        .wb_mux_sel(wb_mux_sel),
        .branch(branch),
        .jump(jump),
        .jalr(jalr),
        .o_wen_dma0(o_wen_dma0),
        .o_wen_dma1(o_wen_dma1),
        .o_slave_start(o_slave_start),
        .o_wait_row(o_wait_row)
    );

    RegFile reg_file_inst (
        .clk(clk),
        .rst(rst),
        .RegWrite(reg_write_wb),   
        .rs1(rs1),                   
        .rs2(rs2),                   
        .rd(rd_wb),                 
        .write_data(write_data_wb),
        .read_data1(read_data1),   
        .read_data2(read_data2)     
    );

    ImmGen imm_gen_inst (
        .instruction(instruction),
        .opcode(opcode),
        .imm_out(imm_out)
    );

endmodule
