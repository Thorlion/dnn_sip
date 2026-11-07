`timescale 1ns/1ps

// File-driven master/slave simulation harness. Instructions are loaded only
// through the existing MASTER_IMEM_FILE and SLAVE_IMEM_FILE parameters.
// OM is asynchronous-read and clocked-write; all DUT memories remain inside
// single_system_top. This bench generates no instructions or DMA commands.
module single_system_tb #(
    parameter MASTER_IMEM_FILE = "single_master_imem.mem",
    parameter SLAVE_IMEM_FILE = "single_slave_imem.mem"
);
    localparam int unsigned PC_W = 9;
    localparam int unsigned OM_DEPTH = 262144; // 256K x 16 bits = 512 KiB
    localparam int unsigned MAX_CYCLES = 100000;
    // OM addresses count 16-bit words, independently of the slave address map.
    localparam int unsigned IMAGE_BASE = 32'h0001_0000;
    localparam int unsigned IMAGE_WORDS = 3 * 224 * 224;
    localparam int unsigned CONV1_WEIGHT_BASE = 32'h0003_5000;
    localparam int unsigned CONV1_WEIGHT_WORDS = 64 * 3 * 11 * 11;
    localparam int unsigned CONV1_BIAS_BASE = 32'h0003_B000;
    localparam int unsigned CONV1_BIAS_WORDS = 64;

    logic r_clk = 1'b0;
    logic r_rst_n = 1'b0;
    logic [15:0] r_om [0:OM_DEPTH-1];
    logic [15:0] w_om_rdata;
    logic [15:0] w_om_wdata;
    logic [31:0] w_om_raddr;
    logic [31:0] w_om_waddr;
    logic w_om_ren;
    logic w_om_wen;
    logic w_dma0_done;
    logic w_dma1_done;
    logic w_slave_done;
    logic w_slave_row_done;
    logic r_previous_slave_done;
    integer r_result_file;

    always #5 r_clk = ~r_clk;

`ifdef ENABLE_WAVES
    initial begin
        $dumpfile("single_system.vcd");
        $dumpvars(0, single_system_tb);
    end
`endif

    single_system_top #(
        .PC_W(PC_W),
        .MASTER_IMEM_FILE(MASTER_IMEM_FILE),
        .SLAVE_IMEM_FILE(SLAVE_IMEM_FILE)
    ) dut (
        .i_clk(r_clk),
        .i_rst_n(r_rst_n),
        .i_om_rdata(w_om_rdata),
        .o_om_raddr(w_om_raddr),
        .o_om_ren(w_om_ren),
        .o_om_wdata(w_om_wdata),
        .o_om_waddr(w_om_waddr),
        .o_om_wen(w_om_wen),
        .o_dma0_done(w_dma0_done),
        .o_dma1_done(w_dma1_done),
        .o_slave_done(w_slave_done),
        .o_slave_row_done(w_slave_row_done)
    );

    // Independent OM ports, no wait states. A same-word read/write supplies
    // the old value at the edge and reflects the new value after the NBA write.
    assign w_om_rdata = (w_om_ren && (w_om_raddr < OM_DEPTH)) ?
                       r_om[w_om_raddr] : 16'd0;

    always @(posedge r_clk) begin
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

        // Only image/parameter data is preloaded into OM. Master and slave
        // instructions come from their respective IMEM files, not from here.
        // The runner stages all five inputs in the simulator's working directory.
        $readmemh("input_img.mem", r_om, IMAGE_BASE, IMAGE_BASE + IMAGE_WORDS - 1);
        $readmemh("conv1_weight.mem", r_om,
                  CONV1_WEIGHT_BASE, CONV1_WEIGHT_BASE + CONV1_WEIGHT_WORDS - 1);
        $readmemh("conv1_bias.mem", r_om,
                  CONV1_BIAS_BASE, CONV1_BIAS_BASE + CONV1_BIAS_WORDS - 1);
        $fdisplay(r_result_file, "OM input image: %08h..%08h (%0d words)",
                  IMAGE_BASE, IMAGE_BASE + IMAGE_WORDS - 1, IMAGE_WORDS);
        $fdisplay(r_result_file, "OM CONV1 weights: %08h..%08h (%0d words)",
                  CONV1_WEIGHT_BASE, CONV1_WEIGHT_BASE + CONV1_WEIGHT_WORDS - 1,
                  CONV1_WEIGHT_WORDS);
        $fdisplay(r_result_file, "OM CONV1 biases: %08h..%08h (%0d words)",
                  CONV1_BIAS_BASE, CONV1_BIAS_BASE + CONV1_BIAS_WORDS - 1,
                  CONV1_BIAS_WORDS);

        repeat (4) @(negedge r_clk);
        r_rst_n = 1'b1;
        repeat (MAX_CYCLES) @(negedge r_clk);

        // Slave DONE is logged; there is no full-system completion/result check.
        // Reaching the run limit indicates only that the simulation finished.
        $fdisplay(r_result_file, "Finished %0d cycles; workload results are unchecked.", MAX_CYCLES);
        $fdisplay(r_result_file, "SINGLE_SYSTEM_TB_FINISHED");
        $fclose(r_result_file);
        $display("SINGLE_SYSTEM_TB_FINISHED: %0d cycles; workload results are unchecked.", MAX_CYCLES);
        $finish;
    end
endmodule
