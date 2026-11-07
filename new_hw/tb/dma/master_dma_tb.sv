`timescale 1ns/1ps

// Runs the real master instruction stream; no DMA CSR signals are forced.
// OM is an asynchronous-read, clocked-write testbench array. IB and OB use
// the project's single-port synchronous SRAM model, with separate memories.
module master_dma_tb;
    localparam int unsigned DATA_WIDTH = 16;
    localparam int unsigned OM_DEPTH = 256;
    localparam int unsigned LOCAL_ADDR_WIDTH = 6;
    localparam int unsigned LOCAL_DEPTH = 1 << LOCAL_ADDR_WIDTH;
    localparam int unsigned TRANSFERS = 3;
    localparam int unsigned CSR_WRITES_PER_DMA = 4 * TRANSFERS;
    localparam int unsigned MAX_CYCLES = 500;
    localparam logic [DATA_WIDTH-1:0] IB_CANARY = 16'hC35A;

    logic r_clk = 1'b0;
    logic r_rst_n = 1'b0;
    always #5 r_clk = ~r_clk;

`ifdef ENABLE_WAVES
    initial begin : DumpWaveforms
        $dumpfile("master_dma.vcd");
        $dumpvars(0, master_dma_tb);
    end
`endif

    logic [DATA_WIDTH-1:0] w_om_rdata, w_om_wdata;
    logic [31:0] w_om_raddr, w_om_waddr;
    logic w_om_ren, w_om_wen;
    logic [DATA_WIDTH-1:0] w_slave_wdata, w_ob_rdata, w_unused_ib_rdata;
    logic [31:0] w_slave_waddr, w_ob_raddr;
    logic w_slave_wen, w_ob_ren;
    logic w_dma0_done, w_dma1_done;

    logic [DATA_WIDTH-1:0] r_om [0:OM_DEPTH-1];
    logic [DATA_WIDTH-1:0] r_expected_om [0:OM_DEPTH-1];
    logic [DATA_WIDTH-1:0] r_expected_ib [0:LOCAL_DEPTH-1];

    // SRAM initialization uses the memory write ports while the DUT is reset.
    logic r_init_en;
    logic [LOCAL_ADDR_WIDTH-1:0] r_init_addr;
    logic [DATA_WIDTH-1:0] r_init_ob_data;

    int unsigned r_completed0, r_completed1;
    int unsigned r_dma0_words, r_dma1_reads, r_dma1_words;
    int unsigned r_csr_writes0, r_csr_writes1;
    int unsigned r_drain_cycles;
    logic r_previous_done0, r_previous_done1;
    logic r_dma0_wrote_this_edge, r_dma1_wrote_this_edge;
    integer r_result_file;

    master_dma_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .IMEM_INIT_FILE("master_dma_program.mem")
    ) dut (
        .i_clk(r_clk),
        .i_rst_n(r_rst_n),
        .i_om_rdata(w_om_rdata),
        .o_om_raddr(w_om_raddr),
        .o_om_ren(w_om_ren),
        .o_om_wdata(w_om_wdata),
        .o_om_waddr(w_om_waddr),
        .o_om_wen(w_om_wen),
        .o_slave_wdata(w_slave_wdata),
        .o_slave_waddr(w_slave_waddr),
        .o_slave_wen(w_slave_wen),
        .i_ob_rdata(w_ob_rdata),
        .o_ob_raddr(w_ob_raddr),
        .o_ob_ren(w_ob_ren),
        .o_dma0_done(w_dma0_done),
        .o_dma1_done(w_dma1_done)
    );

    // Off-chip payload memory is outside the DUT synthesis boundary.
    assign w_om_rdata = (w_om_ren && (w_om_raddr < OM_DEPTH))
                       ? r_om[w_om_raddr] : '0;

    always @(posedge r_clk) begin
        if (r_rst_n && w_om_wen) begin
            if ($isunknown(w_om_waddr) || (w_om_waddr >= OM_DEPTH))
                $fatal(1, "OM write address out of range: %h", w_om_waddr);
            r_om[w_om_waddr] <= w_om_wdata;
        end
    end

    mem #(
        .DATA_W(DATA_WIDTH), .ADDR_W(LOCAL_ADDR_WIDTH), .DEPTH(LOCAL_DEPTH)
    ) u_ib (
        .i_clk(r_clk),
        .i_en(r_init_en || w_slave_wen),
        .i_we(1'b1),
        .i_addr(r_init_en ? r_init_addr : w_slave_waddr[LOCAL_ADDR_WIDTH-1:0]),
        .i_wdata(r_init_en ? IB_CANARY : w_slave_wdata),
        .o_rdata(w_unused_ib_rdata)
    );

    mem #(
        .DATA_W(DATA_WIDTH), .ADDR_W(LOCAL_ADDR_WIDTH), .DEPTH(LOCAL_DEPTH)
    ) u_ob (
        .i_clk(r_clk),
        .i_en(r_init_en || w_ob_ren),
        .i_we(r_init_en),
        .i_addr(r_init_en ? r_init_addr : w_ob_raddr[LOCAL_ADDR_WIDTH-1:0]),
        .i_wdata(r_init_ob_data),
        .o_rdata(w_ob_rdata)
    );

    function automatic logic [15:0] om_pattern(input int unsigned i_index);
        return 16'h8001 ^ (i_index[15:0] * 16'h0211);
    endfunction

    function automatic logic [15:0] ob_pattern(input int unsigned i_index);
        return 16'h5A3C ^ (i_index[15:0] * 16'h0107);
    endfunction

    // Independent test expectations for the three program phases.
    function automatic int unsigned transfer_size(input int unsigned i_phase);
        case (i_phase)
            0: return 8;
            1: return 1;
            default: return 0;
        endcase
    endfunction

    function automatic logic [31:0] source_addr(
        input bit i_dma1, input int unsigned i_phase
    );
        case (i_phase)
            0: return i_dma1 ? 32'd8 : 32'd16;
            1: return i_dma1 ? 32'd24 : 32'd32;
            2: return i_dma1 ? 32'd63 : 32'd255;
            default: return 32'd0;
        endcase
    endfunction

    function automatic logic [31:0] dest_addr(
        input bit i_dma1, input int unsigned i_phase
    );
        case (i_phase)
            0: return i_dma1 ? 32'd128 : 32'd4;
            1: return i_dma1 ? 32'd160 : 32'd20;
            2: return i_dma1 ? 32'd255 : 32'd63;
            default: return 32'd0;
        endcase
    endfunction

    task automatic check_csr_write(
        input bit i_dma1, input int unsigned i_write_index
    );
        logic [31:0] w_expected_offset, w_expected_data;
        if (i_write_index >= CSR_WRITES_PER_DMA)
            $fatal(1, "Unexpected CSR write to DMA%0d", i_dma1);

        case (i_write_index % 4)
            0: begin
                w_expected_offset = 32'h00;
                w_expected_data = source_addr(i_dma1, i_write_index / 4);
            end
            1: begin
                w_expected_offset = 32'h04;
                w_expected_data = dest_addr(i_dma1, i_write_index / 4);
            end
            2: begin
                w_expected_offset = 32'h08;
                w_expected_data = transfer_size(i_write_index / 4);
            end
            default: begin
                w_expected_offset = 32'h0C;
                w_expected_data = 32'd1;
            end
        endcase

        if ((dut.w_dma_csr_offset !== w_expected_offset) ||
            (dut.w_dma_csr_data !== w_expected_data))
            $fatal(1, "DMA%0d CSR write %0d: offset/data %h/%h, expected %h/%h",
                   i_dma1, i_write_index, dut.w_dma_csr_offset,
                   dut.w_dma_csr_data, w_expected_offset, w_expected_data);
    endtask

    task automatic check_final_memories;
        for (int unsigned i = 0; i < OM_DEPTH; i++) begin
            if (r_om[i] !== r_expected_om[i])
                $fatal(1, "OM[%0d]=%h, expected %h", i, r_om[i], r_expected_om[i]);
        end
        for (int unsigned i = 0; i < LOCAL_DEPTH; i++) begin
            if (u_ib.r_memory[i] !== r_expected_ib[i])
                $fatal(1, "IB[%0d]=%h, expected %h", i,
                       u_ib.r_memory[i], r_expected_ib[i]);
        end
    endtask

    initial begin : RunTest
        r_init_en = 1'b0;
        r_init_addr = '0;
        r_init_ob_data = '0;
        r_completed0 = 0;
        r_completed1 = 0;
        r_dma0_words = 0;
        r_dma1_reads = 0;
        r_dma1_words = 0;
        r_csr_writes0 = 0;
        r_csr_writes1 = 0;
        r_drain_cycles = 0;
        r_previous_done0 = 1'b0;
        r_previous_done1 = 1'b0;
        r_dma0_wrote_this_edge = 1'b0;
        r_dma1_wrote_this_edge = 1'b0;
        r_result_file = $fopen("master_dma_result.log", "w");
        if (r_result_file == 0)
            $fatal(1, "Cannot open master_dma_result.log");

        for (int unsigned i = 0; i < OM_DEPTH; i++) begin
            r_om[i] = om_pattern(i);
            r_expected_om[i] = om_pattern(i);
        end
        for (int unsigned i = 0; i < LOCAL_DEPTH; i++)
            r_expected_ib[i] = IB_CANARY;

        for (int unsigned phase = 0; phase < TRANSFERS; phase++) begin
            for (int unsigned word_index = 0;
                 word_index < transfer_size(phase); word_index++) begin
                r_expected_ib[dest_addr(1'b0, phase) + word_index] =
                    om_pattern(source_addr(1'b0, phase) + word_index);
                r_expected_om[dest_addr(1'b1, phase) + word_index] =
                    ob_pattern(source_addr(1'b1, phase) + word_index);
            end
        end

        // The last location is written on the edge before reset is released.
        for (int unsigned i = 0; i < LOCAL_DEPTH; i++) begin
            @(negedge r_clk);
            if ({w_om_ren, w_om_wen, w_slave_wen, w_ob_ren,
                 w_dma0_done, w_dma1_done} !== 6'b0)
                $fatal(1, "DMA outputs must be idle during reset");
            r_init_en = 1'b1;
            r_init_addr = i[LOCAL_ADDR_WIDTH-1:0];
            r_init_ob_data = ob_pattern(i);
        end
        @(negedge r_clk);
        r_init_en = 1'b0;
        r_rst_n = 1'b1;

        for (int unsigned cycle = 0; cycle < MAX_CYCLES; cycle++) begin
            @(posedge r_clk);
            // These checks sample requests/data before the accepting edge's NBA
            // updates. Done is checked below, after those updates have settled.
            if ($isunknown({w_om_ren, w_om_wen, w_slave_wen, w_ob_ren,
                            dut.w_wen_dma0, dut.w_wen_dma1}))
                $fatal(1, "Unknown memory or CSR write enable");
            if (dut.w_wen_dma0 && dut.w_wen_dma1)
                $fatal(1, "A DMA_CONFIG instruction selected both DMAs");
            if (dut.w_wen_dma0) begin
                check_csr_write(1'b0, r_csr_writes0);
                r_csr_writes0++;
            end
            if (dut.w_wen_dma1) begin
                check_csr_write(1'b1, r_csr_writes1);
                r_csr_writes1++;
            end

            r_dma0_wrote_this_edge = w_slave_wen;
            r_dma1_wrote_this_edge = w_om_wen;
            if (w_om_ren !== w_slave_wen)
                $fatal(1, "Each DMA0 input write requires one OM read");
            if (w_slave_wen) begin
                if ((r_completed0 >= TRANSFERS) ||
                    (r_dma0_words >= transfer_size(r_completed0)))
                    $fatal(1, "DMA0 issued an extra word or an empty-transfer access");
                if ($isunknown({w_om_raddr, w_slave_waddr}) ||
                    (w_om_raddr >= OM_DEPTH) || (w_slave_waddr >= LOCAL_DEPTH))
                    $fatal(1, "DMA0 address out of range");
                if ((w_om_raddr !== source_addr(1'b0, r_completed0) + r_dma0_words) ||
                    (w_slave_waddr !== dest_addr(1'b0, r_completed0) + r_dma0_words))
                    $fatal(1, "DMA0 address sequence mismatch");
                if (w_slave_wdata !== om_pattern(source_addr(1'b0, r_completed0) + r_dma0_words))
                    $fatal(1, "DMA0 data mismatch at word %0d", r_dma0_words);
                r_dma0_words++;
            end

            if (w_ob_ren) begin
                if ((r_completed1 >= TRANSFERS) ||
                    (r_dma1_reads >= transfer_size(r_completed1)))
                    $fatal(1, "DMA1 issued an extra OB read or an empty-transfer access");
                if ($isunknown(w_ob_raddr) || (w_ob_raddr >= LOCAL_DEPTH))
                    $fatal(1, "DMA1 OB address out of range");
                if (w_ob_raddr !== source_addr(1'b1, r_completed1) + r_dma1_reads)
                    $fatal(1, "DMA1 OB address sequence mismatch");
                r_dma1_reads++;
            end
            if (w_om_wen) begin
                if ((r_completed1 >= TRANSFERS) ||
                    (r_dma1_words >= transfer_size(r_completed1)))
                    $fatal(1, "DMA1 issued an extra OM write or an empty-transfer access");
                if (w_om_waddr !== dest_addr(1'b1, r_completed1) + r_dma1_words)
                    $fatal(1, "DMA1 OM address sequence mismatch");
                if (w_om_wdata !== ob_pattern(source_addr(1'b1, r_completed1) + r_dma1_words))
                    $fatal(1, "DMA1 data mismatch at word %0d", r_dma1_words);
                r_dma1_words++;
            end

            #1;
            if ($isunknown({w_dma0_done, w_dma1_done}))
                $fatal(1, "Unknown done output");
            if ((w_dma0_done && r_previous_done0) ||
                (w_dma1_done && r_previous_done1))
                $fatal(1, "Done must be a one-clock pulse");

            if (w_dma0_done) begin
                if ((r_completed0 >= TRANSFERS) ||
                    (r_dma0_words != transfer_size(r_completed0)))
                    $fatal(1, "DMA0 done with an incorrect word count");
                if ((transfer_size(r_completed0) != 0) && !r_dma0_wrote_this_edge)
                    $fatal(1, "DMA0 done did not coincide with its final write");
                $fdisplay(r_result_file, "DMA0 phase %0d: %0d words", r_completed0, r_dma0_words);
                r_completed0++;
                r_dma0_words = 0;
            end
            if (w_dma1_done) begin
                if ((r_completed1 >= TRANSFERS) ||
                    (r_dma1_words != transfer_size(r_completed1)) ||
                    (r_dma1_reads != transfer_size(r_completed1)))
                    $fatal(1, "DMA1 done with an incorrect read/write count");
                if ((transfer_size(r_completed1) != 0) && !r_dma1_wrote_this_edge)
                    $fatal(1, "DMA1 done did not coincide with its final write");
                $fdisplay(r_result_file, "DMA1 phase %0d: %0d words", r_completed1, r_dma1_words);
                r_completed1++;
                r_dma1_reads = 0;
                r_dma1_words = 0;
            end
            r_previous_done0 = w_dma0_done;
            r_previous_done1 = w_dma1_done;

            if ((r_completed0 == TRANSFERS) && (r_completed1 == TRANSFERS)) begin
                r_drain_cycles++;
                if (r_drain_cycles >= 4) begin
                    if ((r_csr_writes0 != CSR_WRITES_PER_DMA) ||
                        (r_csr_writes1 != CSR_WRITES_PER_DMA))
                        $fatal(1, "Incorrect number of DMA CSR writes");
                    check_final_memories();
                    $fdisplay(r_result_file, "MASTER_DMA_TB_PASS");
                    $fclose(r_result_file);
                    $display("MASTER_DMA_TB_PASS: each DMA completed 8-word, 1-word and 0-word transfers");
                    $finish;
                end
            end
        end
        $fatal(1, "Timeout: DMA0 completed %0d phases, DMA1 completed %0d phases",
               r_completed0, r_completed1);
    end
endmodule
