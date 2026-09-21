`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/11/2024 01:50:18 PM
// Design Name: 
// Module Name: agu_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module agu_tb();
    parameter SCRATCHPAD_SIZE = 64;
    // INPUT
    bit clk;
    bit rst;
    bit run_en;
    bit sit_en;
    bit sbp_en;
    bit sof_en;
    bit [8:0] offset;
    bit new_base_addr;
    bit [$clog2(SCRATCHPAD_SIZE)-1:0] base_addr_read_IB;
    bit [$clog2(SCRATCHPAD_SIZE)-1:0] base_addr_read_KSP;
    bit [$clog2(SCRATCHPAD_SIZE)-1:0] base_addr_write_OSP;
    bit [$clog2(SCRATCHPAD_SIZE)-1:0] base_addr_read_OSP;
    bit [$clog2(SCRATCHPAD_SIZE)-1:0] base_addr_write_OB;
    bit [$clog2(SCRATCHPAD_SIZE)-1:0] base_addr_read_OB;
    bit [$clog2(SCRATCHPAD_SIZE)-1:0] base_addr_read_BSP;
    bit [$clog2(SCRATCHPAD_SIZE)-1:0] base_addr_write_FCSP;
    bit [$clog2(SCRATCHPAD_SIZE)-1:0] base_addr_read_FCSP;
    // OUTPUT
    wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_read_IB;
    wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_read_KSP;
    wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_write_OSP;
    wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_read_OSP;
    wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_write_OB;
    wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_read_OB;
    wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_read_BSP;
    wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_write_FCSP;
    wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_read_FCSP;
    wire select_next_PC;
    wire [7:0] PC_start;
    
    reg [7:0] PC;
    
    initial begin
        PC = 0;
        
        // Reset
        #10
        rst = 1;
        #300
        rst = 0;
        run_en = 1;
        sit_en = 0;
        sbp_en = 0;
        sof_en = 0;
  ;
        #100
        // Set breakpoint
        run_en = 0;
        sbp_en = 1;
        offset = 10;
        // Set offset
        #10
        sbp_en = 0;
        sof_en = 1;
        offset = 9'b100101010;
        base_addr_read_IB = 10;
        base_addr_read_KSP = 30;
        base_addr_write_OSP = 100;
        base_addr_read_OSP = 5;
        base_addr_write_OB = 12;
        base_addr_read_OB = 20;
        base_addr_read_BSP = 100;
        base_addr_write_FCSP = 250;
        base_addr_read_FCSP = 91;
        new_base_addr = 1;

        // Set iteration
        #10
        sof_en = 0;
        sit_en = 1;
        offset = 4;
        new_base_addr = 0;

        // Run
        #10
        sit_en = 0;
        run_en = 1;
        
        // Done, Continue using run command to do other instructions
        #500
        new_base_addr = 1;
        base_addr_read_IB = 28;
        base_addr_read_KSP = 120;
        base_addr_write_OSP = 191;
        base_addr_read_OSP = 215;
        base_addr_write_OB = 120;
        base_addr_read_OB = 72;
        base_addr_read_BSP = 36;
        base_addr_write_FCSP = 61;
        base_addr_read_FCSP = 80;
        #300
        // ===========================================================
        // Set breakpoint
        run_en = 0;
        new_base_addr = 0;
        sbp_en = 1;
        offset = 3;
        // Set offset
        #10
        sbp_en = 0;
        sof_en = 1;
        offset = 9'b111111111;
        base_addr_read_IB = 8;
        base_addr_read_KSP = 30;
        base_addr_write_OSP = 12;
        base_addr_read_OSP = 15;
        base_addr_write_OB = 12;
        base_addr_read_OB = 92;
        base_addr_read_BSP = 37;
        base_addr_write_FCSP = 1;
        base_addr_read_FCSP = 0;
        new_base_addr = 1;

        // Set iteration
        #10
        sof_en = 0;
        sit_en = 1;
        offset = 5;
        new_base_addr = 0;

        // Run
        #10
        sit_en = 0;
        run_en = 1;
        #5000
        $finish;
    end
    
    // CLOCK
    always #5 clk = ~clk;
    
    // DECLARE AGU BLOCK
    agu #(.SCRATCHPAD_SIZE(SCRATCHPAD_SIZE)) agu_block(
        .clk(clk),
        .rst(rst),
        .run_en(run_en),
        .sit_en(sit_en),
        .sbp_en(sbp_en),
        .sof_en(sof_en),
        .offset(offset),
        .PC(PC),
        
        .new_base_addr(new_base_addr),
        .base_addr_read_IB(base_addr_read_IB),
        .base_addr_read_KSP(base_addr_read_KSP),
        .base_addr_write_OSP(base_addr_write_OSP),
        .base_addr_read_OSP(base_addr_read_OSP),
        .base_addr_write_OB(base_addr_write_OB),
        .base_addr_read_OB(base_addr_read_OB),
        .base_addr_read_BSP(base_addr_read_BSP),
        .base_addr_write_FCSP(base_addr_write_FCSP),
        .base_addr_read_FCSP(base_addr_read_FCSP),
        
        .addr_read_IB(addr_read_IB),
        .addr_read_KSP(addr_read_KSP),
        .addr_write_OSP(addr_write_OSP),
        .addr_read_OSP(addr_read_OSP),
        .addr_write_OB(addr_write_OB),
        .addr_read_OB(addr_read_OB),
        .addr_read_BSP(addr_read_BSP),
        .addr_write_FCSP(addr_write_FCSP),
        .addr_read_FCSP(addr_read_FCSP),
    
        .select_next_PC(select_next_PC),
        .PC_start(PC_start)
    );
        
    wire [7:0] PC_next;
    always @(posedge clk) begin
        if(rst) PC = 0;
        else begin
            if(select_next_PC == 0) PC = PC + 1;
            else PC = PC_start;
        end
    end

endmodule
