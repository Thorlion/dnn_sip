`timescale 1ns / 1ps

module tb_AGU();
    parameter SCRATCHPAD_W = 64;

    // INPUT
    logic clk;
    logic rst;
    logic run_en;
    logic sit_en;
    logic sbp_en;
    logic sof_en;
    logic [8:0] offset;
    logic [7:0] PC;
    logic new_base_addr;

    logic [$clog2(SCRATCHPAD_W)-1:0] IB_rd_base_addr;
    logic [$clog2(SCRATCHPAD_W)-1:0] KSP_rd_base_addr;
    logic [$clog2(SCRATCHPAD_W)-1:0] OSP_wr_base_addr;
    logic [$clog2(SCRATCHPAD_W)-1:0] OSP_rd_base_addr;
    logic [$clog2(SCRATCHPAD_W)-1:0] OB_wr_base_addr;
    logic [$clog2(SCRATCHPAD_W)-1:0] OB_rd_base_addr;
    logic [$clog2(SCRATCHPAD_W)-1:0] BSP_rd_base_addr;
    logic [$clog2(SCRATCHPAD_W)-1:0] FCSP_wr_base_addr;
    logic [$clog2(SCRATCHPAD_W)-1:0] FCSP_rd_base_addr;

    // OUTPUT
    logic [$clog2(SCRATCHPAD_W)-1:0] IB_rd_base_addr_out;
    logic [$clog2(SCRATCHPAD_W)-1:0] KSP_rd_base_addr_out;
    logic [$clog2(SCRATCHPAD_W)-1:0] OSP_wr_base_addr_out;
    logic [$clog2(SCRATCHPAD_W)-1:0] OSP_rd_base_addr_out;
    logic [$clog2(SCRATCHPAD_W)-1:0] OB_wr_base_addr_out;
    logic [$clog2(SCRATCHPAD_W)-1:0] OB_rd_base_addr_out;
    logic [$clog2(SCRATCHPAD_W)-1:0] BSP_rd_base_addr_out;
    logic [$clog2(SCRATCHPAD_W)-1:0] FCSP_wr_base_addr_out;
    logic [$clog2(SCRATCHPAD_W)-1:0] FCSP_rd_base_addr_out;
    
    logic select_next_PC;
    logic [7:0] PC_start;
    logic n_active;

    initial begin
        IB_rd_base_addr = '0;
        KSP_rd_base_addr = '0;
        OSP_wr_base_addr = '0;
        OSP_rd_base_addr = '0;
        OB_wr_base_addr = '0;
        OB_rd_base_addr = '0;
        BSP_rd_base_addr = '0;
        FCSP_wr_base_addr = '0;
        FCSP_rd_base_addr = '0;
    end

    initial begin
//        PC = '0;
        
        // Reset
        #10
        rst = 1'b1;
        #300
        rst = 1'b0;
        run_en = 1'b1;
        sit_en = 1'b0;
        sbp_en = 1'b0;
        sof_en = 1'b0;

        #100
        // Set breakpoint
        run_en = 1'b0;
        sbp_en = 1'b1;
        offset = 10;
        
        // Set offset
        #10
        sbp_en = 1'b0;
        sof_en = 1'b1;
        offset = 9'b100101010;
        IB_rd_base_addr = 10;
        KSP_rd_base_addr = 30;
        OSP_wr_base_addr = 100;
        OSP_rd_base_addr = 5;
        OB_wr_base_addr = 12;
        OB_rd_base_addr = 20;
        BSP_rd_base_addr = 100;
        FCSP_wr_base_addr = 250;
        FCSP_rd_base_addr = 91;
        new_base_addr = 1'b1;

        // Set iteration
        #10
        sof_en = 1'b0;
        sit_en = 1'b1;
        offset = 4;
        new_base_addr = 1'b0;

        // Run
        #10
        sit_en = 1'b0;
        run_en = 1'b1;
        
        // Done, Continue using run command to do other instructions
        #500
        new_base_addr = 1'b1;
        IB_rd_base_addr = 28;
        KSP_rd_base_addr = 120;
        OSP_wr_base_addr = 191;
        OSP_rd_base_addr = 215;
        OB_wr_base_addr = 120;
        OB_rd_base_addr = 72;
        BSP_rd_base_addr = 36;
        FCSP_wr_base_addr = 61;
        FCSP_rd_base_addr = 80;
        
        #300
        // ===========================================================
        // Set breakpoint
        run_en = 1'b0;
        new_base_addr = 1'b0;
        sbp_en = 1'b1;
        offset = 3;
        
        // Set offset
        #10
        sbp_en = 1'b0;
        sof_en = 1'b1;
        offset = 9'b111111111;
        IB_rd_base_addr = 8;
        KSP_rd_base_addr = 30;
        OSP_wr_base_addr = 12;
        OSP_rd_base_addr = 15;
        OB_wr_base_addr = 12;
        OB_rd_base_addr = 92;
        BSP_rd_base_addr = 37;
        FCSP_wr_base_addr = 1;
        FCSP_rd_base_addr = 0;
        new_base_addr = 1'b1;

        // Set iteration
        #10
        sof_en = 1'b0;
        sit_en = 1'b1;
        offset = 5;
        new_base_addr = 1'b0;

        // Run
        #10
        sit_en = 1'b0;
        run_en = 1'b1;
        
        #5000
        $finish;
    end
    
    // CLOCK
    initial begin
        clk = '0;
        forever #5 clk = ~clk;
    end

    // DECLARE AGU BLOCK
    AGU #(
        .SCRATCHPAD_W(SCRATCHPAD_W)
    ) agu_block (
        .clk(clk),
        .rst(rst),
        .run_en(run_en),
        .sit_en(sit_en),
        .sbp_en(sbp_en),
        .sof_en(sof_en),
        .offset(offset),
        .PC(PC),
        
        .new_base_addr(new_base_addr),
        .IB_rd_base_addr(IB_rd_base_addr),
        .KSP_rd_base_addr(KSP_rd_base_addr),
        .OSP_wr_base_addr(OSP_wr_base_addr),
        .OSP_rd_base_addr(OSP_rd_base_addr),
        .OB_wr_base_addr(OB_wr_base_addr),
        .OB_rd_base_addr(OB_rd_base_addr),
        .BSP_rd_base_addr(BSP_rd_base_addr),
        .FCSP_wr_base_addr(FCSP_wr_base_addr),
        .FCSP_rd_base_addr(FCSP_rd_base_addr),
        
        .IB_rd_base_addr_out(IB_rd_base_addr_out),
        .KSP_rd_base_addr_out(KSP_rd_base_addr_out),
        .OSP_wr_base_addr_out(OSP_wr_base_addr_out),
        .OSP_rd_base_addr_out(OSP_rd_base_addr_out),
        .OB_wr_base_addr_out(OB_wr_base_addr_out),
        .OB_rd_base_addr_out(OB_rd_base_addr_out),
        .BSP_rd_base_addr_out(BSP_rd_base_addr_out),
        .FCSP_wr_base_addr_out(FCSP_wr_base_addr_out),
        .FCSP_rd_base_addr_out(FCSP_rd_base_addr_out),
    
        .select_next_PC(select_next_PC),
        .PC_start(PC_start),
        .n_active(n_active)
    );

    always_ff @(posedge clk) begin
        if(rst) begin
            PC <= '0;
        end else begin
            if(select_next_PC == 1'b0) 
                PC <= PC + 1;
            else 
                PC <= PC_start;
        end
    end

endmodule