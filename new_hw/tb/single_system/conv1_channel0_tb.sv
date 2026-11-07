`timescale 1ns/1ps

// Workload-specific checker around the file-driven system harness. No commands
// or memory loaders are added to the DUT; programs execute from their .mem files.
module conv1_channel0_tb;
    localparam int unsigned LANES = 64;
    localparam int unsigned OSP_WORDS = 495;
    localparam int unsigned KERNEL_WORDS = 121;
    localparam int unsigned BATCH_WORDS = 4 * KERNEL_WORDS;
    localparam int unsigned CHANNEL1_BASE = 32'h0003_5079;
    logic [15:0] r_expected [0:LANES*OSP_WORDS-1];
    logic [LANES-1:0] r_lanes_checked = '0;
    int unsigned r_rows = 0;
    int unsigned r_waits = 0;
    int unsigned r_dma_done = 0;
    int unsigned r_dma_words = 0;
    int unsigned r_stores = 0;
    int unsigned r_macs = 0;
    int unsigned r_starts = 0;
    int unsigned r_input_rows_loaded = 0;
    int unsigned r_input_rows_started = 0;
    int unsigned r_prefetch_words = 0;
    logic r_saw_park = 1'b0;

    single_system_tb #(
        .MASTER_IMEM_FILE("conv1_channel0_master_imem.mem"),
        .SLAVE_IMEM_FILE("conv1_channel0_slave_imem.mem")
    ) u_system ();

    always @(posedge u_system.r_clk) begin
        if (u_system.r_rst_n) begin
            if (u_system.w_slave_row_done) r_rows <= r_rows + 1;
            if (u_system.dut.u_master.cpu_inst.w_consume_row_done) r_waits <= r_waits + 1;
            if (u_system.w_dma0_done) r_dma_done <= r_dma_done + 1;
            if (u_system.dut.w_dma0_wen) r_dma_words <= r_dma_words + 1;
            if (u_system.dut.u_slave.w_store_osp) r_stores <= r_stores + 1;
            if (u_system.dut.u_slave.w_mac_en) r_macs <= r_macs + 1;
            if (u_system.dut.w_slave_start) r_starts <= r_starts + 1;
            if (u_system.dut.w_ib_we && (u_system.dut.w_ib_waddr == 10'd223))
                r_input_rows_loaded <= r_input_rows_loaded + 1;
            if (u_system.dut.u_slave.w_load_ib &&
                ((r_input_rows_started == 0) || u_system.dut.u_slave.w_ib_switch))
                r_input_rows_started <= r_input_rows_started + 1;
            if ((|u_system.dut.w_ksp_we) && u_system.dut.u_slave.w_load_ksp &&
                (u_system.dut.w_ksp_wbuf_sel == u_system.dut.u_slave.w_ksp_rbuf_sel))
                $fatal(1, "DMA overwrites the active KSP buffer");
            if ((|u_system.dut.w_ksp_we) && u_system.dut.w_ksp_wbuf_sel) begin
                if ((r_input_rows_loaded != (4 + r_prefetch_words / BATCH_WORDS)) ||
                    ((r_input_rows_started + 1) != r_input_rows_loaded) ||
                    u_system.dut.u_slave.w_ib_switch)
                    $fatal(1, "KSP prefetch outside the row gap: loaded=%0d started=%0d words=%0d",
                           r_input_rows_loaded, r_input_rows_started, r_prefetch_words);
                if ((u_system.dut.w_dma0_addr !=
                     (32'h0001_4000 + (r_prefetch_words / KERNEL_WORDS) * 256 +
                      r_prefetch_words % KERNEL_WORDS)) ||
                    (u_system.w_om_raddr !=
                     (CHANNEL1_BASE + (r_prefetch_words / KERNEL_WORDS) * 363 +
                      r_prefetch_words % KERNEL_WORDS)))
                    $fatal(1, "KSP prefetch address mismatch at word %0d", r_prefetch_words);
                if ((r_prefetch_words % BATCH_WORDS) == 0)
                    $fdisplay(u_system.r_result_file, "Time %0t: KSP1 batch start after input row %0d",
                              $time, r_input_rows_loaded);
                if ((r_prefetch_words % BATCH_WORDS) == (BATCH_WORDS - 1))
                    $fdisplay(u_system.r_result_file, "Time %0t: KSP1 batch complete after input row %0d",
                              $time, r_input_rows_loaded);
                r_prefetch_words <= r_prefetch_words + 1;
            end
            if (u_system.dut.u_slave.w_load_ib && u_system.dut.w_ib_we &&
                (u_system.dut.w_ib_wbuf_sel == u_system.dut.u_slave.w_ib_rbuf_sel))
                $fatal(1, "DMA overwrites the active IB buffer at slave PC %0d",
                       u_system.dut.w_slave_pc);
            if (u_system.dut.u_slave.w_load_ib && (u_system.dut.u_slave.o_ib_addr >= 10'd224))
                $fatal(1, "IB access outside the loaded input row");
            if (u_system.dut.u_slave.w_load_ksp && (u_system.dut.u_slave.o_ksp_addr >= 8'd121))
                $fatal(1, "KSP access outside the loaded channel-0 kernel");
            if (u_system.dut.u_slave.w_store_osp &&
                (u_system.dut.u_slave.w_nl_osp_addr >= 9'd495))
                $fatal(1, "OSP write outside the nine-row tile");
        end
    end

    generate
        for (genvar w_lane = 0; w_lane < LANES; w_lane++) begin : g_check_lane
            initial begin
                wait (u_system.w_slave_done === 1'b1);
                @(negedge u_system.r_clk);
                for (int w_addr = 0; w_addr < OSP_WORDS; w_addr++) begin
                    if (u_system.dut.u_slave.g_lane[w_lane].u_osp.r_memory[w_addr] !==
                        r_expected[w_lane*OSP_WORDS+w_addr])
                        $fatal(1, "OSP mismatch lane=%0d address=%0d expected=%04h actual=%04h",
                               w_lane, w_addr, r_expected[w_lane*OSP_WORDS+w_addr],
                               u_system.dut.u_slave.g_lane[w_lane].u_osp.r_memory[w_addr]);
                end
                for (int w_addr = 0; w_addr < KERNEL_WORDS; w_addr++) begin
                    if (u_system.dut.u_slave.g_lane[w_lane].g_ksp_buffer[1].u_ksp.r_memory[w_addr] !==
                        u_system.r_om[CHANNEL1_BASE + w_lane*363 + w_addr])
                        $fatal(1, "KSP1 channel-1 weight mismatch lane=%0d word=%0d", w_lane, w_addr);
                end
                r_lanes_checked[w_lane] = 1'b1;
            end
        end
    endgenerate

    initial begin
        $readmemh("conv1_channel0_osp.mem", r_expected);
        wait (&r_lanes_checked);
        repeat (16) begin
            @(negedge u_system.r_clk);
            if (u_system.dut.u_master.cpu_inst.id_jump &&
                (u_system.dut.u_master.cpu_inst.if_id_pc == 32'h0000_00A0))
                r_saw_park = 1'b1;
        end
        if ((r_rows != 41) || (r_waits != 41) || (r_dma_done != 169) ||
            (r_dma_words != 24672) || (r_stores != 5335) ||
            (r_prefetch_words != LANES*KERNEL_WORDS) || (r_input_rows_loaded != 41) ||
            (r_macs != 58394) || (r_starts != 1) || !r_saw_park)
            $fatal(1, "Counts rows=%0d waits=%0d DMA done=%0d words=%0d stores=%0d MACs=%0d SCR=%0d park=%0b",
                   r_rows, r_waits, r_dma_done, r_dma_words, r_stores, r_macs, r_starts, r_saw_park);
        $fdisplay(u_system.r_result_file, "Compared %0d OSP words: all matched", LANES*OSP_WORDS);
        $fdisplay(u_system.r_result_file, "Compared %0d KSP1 channel-1 weights: all matched", r_prefetch_words);
        $fdisplay(u_system.r_result_file, "Rows=%0d waits=%0d DMA transfers=%0d words=%0d OSP stores=%0d MACs/lane=%0d",
                  r_rows, r_waits, r_dma_done, r_dma_words, r_stores, r_macs);
        $fdisplay(u_system.r_result_file, "CONV1_CHANNEL0_TB_PASS");
        $fclose(u_system.r_result_file);
        $display("CONV1_CHANNEL0_TB_PASS: all 31680 OSP words matched; 41 row events consumed.");
        $finish;
    end

    initial begin
        wait (u_system.r_rst_n);
        repeat (99990) @(negedge u_system.r_clk);
        $fatal(1, "CONV1 timeout: slave PC=%0d master PC=%08h row events=%0d waits=%0d",
               u_system.dut.w_slave_pc, u_system.dut.u_master.cpu_inst.if_pc, r_rows, r_waits);
    end
endmodule
