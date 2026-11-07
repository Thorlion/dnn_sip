`timescale 1ns/1ps

module conv1_rgb21_tb;
    localparam int unsigned LANES = 64;
    localparam int unsigned INPUT_ROWS = 21;
    localparam int unsigned INPUT_COLS = 224;
    localparam int unsigned OSP_WORDS = 4*55;
    localparam int unsigned KERNEL_WORDS = 121;
    localparam int unsigned WEIGHT_WORDS = LANES*KERNEL_WORDS;
    localparam int unsigned CHANNELS = 3;
    logic [15:0] r_expected [0:LANES*OSP_WORDS-1];
    logic [LANES-1:0] r_checked = '0;
    int unsigned r_starts = 0;
    int unsigned r_rows_started = 0;
    int unsigned r_row_events = 0;
    int unsigned r_waits = 0;
    int unsigned r_input_words = 0;
    int unsigned r_weight_words [0:CHANNELS-1] = '{default:0};
    int unsigned r_dma_done = 0;
    int unsigned r_macs = 0;
    int unsigned r_stores = 0;
    logic r_saw_park = 1'b0;

    single_system_tb u_system ();

    always @(posedge u_system.r_clk) begin
        if (u_system.r_rst_n) begin
            if (u_system.w_slave_row_done) r_row_events <= r_row_events + 1;
            if (u_system.dut.u_master.cpu_inst.w_consume_row_done) r_waits <= r_waits + 1;
            if (u_system.w_dma0_done) r_dma_done <= r_dma_done + 1;
            if (u_system.dut.u_slave.w_mac_en) r_macs <= r_macs + 1;
            if (u_system.dut.u_slave.w_store_osp) r_stores <= r_stores + 1;
            if (u_system.dut.w_slave_start) begin
                if (r_starts >= CHANNELS)
                    $fatal(1, "Unexpected extra SCR");
                if ((r_waits != r_starts*INPUT_ROWS) ||
                    (r_weight_words[r_starts] != WEIGHT_WORDS) ||
                    (r_input_words != (r_starts*INPUT_ROWS + 1)*INPUT_COLS))
                    $fatal(1, "SCR before prior rows, weights, or the first input row are ready");
                $fdisplay(u_system.r_result_file, "Time %0t: SCR channel %0d, all weights ready",
                          $time, r_starts);
                r_starts <= r_starts + 1;
            end
            if (u_system.dut.u_slave.w_load_ib &&
                ((r_rows_started == (r_starts-1)*INPUT_ROWS) || u_system.dut.u_slave.w_ib_switch))
                r_rows_started <= r_rows_started + 1;
            if (u_system.dut.w_ib_we) begin
                int unsigned w_channel, w_row, w_column;
                w_channel = r_input_words / (INPUT_ROWS*INPUT_COLS);
                w_row = r_input_words / INPUT_COLS % INPUT_ROWS;
                w_column = r_input_words % INPUT_COLS;
                if ((w_channel >= CHANNELS) || (u_system.w_om_raddr !=
                    (32'h0001_0000 + w_channel*224*224 + w_row*224 + w_column)) ||
                    (u_system.dut.w_ib_waddr != 10'(w_column)) ||
                    (u_system.dut.w_ib_wbuf_sel != 1'(w_row)))
                    $fatal(1, "Incorrect input transfer channel=%0d row=%0d column=%0d",
                           w_channel, w_row, w_column);
                if (u_system.dut.u_slave.w_load_ib &&
                    (u_system.dut.w_ib_wbuf_sel == u_system.dut.u_slave.w_ib_rbuf_sel))
                    $fatal(1, "DMA writes the active IB");
                r_input_words <= r_input_words + 1;
            end
            if (|u_system.dut.w_ksp_we) begin
                int unsigned w_index, w_lane, w_tap, w_batch_row;
                if (r_starts >= CHANNELS)
                    $fatal(1, "Unexpected weight transfer after the final SCR");
                w_index = r_weight_words[r_starts];
                w_lane = w_index / KERNEL_WORDS;
                w_tap = w_index % KERNEL_WORDS;
                if ((w_lane >= LANES) || (u_system.w_om_raddr !=
                    (32'h0003_5000 + w_lane*363 + r_starts*KERNEL_WORDS + w_tap)) ||
                    (u_system.dut.w_dma0_addr !=
                    (32'h0001_0000 + (r_starts % 2)*32'h4000 + w_lane*256 + w_tap)))
                    $fatal(1, "Incorrect weight transfer channel=%0d lane=%0d tap=%0d",
                           r_starts, w_lane, w_tap);
                if (u_system.dut.u_slave.w_load_ksp &&
                    (u_system.dut.w_ksp_wbuf_sel == u_system.dut.u_slave.w_ksp_rbuf_sel))
                    $fatal(1, "DMA writes the active KSP");
                if (r_starts != 0) begin
                    if (w_lane < 60)
                        w_batch_row = 4 + w_lane/4;
                    else
                        w_batch_row = 19 + (w_lane-60)/2;
                    if ((r_input_words != ((r_starts-1)*INPUT_ROWS + w_batch_row)*INPUT_COLS) ||
                        (r_rows_started + 1 != r_input_words/INPUT_COLS) ||
                        u_system.dut.u_slave.w_ib_switch)
                        $fatal(1, "Weight prefetch missed the input-row gap for row %0d", w_batch_row);
                end
                if (w_index == WEIGHT_WORDS-1)
                    $fdisplay(u_system.r_result_file, "Time %0t: channel %0d KSP buffer %0d ready",
                              $time, r_starts, r_starts % 2);
                r_weight_words[r_starts] <= w_index + 1;
            end
            if (u_system.dut.u_slave.w_store_osp &&
                (u_system.dut.u_slave.w_nl_osp_addr >= 9'(OSP_WORDS)))
                $fatal(1, "OSP store outside the four complete output rows");
        end
    end

    generate
        for (genvar w_lane = 0; w_lane < LANES; w_lane++) begin : g_check
            initial begin
                wait ((r_waits == CHANNELS*INPUT_ROWS) && u_system.w_slave_done);
                @(negedge u_system.r_clk);
                for (int w_addr = 0; w_addr < OSP_WORDS; w_addr++) begin
                    if (u_system.dut.u_slave.g_lane[w_lane].u_osp.r_memory[w_addr] !==
                        r_expected[w_lane*OSP_WORDS+w_addr])
                        $fatal(1, "RGB OSP mismatch lane=%0d address=%0d expected=%04h actual=%04h",
                               w_lane, w_addr, r_expected[w_lane*OSP_WORDS+w_addr],
                               u_system.dut.u_slave.g_lane[w_lane].u_osp.r_memory[w_addr]);
                end
                r_checked[w_lane] = 1'b1;
            end
        end
    endgenerate

    initial begin
        $readmemh("conv1_rgb21_osp.mem", r_expected);
        wait (&r_checked);
        repeat (16) begin
            @(negedge u_system.r_clk);
            if (u_system.dut.u_master.cpu_inst.id_jump &&
                (u_system.dut.u_master.cpu_inst.jump_target_id ==
                 u_system.dut.u_master.cpu_inst.if_id_pc))
                r_saw_park = 1'b1;
        end
        if ((r_starts != CHANNELS) || (r_rows_started != 63) ||
            (r_row_events != 63) || (r_waits != 63) || (r_input_words != 14112) ||
            (r_dma_done != 255) || (r_macs != 75852) || (r_stores != 6930) || !r_saw_park)
            $fatal(1, "Counts SCR=%0d rows=%0d events=%0d waits=%0d input=%0d DMA=%0d MAC=%0d stores=%0d park=%0b",
                   r_starts, r_rows_started, r_row_events, r_waits, r_input_words,
                   r_dma_done, r_macs, r_stores, r_saw_park);
        $fdisplay(u_system.r_result_file, "Compared %0d RGB OSP words: all matched", LANES*OSP_WORDS);
        $fdisplay(u_system.r_result_file, "Channels=%0d rows=%0d waits=%0d DMA transfers=%0d MACs/lane=%0d",
                  r_starts, r_row_events, r_waits, r_dma_done, r_macs);
        $fdisplay(u_system.r_result_file, "CONV1_RGB21_TB_PASS");
        $fclose(u_system.r_result_file);
        $display("CONV1_RGB21_TB_PASS");
        $finish;
    end

    initial begin
        wait (u_system.r_rst_n);
        repeat (99990) @(negedge u_system.r_clk);
        $fatal(1, "RGB timeout: SCR=%0d row events=%0d waits=%0d master PC=%08h slave PC=%0d",
               r_starts, r_row_events, r_waits, u_system.dut.u_master.cpu_inst.if_pc,
               u_system.dut.w_slave_pc);
    end
endmodule
