import riscv_pkg::*;

/**
 * @brief Top-Level Module for PYNQ-Z2 FPGA
 * @details Integrates the Pipelined CPU with FPGA-specific peripherals.
 *          - Instantiates Clock Wizard (125MHz -> 10MHz)
 *          - Instantiates Block RAMs for Instruction and Data Memory
 *          - Maps MMIO LEDs to physical LED pins
 *          - Includes ILA (Integrated Logic Analyzer) for hardware debugging
 * 
 * @param sysclk    125MHz System Clock
 * @param reset_btn Reset Button (Active Low)
 * @param led       4-bit LED Output
 * @param uart_tx   UART Transmit (Not currently implemented)
 */
module dsip_master #(
    parameter IMEM_INIT_FILE = "led_blink.mem"
)(
    input  logic        i_clk,
    input  logic        i_rst_n,
    input  logic        i_slave_row_done,
    output logic [31:0] o_dma_csr_data,
    output logic [31:0] o_dma_csr_offset,
    output logic        o_wen_dma0,
    output logic        o_wen_dma1,

    // SCR outputs: the full forwarded rs1 value is valid during the EX strobe.
    output logic        o_slave_start,
    output logic [31:0] o_slave_pc
);
  




    // --- CPU Signals ---
    // The wrapper reset is active low; the imported CPU and memories use
    // active-high reset inputs.
    logic           w_rst;
    assign w_rst = ~i_rst_n;

    logic [ALEN-1:0] imem_addr;
    logic [31:0]     imem_data;
    logic            imem_en;
    
    logic [ALEN-1:0] dmem_addr;
    logic [XLEN-1:0] dmem_rdata, dmem_wdata;
    logic            dmem_we;
    logic [3:0]      dmem_be;
    logic [2:0]      dmem_funct3;
    logic [3:0]      dmem_leds;

    // CPU Instance
    PipelinedCPU cpu_inst (
        .clk(i_clk),
        .rst(w_rst),
        .i_slave_row_done(i_slave_row_done),
        .imem_addr(imem_addr),
        .imem_data(imem_data),
        .imem_en(imem_en),
        .dmem_addr(dmem_addr),
        .dmem_rdata(dmem_rdata),
        .dmem_wdata(dmem_wdata),
        .dmem_we(dmem_we),
        .dmem_be(dmem_be),
        .dmem_funct3(dmem_funct3),
        .o_dma_csr_offset(o_dma_csr_offset),
        .o_dma_csr_data(o_dma_csr_data),
        .o_wen_dma0(o_wen_dma0),
        .o_wen_dma1(o_wen_dma1),
        .o_slave_start(o_slave_start),
        .o_slave_pc(o_slave_pc)
    );

    // Instruction Memory
    InstructionMemory #(
        .MEM_INIT_FILE(IMEM_INIT_FILE)
    ) imem (
        .clk(i_clk),
        .rst(w_rst),
        .en(1'b1),
        .Address(imem_addr),
        .Instruction(imem_data)
    );

    // Data Memory
    DataMemory dmem_inst (
        .clk(i_clk),
        .rst(w_rst),
        .MemWrite(dmem_we),
        .be(dmem_be),
        .funct3(dmem_funct3),
        .Address(dmem_addr),
        .WriteData(dmem_wdata),
        .ReadData(dmem_rdata),
        .leds_out(dmem_leds)
    );

    // // --- ILA Debug ---
    // // ILA Probe Signals with mark_debug attribute
    // (* mark_debug = "true" *) logic [XLEN-1:0] ila_pc;
    // (* mark_debug = "true" *) logic [XLEN-1:0] ila_instruction;
    // (* mark_debug = "true" *) logic [2:0]      ila_hazard_signals;  // stall_id, flush_ex, id_branch
    // (* mark_debug = "true" *) logic            ila_branch_taken;
    // (* mark_debug = "true" *) logic [XLEN-1:0] ila_branch_target;
    // (* mark_debug = "true" *) logic            ila_alu_zero;
    // (* mark_debug = "true" *) logic [2:0]      ila_mem_wb_controls; // ex_mem_reg_write, mem_wb_reg_write, mem_wb_wb_mux_sel[0]
    // (* mark_debug = "true" *) logic [XLEN-1:0] ila_rs1_data;
    // (* mark_debug = "true" *) logic [XLEN-1:0] ila_rs2_data;
    // (* mark_debug = "true" *) logic [XLEN-1:0] ila_alu_result;
    // (* mark_debug = "true" *) logic [4:0]      ila_mem_wb_rd;       // Register being written in WB
    // (* mark_debug = "true" *) logic [XLEN-1:0] ila_wb_data;         // Data being written in WB
    // (* mark_debug = "true" *) logic [ALEN-1:0] ila_dmem_addr;
    // (* mark_debug = "true" *) logic            ila_dmem_we;
    // (* mark_debug = "true" *) logic [XLEN-1:0] ila_dmem_wdata;

    // // Tap into CPU internals
    // // NOTE: Pipeline Stage Mismatch in Debug Signals
    // // ila_pc is probing the EXECUTE stage (id_ex_pc).
    // // ila_instruction is probing the DECODE stage (if_id_instruction).
    // // This means 'ila_instruction' shows the instruction *following* the one at 'ila_pc'.
    // assign ila_pc = cpu_inst.id_ex_pc; 
    // assign ila_instruction = cpu_inst.if_id_instruction;
    
    // // Hazard/Control Signals (Combined into 3-bit probe)
    // // [2] = id_branch (from ID_Stage)
    // // [1] = flush_ex (from HazardUnit)
    // // [0] = stall_id (from HazardUnit)
    // assign ila_hazard_signals = {cpu_inst.id_branch, cpu_inst.flush_ex, cpu_inst.stall_id};

    // assign ila_branch_taken = cpu_inst.branch_taken;
    // assign ila_branch_target = cpu_inst.ex_branch_target;
    // assign ila_alu_zero = cpu_inst.ex_zero;
    
    // // Memory/Writeback Control Signals (Combined into 3-bit probe)
    // // [2] = ex_mem_reg_write (RegWrite signal entering MEM)
    // // [1] = mem_wb_reg_write (RegWrite signal entering WB)
    // // [0] = mem_wb_wb_mux_sel[0] (MemRead signal in WB)
    // assign ila_mem_wb_controls = {cpu_inst.ex_mem_reg_write, cpu_inst.mem_wb_reg_write, cpu_inst.mem_wb_wb_mux_sel[0]};

    // assign ila_rs1_data = cpu_inst.id_ex_read_data1;
    // assign ila_rs2_data = cpu_inst.id_ex_read_data2;
    // assign ila_alu_result = cpu_inst.ex_alu_result;
    
    // assign ila_mem_wb_rd = cpu_inst.mem_wb_rd;
    // assign ila_wb_data = cpu_inst.wb_write_data;
    // assign ila_dmem_addr = cpu_inst.dmem_addr;
    // assign ila_dmem_we = cpu_inst.dmem_we;
    // assign ila_dmem_wdata = cpu_inst.dmem_wdata;

    // // ILA Instance
    // ila_0 my_ila (
    //     .clk(i_clk), 
    //     .probe0(ila_pc),                // 32-bit
    //     .probe1(ila_instruction),       // 32-bit
    //     .probe2(ila_hazard_signals),    // 3-bit
    //     .probe3(ila_branch_taken),      // 1-bit
    //     .probe4(ila_branch_target),     // 32-bit
    //     .probe5(ila_alu_zero),          // 1-bit
    //     .probe6(ila_mem_wb_controls),   // 3-bit
    //     .probe7(ila_rs1_data),          // 32-bit
    //     .probe8(ila_rs2_data),          // 32-bit
    //     .probe9(ila_alu_result),        // 32-bit
    //     .probe10(ila_mem_wb_rd),        // 5-bit
    //     .probe11(ila_wb_data),          // 32-bit
    //     .probe12(ila_dmem_addr),
    //     .probe13(ila_dmem_we),
    //     .probe14(ila_dmem_wdata)
    // );

endmodule
