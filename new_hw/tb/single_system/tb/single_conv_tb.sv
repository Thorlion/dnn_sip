`timescale 1ns/1ps

module single_conv_tb # (
    parameter int     LAYER_ID           = 2
);
    localparam bit    IS_CONV1           = LAYER_ID == 3;
    localparam bit    IS_CONV2           = LAYER_ID == 2;
    localparam bit    IS_CONV3           = LAYER_ID == 3;
    localparam bit    IS_CONV4           = LAYER_ID == 4;
    localparam bit    IS_CONV5           = LAYER_ID == 5;
    localparam string LAYER              = IS_CONV1 ? "CONV1" : IS_CONV2 ? "CONV2" : IS_CONV3 ? "CONV3" :
                                           IS_CONV4 ? "CONV4" : "CONV5";

    localparam int    INPUT_SIZE         = IS_CONV1 ? 224 : IS_CONV2 ? 27 : 13;
    localparam int    OUTPUT_SIZE        = IS_CONV1 ? 55 : INPUT_SIZE;
    localparam int    KERNEL_SIZE        = IS_CONV1 ? 11 : IS_CONV2 ? 5 : 3;
    localparam int    STRIDE             = IS_CONV1 ? 4 : 1;
    localparam int    PADDING            = IS_CONV1 || IS_CONV2 ? 2 : 1;
    localparam int    CHANNELS           = IS_CONV1 ? 3 : IS_CONV2 ? 96 : IS_CONV3 ? 256 : 384;
    localparam int    GROUPS             = IS_CONV2 || IS_CONV4 || IS_CONV5 ? 2 : 1;
    localparam int    CHANNELS_PER_GROUP = CHANNELS / GROUPS;
    localparam int    LANES              = 64;
    localparam int    FILTERS            = IS_CONV1 ? 96 : IS_CONV2 || IS_CONV5 ? 256 : 384;
    localparam int    FILTERS_PER_GROUP  = FILTERS / GROUPS;
    localparam int    BATCHES            = (FILTERS + LANES - 1) / LANES;
    localparam int    VALID_TAPS         = IS_CONV1 ? 602 : IS_CONV2 ? 129 : 37;

    localparam int    OB_WORDS           = 1024;
    localparam int    OUTPUT_WORDS       = OUTPUT_SIZE * OUTPUT_SIZE * FILTERS;
    localparam int    FULL_BLOCKS        = OUTPUT_WORDS / OB_WORDS;
    localparam int    TAIL_WORDS         = OUTPUT_WORDS % OB_WORDS;
    localparam int    OUTPUT_BASE        = IS_CONV1 ? 'h40000 : IS_CONV2 ? 'h90000 : 'h110000;
    localparam int    TIMEOUT            = IS_CONV1 ? 3500000 : IS_CONV2 ? 8500000 : 10000000;
    localparam int    WEIGHT_WORDS       = FILTERS * CHANNELS_PER_GROUP * KERNEL_SIZE * KERNEL_SIZE;

    int unsigned r_om_words     = 0;
    int unsigned r_ob_words     = 0;
    int unsigned r_ob_reads     = 0;
    int unsigned r_blocks       = 0;
    int unsigned r_macs         = 0;
    int unsigned r_slave_issues = 0;
    integer      r_feature_map;

    single_system_tb # (
        .MASTER_IMEM_FILE (IS_CONV1 ? "conv1_master_imem.mem" :
                           IS_CONV2 ? "conv2_master_imem.mem" :
                           IS_CONV3 ? "conv3_master_imem.mem" :
                           IS_CONV4 ? "conv4_master_imem.mem" : "conv5_master_imem.mem"),
        .SLAVE_IMEM_FILE  (IS_CONV1 ? "conv1_slave_imem.mem" :
                           IS_CONV2 ? "conv2_slave_imem.mem" :
                           IS_CONV3 ? "conv3_slave_imem.mem" :
                           IS_CONV4 ? "conv4_slave_imem.mem" : "conv5_slave_imem.mem"),
        .OM_DEPTH         (IS_CONV1 || IS_CONV2 ? 1048576 : 2097152),
        .MAX_CYCLES       (TIMEOUT + 1),
        .CONV1_BIAS_FILE  (""),
        .LOG_OM_WRITES    (1'b0),
        .CONV1_FILTERS    (FILTERS),
        .CONV1_BIAS_BASE  (IS_CONV4 || IS_CONV5 ? 'h10D000 : 'h35000 + WEIGHT_WORDS),
        .IMAGE_FILE       (IS_CONV1 ? "input_img.mem" : IS_CONV2 ? "conv2_input.mem" :
                           IS_CONV3 ? "conv3_input.mem" : IS_CONV4 ? "conv4_input.mem" : "conv5_input.mem"),
        .WEIGHT_FILE      (IS_CONV1 ? "conv1_weight.mem" : IS_CONV2 ? "conv2_weight.mem" :
                           IS_CONV3 ? "conv3_weight.mem" : IS_CONV4 ? "conv4_weight.mem" : "conv5_weight.mem"),
        .IMAGE_WORDS      (CHANNELS * INPUT_SIZE * INPUT_SIZE),
        .WEIGHT_WORDS     (WEIGHT_WORDS),
        .BIAS_WORDS       (IS_CONV1 ? FILTERS : 1)
    ) u_system ();

    // Reference each output directly from the original OM input and weights.
    function automatic logic [15:0] expected_word(input int i_index);
        int filter, first_channel, oy, ox, y, x, image_addr, weight_addr;
        int signed pixel, weight, total;
        filter = i_index % FILTERS;
        first_channel = (filter / FILTERS_PER_GROUP) * CHANNELS_PER_GROUP;
        ox = i_index / FILTERS % OUTPUT_SIZE;
        oy = i_index / FILTERS / OUTPUT_SIZE;
        total = 0;
        for (int channel = 0; channel < CHANNELS_PER_GROUP; channel++) begin
            for (int ky = 0; ky < KERNEL_SIZE; ky++) begin
                for (int kx = 0; kx < KERNEL_SIZE; kx++) begin
                    y = STRIDE * oy - PADDING + ky;
                    x = STRIDE * ox - PADDING + kx;
                    if (y >= 0 && y < INPUT_SIZE && x >= 0 && x < INPUT_SIZE) begin
                        image_addr = 'h10000 + ((first_channel + channel) * INPUT_SIZE + y) * INPUT_SIZE + x;
                        weight_addr = 'h35000 +
                                      ((filter * CHANNELS_PER_GROUP + channel) * KERNEL_SIZE + ky) * KERNEL_SIZE + kx;
                        pixel = int'($signed(u_system.r_om[image_addr]));
                        weight = int'($signed(u_system.r_om[weight_addr]));
                        total += (pixel * weight) >>> 8;
                    end
                end
            end
        end
        return total[15:0];
    endfunction

    always @(posedge u_system.r_clk) begin : CheckTransfers
        if (u_system.r_rst_n) begin
            if (u_system.dut.u_slave.w_issue)
                r_slave_issues <= r_slave_issues + 1;
            if (u_system.dut.u_slave.w_load_ib && u_system.dut.u_slave.w_load_ksp)
                r_macs <= r_macs + 1;
            if (u_system.dut.w_ib_we && u_system.dut.u_slave.w_load_ib &&
                u_system.dut.w_ib_wbuf_sel == u_system.dut.u_slave.w_ib_rbuf_sel)
                $fatal(1, "DMA0 writes the active input bank");
            if (u_system.dut.u_slave.w_store_ob)
                r_ob_words <= r_ob_words + 1;
            if (u_system.dut.w_ob_ren) begin
                if (u_system.dut.u_slave.w_store_ob &&
                    u_system.dut.u_slave.w_nl_ob_wbuf_sel == u_system.dut.w_ob_rbuf_sel)
                    $fatal(1, "DMA1 reads the active OB write bank");
                if (r_ob_reads >= OUTPUT_WORDS || u_system.dut.w_ob_raddr != 10'(r_ob_reads) ||
                    u_system.dut.w_ob_rbuf_sel != 1'(r_ob_reads / OB_WORDS))
                    $fatal(1, "Unexpected OB read for word %0d", r_ob_reads);
                if ((r_ob_reads % OB_WORDS == 0) &&
                    (r_ob_words < (r_ob_reads < FULL_BLOCKS * OB_WORDS ? r_ob_reads + OB_WORDS : OUTPUT_WORDS)))
                    $fatal(1, "DMA1 started before the OB block was filled");
                r_ob_reads <= r_ob_reads + 1;
            end

            if (u_system.w_om_wen) begin
                logic [15:0] w_expected;
                if (r_om_words >= OUTPUT_WORDS || u_system.w_om_waddr != OUTPUT_BASE + r_om_words)
                    $fatal(1, "Unexpected OM address %08h at word %0d", u_system.w_om_waddr, r_om_words);
                w_expected = expected_word(r_om_words);
                if (u_system.w_om_wdata !== w_expected)
                    $fatal(1, "%s mismatch y=%0d x=%0d filter=%0d expected=%04h actual=%04h",
                           LAYER, r_om_words / FILTERS / OUTPUT_SIZE, r_om_words / FILTERS % OUTPUT_SIZE,
                           r_om_words % FILTERS, w_expected, u_system.w_om_wdata);
                r_om_words <= r_om_words + 1;
            end

            if (u_system.w_dma1_done) begin
                if (r_blocks > FULL_BLOCKS || r_om_words !=
                    (r_blocks < FULL_BLOCKS ? (r_blocks + 1) * OB_WORDS : OUTPUT_WORDS))
                    $fatal(1, "DMA1 ended at word %0d for block %0d", r_om_words, r_blocks);
                r_blocks <= r_blocks + 1;
            end
        end
    end

    initial begin : WriteFeatureMap
        wait (r_blocks == FULL_BLOCKS + 1);
        @(negedge u_system.r_clk);
        if (r_om_words != OUTPUT_WORDS || r_ob_words != OUTPUT_WORDS ||
            r_ob_reads != OUTPUT_WORDS || r_macs != BATCHES * CHANNELS_PER_GROUP * VALID_TAPS * VALID_TAPS)
            $fatal(1, "Unexpected counts OM=%0d OB=%0d OB reads=%0d MAC issue cycles=%0d",
                   r_om_words, r_ob_words, r_ob_reads, r_macs);

        r_feature_map = $fopen(IS_CONV1 ? "conv1_feature_map.mem" :
                              IS_CONV2 ? "conv2_feature_map.mem" :
                              IS_CONV3 ? "conv3_feature_map.mem" :
                              IS_CONV4 ? "conv4_feature_map.mem" : "conv5_feature_map.mem", "w");
        if (r_feature_map == 0)
            $fatal(1, "Cannot open feature map output file");
        for (int word_index = 0; word_index < OUTPUT_WORDS; word_index++)
            $fdisplay(r_feature_map, "%04h", u_system.r_om[OUTPUT_BASE + word_index]);
        $fclose(r_feature_map);

        $fdisplay(u_system.r_result_file, "Time %0t: all %0d feature-map words matched",
                  $time, OUTPUT_WORDS);
        $fdisplay(u_system.r_result_file, "DMA1: %0d x %0d words, final %0d words",
                  FULL_BLOCKS, OB_WORDS, TAIL_WORDS);
        $fdisplay(u_system.r_result_file, "Slave issued %0d instructions, including %0d MAC cycles",
                  r_slave_issues, r_macs);
        $fdisplay(u_system.r_result_file, "%s_FULL_TB_PASS", LAYER);
        $fclose(u_system.r_result_file);
        $display("%s_FULL_TB_PASS", LAYER);
        $finish;
    end

    initial begin : CheckTimeout
        wait (u_system.r_rst_n);
        repeat (TIMEOUT) @(negedge u_system.r_clk);
        $fatal(1, "%s timeout: OM words=%0d master PC=%08h slave PC=%0d",
               LAYER, r_om_words, u_system.dut.u_master.cpu_inst.if_pc, u_system.dut.w_slave_pc);
    end
endmodule
