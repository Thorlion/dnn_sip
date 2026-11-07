// Structural connection of the PC, AGU, datapath and memories.
// All memories contain 16-bit words:
//   KSP: two buffers x 64 banks x 256 words (64 KiB total).
//   OSP: 64 banks x 512 words (1 KiB per bank).
//   IB:  two buffers x 1024 words (4 KiB total).
//   BSP: one bank x 64 words (128 bytes).
//   OB:  two buffers x 1024 words (4 KiB total).
//
// The caller supplies programming controls and bank/buffer masks.
// IMEM -> dec_if supplies flow control, address offsets and memory-load fields.
// AGU outputs drive read addresses; OSP stores use the pipelined IF address.
// AGU owns the IB/KSP/OSP/BSP feedback registers and the OB store-address counter.
// A selected OSP word and BSP feed MLOM/MLB, a wrapping adder and a dummy LUT.
// Instruction switch bits toggle the IB/KSP read and OB write buffers on issue.
// The same instruction uses the new buffer; OB's resolved ID follows its store.
// Address-counter widths: IB 10, KSP 8, OSP 9, BSP 6 bits.
// Instruction magnitudes: IB 3, KSP 7, OSP 9, BSP 3 bits, each with sign.
// IB/OSP/BSP also have clear controls; KSP always uses address feedback.
// DONE stops IF issue and locks the PC. Existing ML/EXE/NL operations drain;
// o_done then stays high until reset or a new start.
// ROW_DONE emits one completion pulse after its instruction's final store;
// it does not stop instruction issue or hold the PC.
// Each bank performs one synchronous read or write per enabled rising edge.
module dsip_slave #(
    parameter int unsigned PC_W = 9,
    parameter IMEM_INIT_FILE = ""
)(
    input  logic                 i_clk,
    input  logic                 i_rst_n,

    // Start/restart at this instruction index (the slave-PC bits of master rs1).
    input  logic                 i_start,
    input  logic [PC_W-1:0]      i_start_pc,
    input  logic                 i_pc_en,
    output logic [PC_W-1:0]      o_pc,
    output logic                 o_done,
    output logic                 o_row_done,

    // IMEM programming uses four 16-bit words per 64-bit instruction record.
    // Word address = {instruction index, word select}; low word is written first.
    // Writes pause instruction issue. Program all four words before execution.
    input  logic                 i_imem_we,
    input  logic [PC_W+1:0]      i_imem_waddr,
    input  logic [15:0]          i_imem_wdata,

    // Remaining instruction fields forwarded to the EXE-stage input.
    output logic [8:0]           o_exe_instruction,
    output logic                 o_exe_valid,

    // Remaining store fields forwarded to the nonlinear-stage input.
    output logic [1:0]           o_nl_instruction,
    output logic                 o_nl_valid,

    // AGU branch outputs are also exposed for observation.
    output logic                 o_pc_load,
    output logic [PC_W-1:0]      o_pc_target,

    output logic [9:0]           o_ib_addr,
    output logic [7:0]           o_ksp_addr,
    output logic [8:0]           o_osp_addr,
    output logic [5:0]           o_bsp_addr,
    output logic [9:0]           o_ob_addr,

    input  logic [63:0]          i_ksp_en,
    input  logic [63:0]          i_ksp_we,
    // The instruction switches the read buffer; DMA supplies write controls.
    input  logic                 i_ksp_wbuf_sel,
    input  logic [7:0]           i_ksp_waddr,
    input  logic [15:0]          i_ksp_wdata [0:63],
    output logic [15:0]          o_ksp_rdata [0:63],

    input  logic [63:0]          i_osp_en,
    // Per-lane store mask, qualified by the decoded Store OSP instruction.
    input  logic [63:0]          i_osp_we,
    output logic [15:0]          o_osp_rdata [0:63],

    // One-cycle synchronous OB reads; the instruction switches the write buffer.
    // Different buffers can read/write together. Same-buffer writes win.
    input  logic                 i_ob_ren,
    input  logic [9:0]           i_ob_raddr,
    input  logic                 i_ob_rbuf_sel,
    output logic [15:0]          o_ob_rdata,

    input  logic                 i_ib_en,
    input  logic                 i_ib_we,
    input  logic                 i_ib_wbuf_sel,
    input  logic [9:0]           i_ib_waddr,
    input  logic [15:0]          i_ib_wdata,
    output logic [15:0]          o_ib_rdata,

    // Temporary: operand/EOA enable ports are retained, but their internal
    // lane masks are tied high. EOA still requires a valid MAC instruction.
    input  logic [63:0]          i_mli_en,
    input  logic [63:0]          i_mlk_en,
    input  logic [63:0]          i_mlo_en,
    output logic signed [15:0]   o_mli_out [0:63],
    output logic signed [15:0]   o_mlk_out [0:63],
    output logic signed [15:0]   o_mlo_out [0:63],

    input  logic [63:0]          i_eoa_en,
    output logic signed [15:0]   o_eoa_out [0:63],

    input  logic                 i_bsp_en,
    input  logic                 i_bsp_we,
    input  logic [5:0]           i_bsp_waddr,
    input  logic [15:0]          i_bsp_wdata,
    output logic [15:0]          o_bsp_rdata
);
    localparam int DATA_W = 16;
    localparam int LANES = 64;
    localparam int IB_ADDR_W = 10;
    localparam int KSP_ADDR_W = 8;
    localparam int OSP_ADDR_W = 9;
    localparam int BSP_ADDR_W = 6;
    localparam int OB_ADDR_W = 10;

    logic signed [DATA_W-1:0] w_dalu_result [0:LANES-1];
    logic signed [DATA_W-1:0] w_seoa [0:LANES-1];
    logic [DATA_W-1:0] w_osp_mux_data;
    logic signed [DATA_W-1:0] w_mlom_out;
    logic signed [DATA_W-1:0] w_mlb_out;
    logic signed [DATA_W-1:0] w_bias_sum;
    logic signed [DATA_W-1:0] w_lut_out;
    logic [5:0] w_osp_mux_sel;
    logic [5:0] w_ml_osp_mux_sel;
    logic w_ob_wbuf_sel;
    logic w_ob_switch;
    logic r_ob_active_buf;
    logic w_ml_ob_wbuf_sel;
    logic w_exe_ob_wbuf_sel;
    logic w_nl_ob_wbuf_sel;
    logic w_ob_read_en;
    logic r_ob_read_buf_sel;
    logic [DATA_W-1:0] w_ob_buffer_rdata [0:1];

    logic w_mult_sel_1;
    logic w_mult_sel_2;
    logic [1:0] w_acc_sel;
    logic w_mac_en;
    logic w_store_osp;
    logic w_store_ob;
    logic [LANES-1:0] w_osp_we;
    logic [OSP_ADDR_W-1:0] w_ml_osp_addr;
    logic [OSP_ADDR_W-1:0] w_exe_osp_addr;
    logic [OSP_ADDR_W-1:0] w_nl_osp_addr;

    logic [63:0] w_instruction;
    logic [63:0] w_decode_instruction;
    logic [8:0] w_ml_instruction;
    logic w_ml_instruction_valid;
    logic [PC_W-1:0] w_imem_raddr;
    logic w_pc_running;
    logic w_fetch;
    logic w_issue;
    logic r_instruction_valid;
    logic w_done_instruction;
    logic [2:0] r_done_pipe;
    logic w_row_done_instruction;
    logic [2:0] r_row_done_pipe;

    logic [5:0] w_set_iteration;
    logic [2:0] w_set_breakpoint;
    logic [2:0] w_conditional_loop;
    logic w_ib_rbuf_sel;
    logic w_ib_switch;
    logic r_ib_active_buf;
    logic w_ib_clear;
    logic w_ib_sign;
    logic [2:0] w_ib_offset;
    logic w_ksp_rbuf_sel;
    logic w_ksp_switch;
    logic r_ksp_active_buf;
    logic w_ksp_sign;
    logic [6:0] w_ksp_offset;
    logic w_osp_clear;
    logic w_osp_sign;
    logic [8:0] w_osp_offset;
    logic w_bsp_clear;
    logic w_bsp_sign;
    logic [2:0] w_bsp_offset;
    logic w_load_ib;
    logic w_load_ksp;
    logic w_load_osp;
    logic w_load_bsp;

    logic w_ib_read_en;
    logic [LANES-1:0] w_ksp_read_en;
    logic [DATA_W-1:0] w_ib_buffer_rdata [0:1];
    logic [DATA_W-1:0] w_ksp_buffer_rdata [0:1][0:LANES-1];
    logic r_ib_read_buf_sel;
    logic [LANES-1:0] r_ksp_read_buf_sel;

    // Start/restart loads the PC and fetches i_start_pc on the same edge.
    // Suppress the old fetched instruction while start is asserted.
    // Once valid, the current instruction issues
    // while IMEM reads the next PC value on the same edge. PC and IMEM output
    // therefore stay aligned, including when the AGU requests a branch.
    // Priority is start/restart, then AGU branch, then enabled advancement.
    assign w_fetch = i_rst_n && (w_pc_running || i_start) &&
                     !i_imem_we && !w_done_instruction;
    assign w_issue = i_rst_n && w_pc_running &&
                     r_instruction_valid && !i_imem_we && !i_start;
    assign w_decode_instruction = w_issue ? w_instruction : 64'd0;
    assign w_imem_raddr = i_start ? i_start_pc :
                         o_pc_load ? o_pc_target :
                         ((w_issue && i_pc_en && !w_done_instruction) ? (o_pc + 1'b1) : o_pc);

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n)
            r_instruction_valid <= 1'b0;
        else
            r_instruction_valid <= w_fetch;
    end

    // A DONE instruction issued at edge N can store its result at edge N+3:
    // IF read -> ML/EXE operands -> EXE/NL result -> memory-store acceptance.
    // Assert sticky completion on that final accepting edge, after the drain.
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_done_pipe <= '0;
            o_done <= 1'b0;
        end else if (i_start) begin
            r_done_pipe <= '0;
            o_done <= 1'b0;
        end else begin
            r_done_pipe <= {r_done_pipe[1:0], w_done_instruction};
            if (r_done_pipe[2])
                o_done <= 1'b1;
        end
    end

    // Match DONE's store-acceptance timing, but report one event per marked
    // instruction instead of latching completion. Start discards old events.
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_row_done_pipe <= '0;
            o_row_done <= 1'b0;
        end else if (i_start) begin
            r_row_done_pipe <= '0;
            o_row_done <= 1'b0;
        end else begin
            r_row_done_pipe <= {r_row_done_pipe[1:0], w_row_done_instruction};
            o_row_done <= r_row_done_pipe[2];
        end
    end

    imem #(
        .INSTR_W(64), .ADDR_W(PC_W), .DEPTH(2 ** PC_W),
        .MEM_INIT_FILE(IMEM_INIT_FILE)
    ) u_imem (
        .i_clk(i_clk),
        .i_en(i_imem_we || w_fetch),
        .i_we(i_imem_we),
        .i_raddr(w_imem_raddr),
        .i_waddr(i_imem_waddr),
        .i_wdata(i_imem_wdata),
        .o_rdata(w_instruction)
    );

    // Decode hold/switch commands separately from resolved physical buffer IDs.
    // IF also decodes output-path selections. The low seven bits continue
    // through IF -> ML -> EXE in the zero-extended control payload.
    dec_if u_dec_if (
        .i_instruction(w_decode_instruction),
        .o_ob_switch(w_ob_switch),
        .o_osp_mux_sel(w_osp_mux_sel),
        .o_set_iteration(w_set_iteration),
        .o_set_breakpoint(w_set_breakpoint),
        .o_conditional_loop(w_conditional_loop),
        .o_done(w_done_instruction),
        .o_row_done(w_row_done_instruction),
        .o_ib_switch(w_ib_switch),
        .o_ib_clear(w_ib_clear),
        .o_ib_sign(w_ib_sign),
        .o_ib_offset(w_ib_offset),
        .o_ksp_switch(w_ksp_switch),
        .o_ksp_sign(w_ksp_sign),
        .o_ksp_offset(w_ksp_offset),
        .o_osp_clear(w_osp_clear),
        .o_osp_sign(w_osp_sign),
        .o_osp_offset(w_osp_offset),
        .o_bsp_clear(w_bsp_clear),
        .o_bsp_sign(w_bsp_sign),
        .o_bsp_offset(w_bsp_offset),
        .o_load_ib(w_load_ib),
        .o_load_ksp(w_load_ksp),
        .o_load_osp(w_load_osp),
        .o_load_bsp(w_load_bsp)
    );

    // Switch before this instruction's access and retain its selected buffer.
    // Commands are zero without IF issue; state changes only once per issue,
    // even when Load/Store is zero or a memory conflict suppresses its access.
    // Reset selects buffer 0. SCR/restart retains these selections.
    assign w_ib_rbuf_sel = r_ib_active_buf ^ w_ib_switch;
    assign w_ksp_rbuf_sel = r_ksp_active_buf ^ w_ksp_switch;
    assign w_ob_wbuf_sel = r_ob_active_buf ^ w_ob_switch;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_ib_active_buf <= 1'b0;
            r_ksp_active_buf <= 1'b0;
            r_ob_active_buf <= 1'b0;
        end else if (w_issue) begin
            r_ib_active_buf <= w_ib_rbuf_sel;
            r_ksp_active_buf <= w_ksp_rbuf_sel;
            r_ob_active_buf <= w_ob_wbuf_sel;
        end
    end

    // Each start pulse loads its entry PC. Otherwise, a decoded AGU branch
    // takes priority over the normal enabled PC increment.
    slave_pc #(.PC_W(PC_W)) u_pc (
        .i_start(i_start),
        .i_halt(w_done_instruction),
        .i_start_pc(i_start_pc),
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_en(w_issue && i_pc_en),
        .i_load(o_pc_load),
        .i_load_pc(o_pc_target),
        .o_pc(o_pc),
        .o_running(w_pc_running)
    );

    // AGU owns all execution address state. IF issue advances the four
    // offset-based pointers; valid NL Store OB requests advance OB separately.
    agu #(.PC_W(PC_W)) u_agu (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_addr_en(w_issue),
        .i_store_ob(w_store_ob),
        .i_set_iteration(w_set_iteration),
        .i_set_breakpoint(w_set_breakpoint),
        .i_conditional_loop(w_conditional_loop),
        .i_pc(o_pc),
        .i_ib_clear(w_ib_clear),
        .i_ib_sign(w_ib_sign),
        .i_ib_offset(w_ib_offset),
        .i_ksp_sign(w_ksp_sign),
        .i_ksp_offset(w_ksp_offset),
        .i_osp_clear(w_osp_clear),
        .i_osp_sign(w_osp_sign),
        .i_osp_offset(w_osp_offset),
        .i_bsp_clear(w_bsp_clear),
        .i_bsp_sign(w_bsp_sign),
        .i_bsp_offset(w_bsp_offset),
        .o_ib_addr(o_ib_addr),
        .o_ksp_addr(o_ksp_addr),
        .o_osp_addr(o_osp_addr),
        .o_bsp_addr(o_bsp_addr),
        .o_ob_addr(o_ob_addr),
        .o_pc_load(o_pc_load),
        .o_pc_target(o_pc_target)
    );

    // The registered NL store fields control OSP writes using their matching
    // pipelined OSP address. Store OB writes the dummy LUT result and advances
    // AGU's sequential OB address on that same edge.
    dec_ms u_dec_ms (
        .i_valid(o_nl_valid),
        .i_instruction(o_nl_instruction),
        .o_store_osp(w_store_osp),
        .o_store_ob(w_store_ob)
    );
    assign w_osp_we = i_osp_we & {LANES{w_store_osp}};

    // IB/KSP can read and write different buffers on the same edge. If a
    // write targets the selected read buffer, that bank's write has priority.
    // Capture the buffer selector only when a read actually takes place.
    // This keeps synchronous read data aligned across buffer changes and
    // preserves each disabled lane's last read result.
    assign w_ib_read_en = i_ib_en && w_load_ib &&
                         !(i_ib_we && (i_ib_wbuf_sel == w_ib_rbuf_sel));
    assign w_ksp_read_en = i_ksp_en & {LANES{w_load_ksp}} &
                          ~(i_ksp_we & {LANES{i_ksp_wbuf_sel == w_ksp_rbuf_sel}});
    assign o_ib_rdata = r_ib_read_buf_sel ? w_ib_buffer_rdata[1] :
                                          w_ib_buffer_rdata[0];

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_ib_read_buf_sel <= 1'b0;
            r_ksp_read_buf_sel <= '0;
        end else begin
            if (w_ib_read_en)
                r_ib_read_buf_sel <= w_ib_rbuf_sel;
            for (int w_lane = 0; w_lane < LANES; w_lane++) begin
                if (w_ksp_read_en[w_lane])
                    r_ksp_read_buf_sel[w_lane] <= w_ksp_rbuf_sel;
            end
        end
    end

    // IB/KSP/BSP programming writes retain external control. OSP writes
    // require the decoded store and mask. Memories remain single-port 1RW.
    generate
        for (genvar w_lane = 0; w_lane < LANES; w_lane++) begin : g_lane
            for (genvar w_buffer = 0; w_buffer < 2; w_buffer++) begin : g_ksp_buffer
                logic w_read_en;
                logic w_write_en;

                assign w_read_en = w_ksp_read_en[w_lane] &&
                                   (w_ksp_rbuf_sel == 1'(w_buffer));
                assign w_write_en = i_ksp_en[w_lane] && i_ksp_we[w_lane] &&
                                    (i_ksp_wbuf_sel == 1'(w_buffer));

                mem #(.DATA_W(DATA_W), .ADDR_W(KSP_ADDR_W), .DEPTH(256)) u_ksp (
                    .i_clk(i_clk),
                    .i_en(w_read_en || w_write_en),
                    .i_we(w_write_en),
                    .i_addr(w_write_en ? i_ksp_waddr : o_ksp_addr),
                    .i_wdata(i_ksp_wdata[w_lane]),
                    .o_rdata(w_ksp_buffer_rdata[w_buffer][w_lane])
                );
            end

            assign o_ksp_rdata[w_lane] = r_ksp_read_buf_sel[w_lane] ?
                                       w_ksp_buffer_rdata[1][w_lane] :
                                       w_ksp_buffer_rdata[0][w_lane];

            mem #(.DATA_W(DATA_W), .ADDR_W(OSP_ADDR_W), .DEPTH(512)) u_osp (
                .i_clk(i_clk),
                .i_en(i_osp_en[w_lane] && (w_osp_we[w_lane] || w_load_osp)),
                .i_we(w_osp_we[w_lane]),
                .i_addr(w_osp_we[w_lane] ? w_nl_osp_addr : o_osp_addr),
                .i_wdata(o_eoa_out[w_lane]),
                .o_rdata(o_osp_rdata[w_lane])
            );
        end
    endgenerate

    // OB uses two independent 1RW memories. Capture the buffer ID only for
    // completed reads so the output holds across disabled/conflicting reads.
    assign w_ob_read_en = i_rst_n && i_ob_ren &&
                          !(w_store_ob && (i_ob_rbuf_sel == w_nl_ob_wbuf_sel));
    assign o_ob_rdata = r_ob_read_buf_sel ? w_ob_buffer_rdata[1] :
                                          w_ob_buffer_rdata[0];

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n)
            r_ob_read_buf_sel <= 1'b0;
        else if (w_ob_read_en)
            r_ob_read_buf_sel <= i_ob_rbuf_sel;
    end

    generate
        for (genvar w_buffer = 0; w_buffer < 2; w_buffer++) begin : g_ob_buffer
            logic w_read_en;
            logic w_write_en;

            assign w_read_en = w_ob_read_en && (i_ob_rbuf_sel == 1'(w_buffer));
            assign w_write_en = i_rst_n && w_store_ob &&
                                (w_nl_ob_wbuf_sel == 1'(w_buffer));

            mem #(.DATA_W(DATA_W), .ADDR_W(OB_ADDR_W), .DEPTH(1024)) u_ob (
                .i_clk(i_clk),
                .i_en(w_read_en || w_write_en),
                .i_we(w_write_en),
                .i_addr(w_write_en ? o_ob_addr : i_ob_raddr),
                .i_wdata(w_lut_out),
                .o_rdata(w_ob_buffer_rdata[w_buffer])
            );
        end
    endgenerate

    generate
        for (genvar w_buffer = 0; w_buffer < 2; w_buffer++) begin : g_ib_buffer
            logic w_read_en;
            logic w_write_en;

            assign w_read_en = w_ib_read_en && (w_ib_rbuf_sel == 1'(w_buffer));
            assign w_write_en = i_ib_en && i_ib_we && (i_ib_wbuf_sel == 1'(w_buffer));

            mem #(.DATA_W(DATA_W), .ADDR_W(IB_ADDR_W), .DEPTH(1024)) u_ib (
                .i_clk(i_clk),
                .i_en(w_read_en || w_write_en),
                .i_we(w_write_en),
                .i_addr(w_write_en ? i_ib_waddr : o_ib_addr),
                .i_wdata(i_ib_wdata),
                .o_rdata(w_ib_buffer_rdata[w_buffer])
            );
        end
    endgenerate

    mem #(.DATA_W(DATA_W), .ADDR_W(BSP_ADDR_W), .DEPTH(64)) u_bsp (
        .i_clk(i_clk),
        .i_en(i_bsp_en && (i_bsp_we || w_load_bsp)),
        .i_we(i_bsp_we),
        .i_addr(i_bsp_we ? i_bsp_waddr : o_bsp_addr),
        .i_wdata(i_bsp_wdata),
        .o_rdata(o_bsp_rdata)
    );

    // On the IF issue edge, memory reads start and the remaining instruction
    // bits and the instruction's OSP address advance into ML. A bubble advances
    // when IF does not issue.
    reg_if_ml #(.INSTR_W(9), .OSP_ADDR_W(OSP_ADDR_W)) u_reg_if_ml (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_valid(w_issue),
        .i_instruction({2'b00, w_instruction[6:0]}),
        .i_osp_addr(o_osp_addr),
        .i_osp_mux_sel(w_osp_mux_sel),
        .i_ob_wbuf_sel(w_ob_wbuf_sel),
        .o_valid(w_ml_instruction_valid),
        .o_instruction(w_ml_instruction),
        .o_osp_addr(w_ml_osp_addr),
        .o_osp_mux_sel(w_ml_osp_mux_sel),
        .o_ob_wbuf_sel(w_ml_ob_wbuf_sel)
    );

    // The IF-to-ML select belongs to the same instruction as the synchronous
    // OSP outputs. Select one of the 64 words before the MLOM register.
    assign w_osp_mux_data = o_osp_rdata[w_ml_osp_mux_sel];
    // Signed fixed-point operands share their binary point. Addition wraps
    // to DATA_W bits, matching the DALU; no rescaling or saturation is added.
    assign w_bias_sum = w_mlb_out + w_mlom_out;

    // ML -> EXE operands and matching instruction. Temporarily capture all
    // DALU operand lanes every edge. MLOM/MLB capture on valid ML instructions.
    reg_ml_exe #(
        .DATA_W(DATA_W), .LANES(LANES), .INSTR_W(9), .OSP_ADDR_W(OSP_ADDR_W)
    ) u_reg_ml_exe (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_instruction_valid(w_ml_instruction_valid),
        .i_instruction(w_ml_instruction),
        .i_osp_addr(w_ml_osp_addr),
        .i_ob_wbuf_sel(w_ml_ob_wbuf_sel),
        .o_instruction_valid(o_exe_valid),
        .o_instruction(o_exe_instruction),
        .o_osp_addr(w_exe_osp_addr),
        .o_ob_wbuf_sel(w_exe_ob_wbuf_sel),
        .i_mli_en({LANES{1'b1}}),
        .i_mlk_en({LANES{1'b1}}),
        .i_mlo_en({LANES{1'b1}}),
        .i_ib_rdata(o_ib_rdata),
        .i_ksp_rdata(o_ksp_rdata),
        .i_osp_rdata(o_osp_rdata),
        .i_mlom_data(w_osp_mux_data),
        .i_bsp_rdata(o_bsp_rdata),
        .o_mli_out(o_mli_out),
        .o_mlk_out(o_mlk_out),
        .o_mlo_out(o_mlo_out),
        .o_mlom_out(w_mlom_out),
        .o_mlb_out(w_mlb_out)
    );

    // EXE decoder broadcasts the MAC controls to all lanes.
    dec_ex u_dec_ex (
        .i_valid(o_exe_valid),
        .i_instruction(o_exe_instruction),
        .o_mult_sel_1(w_mult_sel_1),
        .o_mult_sel_2(w_mult_sel_2),
        .o_acc_sel(w_acc_sel),
        .o_max_or_mac(),
        .o_mac_en(w_mac_en)
    );

    generate
        for (genvar w_lane = 0; w_lane < LANES; w_lane++) begin : g_dalu
            if (w_lane == 0) begin : g_first_lane
                assign w_seoa[w_lane] = '0;
            end else begin : g_neighbor
                assign w_seoa[w_lane] = o_eoa_out[w_lane-1];
            end

            dalu #(.DATA_W(DATA_W), .DECIMAL_BIT(8)) u_dalu (
                .i_mult_sel_1(w_mult_sel_1),
                .i_mult_sel_2(w_mult_sel_2),
                .i_acc_sel(w_acc_sel),
                .i_mli_out(o_mli_out[w_lane]),
                .i_mlk_out(o_mlk_out[w_lane]),
                .i_mlo_out(o_mlo_out[w_lane]),
                .i_eoa_out(o_eoa_out[w_lane]),
                .i_seoa(w_seoa[w_lane]),
                .o_acc_result(w_dalu_result[w_lane])
            );
        end
    endgenerate

    // EXE -> NL results, remaining store fields and their OSP address.
    // These registers break the DALU feedback path and keep control timing
    // at the same boundary.
    reg_exe_nl #(
        .DATA_W(DATA_W), .LANES(LANES), .INSTR_W(2), .OSP_ADDR_W(OSP_ADDR_W)
    ) u_reg_exe_nl (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_instruction_valid(o_exe_valid),
        .i_instruction(o_exe_instruction[1:0]),
        .i_osp_addr(w_exe_osp_addr),
        .i_ob_wbuf_sel(w_exe_ob_wbuf_sel),
        .o_instruction_valid(o_nl_valid),
        .o_instruction(o_nl_instruction),
        .o_osp_addr(w_nl_osp_addr),
        .o_ob_wbuf_sel(w_nl_ob_wbuf_sel),
        // Temporary all-ones lane mask; preserve valid MAC commit gating.
        .i_eoa_en({LANES{w_mac_en}}),
        .i_dalu_result(w_dalu_result),
        .i_lut_data(w_bias_sum),
        .o_eoa_out(o_eoa_out),
        .o_lut_out(w_lut_out)
    );

    
endmodule
