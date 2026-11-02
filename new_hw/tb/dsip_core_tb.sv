`timescale 1ns/1ps

// Core stimulus scaffold. Only IMEM loading is implemented here.
// IB/KSP loading and current-address updates will be specified separately.
module dsip_core_tb;
    localparam int unsigned PC_W = 9;
    localparam int unsigned INSTR_W = 58;
    localparam int unsigned DATA_W = 16;
    localparam int unsigned LANES = 64;
    localparam int unsigned IMEM_DEPTH = 2 ** PC_W;
    localparam time CLK_PERIOD = 10;

    logic r_clk = 1'b0;
    logic r_rst_n;
    logic r_start;
    logic r_pc_en;
    logic r_imem_we;
    logic [PC_W-1:0] r_imem_waddr;
    logic [INSTR_W-1:0] r_imem_wdata;
    logic [INSTR_W-1:0] r_imem_image [0:IMEM_DEPTH-1];

    logic [9:0] r_ib_addr;
    logic [8:0] r_ksp_addr;
    logic [8:0] r_osp_addr;
    logic [5:0] r_bsp_addr;
    logic [LANES-1:0] r_ksp_en;
    logic [LANES-1:0] r_ksp_we;
    logic [DATA_W-1:0] r_ksp_wdata [0:LANES-1];
    logic [LANES-1:0] r_osp_en;
    logic [LANES-1:0] r_osp_we;
    logic r_ib_en;
    logic r_ib_we;
    logic [DATA_W-1:0] r_ib_wdata;
    logic r_bsp_en;
    logic r_bsp_we;
    logic [DATA_W-1:0] r_bsp_wdata;

    wire [PC_W-1:0] w_pc;
    wire [8:0] w_exe_instruction;
    wire w_exe_valid;
    wire [1:0] w_nl_instruction;
    wire w_nl_valid;
    wire w_pc_load;
    wire [PC_W-1:0] w_pc_target;
    wire [9:0] w_ib_addr;
    wire [8:0] w_ksp_addr;
    wire [8:0] w_osp_addr;
    wire [5:0] w_bsp_addr;
    wire [DATA_W-1:0] w_ksp_rdata [0:LANES-1];
    wire [DATA_W-1:0] w_osp_rdata [0:LANES-1];
    wire [DATA_W-1:0] w_ib_rdata;
    wire [DATA_W-1:0] w_bsp_rdata;
    wire signed [DATA_W-1:0] w_mli_out [0:LANES-1];
    wire signed [DATA_W-1:0] w_mlk_out [0:LANES-1];
    wire signed [DATA_W-1:0] w_mlo_out [0:LANES-1];
    wire signed [DATA_W-1:0] w_eoa_out [0:LANES-1];

    string r_imem_path;
    integer r_run_cycles;
    integer r_unused;
    integer r_log;
    integer r_cycle;
    logic r_trace_en;

    always #(CLK_PERIOD / 2) r_clk = ~r_clk;

    dsip_core #(.PC_W(PC_W)) u_core (
        .i_clk(r_clk),
        .i_rst_n(r_rst_n),
        .i_start(r_start),
        .i_pc_en(r_pc_en),
        .o_pc(w_pc),
        .i_imem_we(r_imem_we),
        .i_imem_waddr(r_imem_waddr),
        .i_imem_wdata(r_imem_wdata),
        .o_exe_instruction(w_exe_instruction),
        .o_exe_valid(w_exe_valid),
        .o_nl_instruction(w_nl_instruction),
        .o_nl_valid(w_nl_valid),
        .o_pc_load(w_pc_load),
        .o_pc_target(w_pc_target),
        .i_ib_addr(r_ib_addr),
        .i_ksp_addr(r_ksp_addr),
        .i_osp_addr(r_osp_addr),
        .i_bsp_addr(r_bsp_addr),
        .o_ib_addr(w_ib_addr),
        .o_ksp_addr(w_ksp_addr),
        .o_osp_addr(w_osp_addr),
        .o_bsp_addr(w_bsp_addr),
        .i_ksp_en(r_ksp_en),
        .i_ksp_we(r_ksp_we),
        .i_ksp_wdata(r_ksp_wdata),
        .o_ksp_rdata(w_ksp_rdata),
        .i_osp_en(r_osp_en),
        .i_osp_we(r_osp_we),
        .o_osp_rdata(w_osp_rdata),
        .i_ib_en(r_ib_en),
        .i_ib_we(r_ib_we),
        .i_ib_wdata(r_ib_wdata),
        .o_ib_rdata(w_ib_rdata),
        // These ports are currently bypassed inside the core; keep them high.
        .i_mli_en({LANES{1'b1}}),
        .i_mlk_en({LANES{1'b1}}),
        .i_mlo_en({LANES{1'b1}}),
        .o_mli_out(w_mli_out),
        .o_mlk_out(w_mlk_out),
        .o_mlo_out(w_mlo_out),
        .i_eoa_en({LANES{1'b1}}),
        .o_eoa_out(w_eoa_out),
        .i_bsp_en(r_bsp_en),
        .i_bsp_we(r_bsp_we),
        .i_bsp_wdata(r_bsp_wdata),
        .o_bsp_rdata(w_bsp_rdata)
    );

    task automatic load_imem;
        integer r_file;
        integer r_addr;
        begin
            r_file = $fopen(r_imem_path, "r");
            if (!r_file)
                $fatal(1, "Cannot open IMEM instruction file: %s", r_imem_path);
            $fclose(r_file);

            // Unspecified IMEM words contain the zero instruction.
            // Data memories are deliberately not initialized by this task.
            for (r_addr = 0; r_addr < IMEM_DEPTH; r_addr = r_addr + 1)
                r_imem_image[r_addr] = '0;
            $readmemb(r_imem_path, r_imem_image);

            // Set up each write on a falling edge for the next rising edge.
            for (r_addr = 0; r_addr < IMEM_DEPTH; r_addr = r_addr + 1) begin
                @(negedge r_clk);
                r_imem_we = 1'b1;
                r_imem_waddr = r_addr[PC_W-1:0];
                r_imem_wdata = r_imem_image[r_addr];
            end
            @(negedge r_clk);
            r_imem_we = 1'b0;
            r_imem_waddr = '0;
            r_imem_wdata = '0;
            $display("IMEM programmed from %s (%0d locations).", r_imem_path, IMEM_DEPTH);
        end
    endtask

    task automatic load_ib;
        begin
            // TODO: IB loading sequence to be specified by the user.
        end
    endtask

    task automatic load_ksp;
        begin
            // TODO: KSP loading sequence to be specified by the user.
        end
    endtask

    // Pre-edge samples describe the instruction and store being accepted on
    // this rising edge. Hierarchical references below are observation only.
    always @(posedge r_clk) begin
        if (r_trace_en) begin
            $fdisplay(r_log,
                "%0d | %0d | %b | %015h | %b:%03h | %b:%01h | %b:%0d | %0d,%0d,%0d,%0d | %016h:%0d | %0d",
                r_cycle, w_pc, u_core.w_issue, u_core.w_decode_instruction,
                w_exe_valid, w_exe_instruction, w_nl_valid, w_nl_instruction,
                w_pc_load, w_pc_target, w_ib_addr, w_ksp_addr, w_osp_addr, w_bsp_addr,
                u_core.w_osp_we, u_core.w_nl_osp_addr, $signed(w_eoa_out[0]));
            r_cycle = r_cycle + 1;
        end
    end

    initial begin
        r_rst_n = 1'b0;
        r_start = 1'b0;
        r_pc_en = 1'b0;
        r_imem_we = 1'b0;
        r_imem_waddr = '0;
        r_imem_wdata = '0;
        r_ib_addr = '0;
        r_ksp_addr = '0;
        r_osp_addr = '0;
        r_bsp_addr = '0;
        r_ksp_en = '1;
        r_ksp_we = '0;
        r_osp_en = '1;
        r_osp_we = '1;
        r_ib_en = 1'b1;
        r_ib_we = 1'b0;
        r_ib_wdata = '0;
        r_bsp_en = 1'b1;
        r_bsp_we = 1'b0;
        r_bsp_wdata = '0;
        for (int r_lane = 0; r_lane < LANES; r_lane = r_lane + 1)
            r_ksp_wdata[r_lane] = '0;

        r_trace_en = 1'b0;
        r_cycle = 0;
        r_imem_path = "../../new_sw/core_instruction/core_imem_instr.txt";
        r_run_cycles = 64;
        r_unused = $value$plusargs("IMEM_FILE=%s", r_imem_path);
        r_unused = $value$plusargs("RUN_CYCLES=%d", r_run_cycles);
        if (r_run_cycles < 1)
            $fatal(1, "RUN_CYCLES must be positive");

        r_log = $fopen("core_output.log", "w");
        if (!r_log)
            $fatal(1, "Cannot open core_output.log");
        $fdisplay(r_log, "DSIP core trace; pre-edge samples, EOA lane 0 is signed fixed point (8 fractional bits).");
        $fdisplay(r_log, "IB/KSP loading is pending; data memories are not initialized. Current address inputs stay at zero.");
        $fdisplay(r_log, "CYCLE | PC | IF_VALID | IF_WORD | EXE_VALID:WORD | NL_VALID:WORD | PC_LOAD:TARGET | IB,KSP,OSP,BSP_ADDR | OSP_WE:WRITE_ADDR | EOA0");

        repeat (3) @(negedge r_clk);
        load_imem();
        @(negedge r_clk);
        r_rst_n = 1'b1;
        load_ib();
        load_ksp();

        // TODO: current-address stimulus/feedback will be specified separately.
        // Do not connect an AGU output combinationally back to its input.
        @(negedge r_clk);
        r_pc_en = 1'b1;
        r_trace_en = 1'b1;
        r_start = 1'b1;
        @(negedge r_clk);
        r_start = 1'b0;

        // Count the start/fetch edge as the first of RUN_CYCLES clocks.
        // This is a testbench duration, not a core halt instruction.
        repeat (r_run_cycles - 1) @(negedge r_clk);
        r_trace_en = 1'b0;
        $fdisplay(r_log, "DSIP_CORE_TB_COMPLETE cycles=%0d", r_cycle);
        $fclose(r_log);
        $display("DSIP_CORE_TB_COMPLETE: %0d cycles; see core_output.log. No arithmetic comparison performed.", r_cycle);
        $finish;
    end
endmodule
