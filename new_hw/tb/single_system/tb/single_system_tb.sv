`timescale 1ns/1ps

// File-driven master/slave simulation harness. Instructions are loaded only
// through the existing MASTER_IMEM_FILE and SLAVE_IMEM_FILE parameters.
// OM is asynchronous-read and clocked-write; all DUT memories remain inside
// single_system_top. This bench generates no instructions or DMA commands.
module single_system_tb # (
    parameter               MASTER_IMEM_FILE = "conv1_master_imem.mem",
    parameter               SLAVE_IMEM_FILE  = "conv1_slave_imem.mem",
    parameter int unsigned  OM_DEPTH         = 1048576,
    parameter int unsigned  MAX_CYCLES       = 3500000,
    parameter               CONV1_BIAS_FILE  = "",
    parameter bit           LOG_OM_WRITES    = 1'b1,
    parameter int unsigned  CONV1_FILTERS    = 96,
    parameter int unsigned  CONV1_BIAS_BASE  = 32'h0003_D820,
    parameter               IMAGE_FILE       = "input_img.mem",
    parameter               WEIGHT_FILE      = "conv1_weight.mem",
    parameter int unsigned  IMAGE_WORDS      = 3 * 224 * 224,
    parameter int unsigned  WEIGHT_WORDS     = CONV1_FILTERS * 3 * 11 * 11,
    parameter int unsigned  BIAS_WORDS       = CONV1_FILTERS
);
    localparam int unsigned PC_W             = 9;
    // OM addresses count 16-bit words, independently of the slave address map.
    localparam int unsigned IMAGE_BASE       = 32'h0001_0000;
    localparam int unsigned WEIGHT_BASE      = 32'h0003_5000;

    logic        r_clk   = 1'b0;
    logic        r_rst_n = 1'b0;

    logic [15:0] r_om [0:OM_DEPTH-1];
    logic [15:0] w_om_rdata;
    logic [31:0] w_om_raddr;
    logic        w_om_ren;
    logic [15:0] w_om_wdata;
    logic [31:0] w_om_waddr;
    logic        w_om_wen;

    logic        w_dma0_done;
    logic        w_dma1_done;
    logic        w_slave_done;
    logic        w_slave_row_done;
    logic        r_previous_slave_done;
    integer      r_result_file;

    always #5 r_clk = ~r_clk;

`ifdef ENABLE_WAVES
    initial begin : DumpWaveforms
        $dumpfile("single_system.vcd");
        $dumpvars(0, single_system_tb);
    end
`endif

    single_system_top # (
        .PC_W             (PC_W),
        .MASTER_IMEM_FILE (MASTER_IMEM_FILE),
        .SLAVE_IMEM_FILE  (SLAVE_IMEM_FILE)
    ) dut (
        .i_clk            (r_clk),
        .i_rst_n          (r_rst_n),

        .i_om_rdata       (w_om_rdata),
        .o_om_raddr       (w_om_raddr),
        .o_om_ren         (w_om_ren),
        .o_om_wdata       (w_om_wdata),
        .o_om_waddr       (w_om_waddr),
        .o_om_wen         (w_om_wen),

        .o_dma0_done      (w_dma0_done),
        .o_dma1_done      (w_dma1_done),
        .o_slave_done     (w_slave_done),
        .o_slave_row_done (w_slave_row_done)
    );

    // OM has independent ports. Reads are asynchronous and writes take effect after the clock edge.
    assign w_om_rdata = (w_om_ren && (w_om_raddr < OM_DEPTH))
                        ? r_om[w_om_raddr] : 16'd0;

    always @(posedge r_clk) begin : MonitorMemory
        if (!r_rst_n) begin
            r_previous_slave_done <= 1'b0;
        end else begin
            if ($isunknown({w_om_ren, w_om_wen}))
                $fatal(1, "Unknown OM request");
            if (w_om_ren && ($isunknown(w_om_raddr) || (w_om_raddr >= OM_DEPTH)))
                $fatal(1, "OM read address out of range: %h", w_om_raddr);

            if (w_om_wen) begin
                if ($isunknown(w_om_waddr) || (w_om_waddr >= OM_DEPTH))
                    $fatal(1, "OM write address out of range: %h", w_om_waddr);
                r_om[w_om_waddr] <= w_om_wdata;
                if (LOG_OM_WRITES)
                    $fdisplay(r_result_file, "Time %0t: OM[%08h] <= %04h",
                              $time, w_om_waddr, w_om_wdata);
            end

            if (w_dma0_done)
                $fdisplay(r_result_file, "Time %0t: DMA0 done", $time);
            if (w_dma1_done)
                $fdisplay(r_result_file, "Time %0t: DMA1 done", $time);
            if (w_slave_done && !r_previous_slave_done)
                $fdisplay(r_result_file, "Time %0t: slave done (pipeline drained)", $time);
            r_previous_slave_done <= w_slave_done;
        end
    end

    initial begin : RunProgram
        r_result_file = $fopen("single_system_result.log", "w");
        if (r_result_file == 0)
            $fatal(1, "Cannot open single_system_result.log");

        for (int unsigned w_word = 0; w_word < OM_DEPTH; w_word++)
            r_om[w_word] = 16'hA55A;

        // Preload image and parameter data from the simulator's working directory.
        $readmemh(IMAGE_FILE, r_om, IMAGE_BASE, IMAGE_BASE + IMAGE_WORDS - 1);
        $readmemh(WEIGHT_FILE, r_om, WEIGHT_BASE, WEIGHT_BASE + WEIGHT_WORDS - 1);
        if (CONV1_BIAS_FILE != "") begin
            $readmemh(CONV1_BIAS_FILE, r_om,
                      CONV1_BIAS_BASE, CONV1_BIAS_BASE + BIAS_WORDS - 1);
        end else begin
            // A bias-free program can load zero into the existing output adder.
            for (int w_bias = 0; w_bias < BIAS_WORDS; w_bias++)
                r_om[CONV1_BIAS_BASE + w_bias] = 16'h0000;
        end
        $fdisplay(r_result_file, "OM input image: %08h..%08h (%0d words)",
                  IMAGE_BASE, IMAGE_BASE + IMAGE_WORDS - 1, IMAGE_WORDS);
        $fdisplay(r_result_file, "OM weights: %08h..%08h (%0d words)",
                  WEIGHT_BASE, WEIGHT_BASE + WEIGHT_WORDS - 1, WEIGHT_WORDS);
        $fdisplay(r_result_file, "OM bias slot: %08h..%08h (%0d words)",
                  CONV1_BIAS_BASE, CONV1_BIAS_BASE + BIAS_WORDS - 1, BIAS_WORDS);

        repeat (4) @(negedge r_clk);
        r_rst_n = 1'b1;
        repeat (MAX_CYCLES) @(negedge r_clk);

        // The bare harness exits at the cycle limit. The layer checker verifies the outputs.
        $fdisplay(r_result_file, "Finished %0d cycles; workload results are unchecked.", MAX_CYCLES);
        $fdisplay(r_result_file, "SINGLE_SYSTEM_TB_FINISHED");
        $fclose(r_result_file);
        $display("SINGLE_SYSTEM_TB_FINISHED: %0d cycles; workload results are unchecked.", MAX_CYCLES);
        $finish;
    end
endmodule
