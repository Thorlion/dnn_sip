// Structural connection of the PC, AGU, datapath and memories.
// All memories contain 16-bit words:
//   KSP: 64 banks x 512 words (1 KiB per bank).
//   OSP: 64 banks x 512 words (1 KiB per bank).
//   IB:  one bank x 1024 words (2 KiB).
//   BSP: one bank x 64 words (128 bytes).
//
// The caller supplies current data-memory addresses and bank/buffer masks.
// IMEM -> dec_if supplies flow control, address offsets and memory-load fields.
// AGU outputs drive read addresses; OSP stores use the pipelined IF address.
// Address feedback is still external.
// Each memory address uses its own sign bit and offset magnitude:
// IB 10 bits, KSP/OSP 9 bits, BSP 6 bits.
// Each bank performs one synchronous read or write per enabled rising edge.
module dsip_slave #(
    parameter int unsigned PC_W = 9
)(
    input  logic                 i_clk,
    input  logic                 i_rst_n,

    input  logic                 i_start,
    input  logic                 i_pc_en,
    output logic [PC_W-1:0]      o_pc,

    // Synchronous IMEM programming interface. Writes pause instruction issue.
    input  logic                 i_imem_we,
    input  logic [PC_W-1:0]      i_imem_waddr,
    input  logic [57:0]          i_imem_wdata,

    // Remaining instruction fields forwarded to the EXE-stage input.
    output logic [8:0]           o_exe_instruction,
    output logic                 o_exe_valid,

    // Remaining store fields forwarded to the nonlinear-stage input.
    output logic [1:0]           o_nl_instruction,
    output logic                 o_nl_valid,

    // AGU branch outputs are also exposed for observation.
    output logic                 o_pc_load,
    output logic [PC_W-1:0]      o_pc_target,

    input  logic [9:0]           i_ib_addr,
    input  logic [8:0]           i_ksp_addr,
    input  logic [8:0]           i_osp_addr,
    input  logic [5:0]           i_bsp_addr,
    output logic [9:0]           o_ib_addr,
    output logic [8:0]           o_ksp_addr,
    output logic [8:0]           o_osp_addr,
    output logic [5:0]           o_bsp_addr,

    input  logic [63:0]          i_ksp_en,
    input  logic [63:0]          i_ksp_we,
    input  logic [15:0]          i_ksp_wdata [0:63],
    output logic [15:0]          o_ksp_rdata [0:63],

    input  logic [63:0]          i_osp_en,
    // Per-lane store mask, qualified by the decoded Store OSP instruction.
    input  logic [63:0]          i_osp_we,
    output logic [15:0]          o_osp_rdata [0:63],

    input  logic                 i_ib_en,
    input  logic                 i_ib_we,
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
    input  logic [15:0]          i_bsp_wdata,
    output logic [15:0]          o_bsp_rdata
);
    localparam int DATA_W = 16;
    localparam int LANES = 64;
    localparam int IB_ADDR_W = 10;
    localparam int KSP_ADDR_W = 9;
    localparam int OSP_ADDR_W = 9;
    localparam int BSP_ADDR_W = 6;

    logic [IB_ADDR_W-1:0] w_ksp_addr;
    logic [IB_ADDR_W-1:0] w_osp_addr;
    logic [IB_ADDR_W-1:0] w_bsp_addr;

    logic signed [DATA_W-1:0] w_dalu_result [0:LANES-1];
    logic signed [DATA_W-1:0] w_seoa [0:LANES-1];

    logic w_mult_sel_1;
    logic w_mult_sel_2;
    logic [1:0] w_acc_sel;
    logic w_mac_en;
    logic w_store_osp;
    logic [LANES-1:0] w_osp_we;
    logic [OSP_ADDR_W-1:0] w_ml_osp_addr;
    logic [OSP_ADDR_W-1:0] w_exe_osp_addr;
    logic [OSP_ADDR_W-1:0] w_nl_osp_addr;

    logic [57:0] w_instruction;
    logic [57:0] w_decode_instruction;
    logic [8:0] w_ml_instruction;
    logic w_ml_instruction_valid;
    logic [PC_W-1:0] w_imem_raddr;
    logic w_pc_running;
    logic w_fetch;
    logic w_issue;
    logic r_instruction_valid;

    logic [4:0] w_set_iteration;
    logic w_set_breakpoint;
    logic w_conditional_loop;
    logic w_ib_sign;
    logic [9:0] w_ib_offset;
    logic w_ksp_sign;
    logic [8:0] w_ksp_offset;
    logic w_osp_sign;
    logic [8:0] w_osp_offset;
    logic w_bsp_sign;
    logic [5:0] w_bsp_offset;
    logic w_load_ib;
    logic w_load_ksp;
    logic w_load_osp;
    logic w_load_bsp;

    // Initial fetch holds the PC. Once valid, the current instruction issues
    // while IMEM reads the next PC value on the same edge. PC and IMEM output
    // therefore stay aligned, including when the AGU requests a branch.
    // i_pc_en controls normal advancement; a decoded AGU branch retains priority.
    assign w_fetch = i_rst_n && (w_pc_running || i_start) &&
                     !i_imem_we;
    assign w_issue = i_rst_n && w_pc_running &&
                     r_instruction_valid && !i_imem_we;
    assign w_decode_instruction = w_issue ? w_instruction : 58'd0;
    assign w_imem_raddr = o_pc_load ? o_pc_target :
                         ((w_issue && i_pc_en) ? (o_pc + 1'b1) : o_pc);

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n)
            r_instruction_valid <= 1'b0;
        else
            r_instruction_valid <= w_fetch;
    end

    imem #(.INSTR_W(58), .ADDR_W(PC_W), .DEPTH(2 ** PC_W)) u_imem (
        .i_clk(i_clk),
        .i_en(i_imem_we || w_fetch),
        .i_we(i_imem_we),
        .i_addr(i_imem_we ? i_imem_waddr : w_imem_raddr),
        .i_wdata(i_imem_wdata),
        .o_rdata(w_instruction)
    );

    // Only the IF fields are decoded here. Arithmetic [8:2] and store [1:0]
    // are forwarded through IF -> ML -> EXE for later-stage decoding.
    dec_if u_dec_if (
        .i_instruction(w_decode_instruction),
        .o_set_iteration(w_set_iteration),
        .o_set_breakpoint(w_set_breakpoint),
        .o_conditional_loop(w_conditional_loop),
        .o_ib_sign(w_ib_sign),
        .o_ib_offset(w_ib_offset),
        .o_ksp_sign(w_ksp_sign),
        .o_ksp_offset(w_ksp_offset),
        .o_osp_sign(w_osp_sign),
        .o_osp_offset(w_osp_offset),
        .o_bsp_sign(w_bsp_sign),
        .o_bsp_offset(w_bsp_offset),
        .o_load_ib(w_load_ib),
        .o_load_ksp(w_load_ksp),
        .o_load_osp(w_load_osp),
        .o_load_bsp(w_load_bsp)
    );

    // The one-cycle start pulse releases the PC. During execution, the AGU
    // branch request takes priority over the normal enabled PC increment.
    pc #(.PC_W(PC_W)) u_pc (
        .i_start(i_start),
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_en(w_issue && i_pc_en),
        .i_load(o_pc_load),
        .i_load_pc(o_pc_target),
        .o_pc(o_pc),
        .o_running(w_pc_running)
    );

    // IF stage
    // ADDRESS_WIDTH is the AGU's highest address bit, not a bit count.
    agu #(.ADDRESS_WIDTH(IB_ADDR_W-1), .PC_W(PC_W)) u_agu (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_set_iteration(w_set_iteration),
        .i_set_breakpoint(w_set_breakpoint),
        .i_conditional_loop(w_conditional_loop),
        .i_pc(o_pc),
        .i_ib_addr(i_ib_addr),
        .i_ksp_addr({{(IB_ADDR_W-KSP_ADDR_W){1'b0}}, i_ksp_addr}),
        .i_osp_addr({{(IB_ADDR_W-OSP_ADDR_W){1'b0}}, i_osp_addr}),
        .i_bsp_addr({{(IB_ADDR_W-BSP_ADDR_W){1'b0}}, i_bsp_addr}),
        .i_ib_sign(w_ib_sign),
        .i_ib_offset(w_ib_offset),
        .i_ksp_sign(w_ksp_sign),
        .i_ksp_offset(w_ksp_offset),
        .i_osp_sign(w_osp_sign),
        .i_osp_offset(w_osp_offset),
        .i_bsp_sign(w_bsp_sign),
        .i_bsp_offset(w_bsp_offset),
        .o_ib_addr(o_ib_addr),
        .o_ksp_addr(w_ksp_addr),
        .o_osp_addr(w_osp_addr),
        .o_bsp_addr(w_bsp_addr),
        .o_pc_load(o_pc_load),
        .o_pc_target(o_pc_target)
    );

    // Each memory uses the low address bits appropriate to its depth.
    assign o_ksp_addr = w_ksp_addr[KSP_ADDR_W-1:0];
    assign o_osp_addr = w_osp_addr[OSP_ADDR_W-1:0];
    assign o_bsp_addr = w_bsp_addr[BSP_ADDR_W-1:0];

    // The registered NL store fields control OSP writes using their matching
    // pipelined OSP address. OB is not instantiated.
    dec_ms u_dec_ms (
        .i_valid(o_nl_valid),
        .i_instruction(o_nl_instruction),
        .o_store_osp(w_store_osp),
        .o_store_ob()
    );
    assign w_osp_we = i_osp_we & {LANES{w_store_osp}};

    // Existing enables select banks/buffers. IB/KSP/BSP programming writes
    // retain external control; OSP writes require the decoded store and mask.
    // Reads additionally require the corresponding decoded load bit.
    // A write wins over an instruction read on the same 1RW memory bank.
    generate
        for (genvar w_lane = 0; w_lane < LANES; w_lane++) begin : g_lane
            mem #(.DATA_W(DATA_W), .ADDR_W(KSP_ADDR_W), .DEPTH(512)) u_ksp (
                .i_clk(i_clk),
                .i_en(i_ksp_en[w_lane] && (i_ksp_we[w_lane] || w_load_ksp)),
                .i_we(i_ksp_we[w_lane]),
                .i_addr(o_ksp_addr),
                .i_wdata(i_ksp_wdata[w_lane]),
                .o_rdata(o_ksp_rdata[w_lane])
            );

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

    mem #(.DATA_W(DATA_W), .ADDR_W(IB_ADDR_W), .DEPTH(1024)) u_ib (
        .i_clk(i_clk),
        .i_en(i_ib_en && (i_ib_we || w_load_ib)),
        .i_we(i_ib_we),
        .i_addr(o_ib_addr),
        .i_wdata(i_ib_wdata),
        .o_rdata(o_ib_rdata)
    );

    mem #(.DATA_W(DATA_W), .ADDR_W(BSP_ADDR_W), .DEPTH(64)) u_bsp (
        .i_clk(i_clk),
        .i_en(i_bsp_en && (i_bsp_we || w_load_bsp)),
        .i_we(i_bsp_we),
        .i_addr(o_bsp_addr),
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
        .i_instruction(w_instruction[8:0]),
        .i_osp_addr(o_osp_addr),
        .o_valid(w_ml_instruction_valid),
        .o_instruction(w_ml_instruction),
        .o_osp_addr(w_ml_osp_addr)
    );

    // ML -> EXE operands and matching instruction. Temporarily capture all
    // operand lanes every edge; synchronous memory outputs retain read timing.
    reg_ml_exe #(
        .DATA_W(DATA_W), .LANES(LANES), .INSTR_W(9), .OSP_ADDR_W(OSP_ADDR_W)
    ) u_reg_ml_exe (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_instruction_valid(w_ml_instruction_valid),
        .i_instruction(w_ml_instruction),
        .i_osp_addr(w_ml_osp_addr),
        .o_instruction_valid(o_exe_valid),
        .o_instruction(o_exe_instruction),
        .o_osp_addr(w_exe_osp_addr),
        .i_mli_en({LANES{1'b1}}),
        .i_mlk_en({LANES{1'b1}}),
        .i_mlo_en({LANES{1'b1}}),
        .i_ib_rdata(o_ib_rdata),
        .i_ksp_rdata(o_ksp_rdata),
        .i_osp_rdata(o_osp_rdata),
        .o_mli_out(o_mli_out),
        .o_mlk_out(o_mlk_out),
        .o_mlo_out(o_mlo_out)
    );

    // EXE decoder broadcasts the MAC controls to all lanes. MAX outputs are
    // intentionally left unconnected until the MAX datapath is implemented.
    dec_ex u_dec_ex (
        .i_valid(o_exe_valid),
        .i_instruction(o_exe_instruction),
        .o_mult_sel_1(w_mult_sel_1),
        .o_mult_sel_2(w_mult_sel_2),
        .o_acc_sel(w_acc_sel),
        .o_max_sel_1(),
        .o_max_sel_2(),
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
        .o_instruction_valid(o_nl_valid),
        .o_instruction(o_nl_instruction),
        .o_osp_addr(w_nl_osp_addr),
        // Temporary all-ones lane mask; preserve valid MAC commit gating.
        .i_eoa_en({LANES{w_mac_en}}),
        .i_dalu_result(w_dalu_result),
        .o_eoa_out(o_eoa_out)
    );

    
endmodule
