// Structural connection of the configuration registers, AGU and memories.
// All memories contain 16-bit words:
//   KSP: 64 banks x 512 words (1 KiB per bank).
//   OSP: 64 banks x 512 words (1 KiB per bank).
//   IB:  one bank x 1024 words (2 KiB).
//   BSP: one bank x 64 words (128 bytes).
//
// The caller supplies current addresses and memory controls. AGU outputs drive
// the memory address ports; there is no internal address-feedback register.
// OSP/BSP addresses remain unknown until their AGU output logic is defined.
// Each bank performs one synchronous read or write per enabled rising edge.
module dsip_core #(
    parameter int unsigned REG_W = 16
)(
    input  logic                 i_clk,
    input  logic                 i_rst_n,

    input  logic                 i_cfg_we,
    input  logic [2:0]           i_cfg_offset,
    input  logic [REG_W-1:0]     i_cfg_wdata,
    output logic [REG_W-1:0]     o_cfg_rdata,

    input  logic [9:0]           i_ib_addr,
    input  logic [8:0]           i_ksp_addr,
    input  logic [8:0]           i_osp_addr,
    input  logic [5:0]           i_bsp_addr,
    input  logic                 i_ib_sign,
    input  logic [4:0]           i_ib_offset,
    output logic [9:0]           o_ib_addr,
    output logic [8:0]           o_ksp_addr,
    output logic [8:0]           o_osp_addr,
    output logic [5:0]           o_bsp_addr,

    input  logic [63:0]          i_ksp_en,
    input  logic [63:0]          i_ksp_we,
    input  logic [15:0]          i_ksp_wdata [0:63],
    output logic [15:0]          o_ksp_rdata [0:63],

    input  logic [63:0]          i_osp_en,
    input  logic [63:0]          i_osp_we,
    output logic [15:0]          o_osp_rdata [0:63],

    input  logic                 i_ib_en,
    input  logic                 i_ib_we,
    input  logic [15:0]          i_ib_wdata,
    output logic [15:0]          o_ib_rdata,

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

    logic [REG_W-1:0] w_stride;
    logic [REG_W-1:0] w_input_size;
    logic [REG_W-1:0] w_input_channels;
    logic [REG_W-1:0] w_weight_size;
    logic [REG_W-1:0] w_weight_channels;
    logic w_linear_activation;

    logic [IB_ADDR_W-1:0] w_ksp_addr;
    logic [IB_ADDR_W-1:0] w_osp_addr;
    logic [IB_ADDR_W-1:0] w_bsp_addr;

    logic signed [DATA_W-1:0] w_dalu_result [0:LANES-1];
    logic signed [DATA_W-1:0] w_seoa [0:LANES-1];

    // Start of instruction fetch (IF stage)

    reg_map #(.REG_W(REG_W)) u_reg_map (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_we(i_cfg_we),
        .i_offset(i_cfg_offset),
        .i_wdata(i_cfg_wdata),
        .o_rdata(o_cfg_rdata),
        .o_stride(w_stride),
        .o_input_size(w_input_size),
        .o_input_channels(w_input_channels),
        .o_weight_size(w_weight_size),
        .o_weight_channels(w_weight_channels),
        .o_linear_activation(w_linear_activation)
    );

    // IF stage
    // ADDRESS_WIDTH is the AGU's highest address bit, not a bit count.
    // Configuration inputs use REG_WIDTH independently of address width.
    agu #(.ADDRESS_WIDTH(IB_ADDR_W-1), .REG_WIDTH(REG_W)) u_agu (
        .i_ib_addr(i_ib_addr),
        .i_ksp_addr({{(IB_ADDR_W-KSP_ADDR_W){1'b0}}, i_ksp_addr}),
        .i_osp_addr({{(IB_ADDR_W-OSP_ADDR_W){1'b0}}, i_osp_addr}),
        .i_bsp_addr({{(IB_ADDR_W-BSP_ADDR_W){1'b0}}, i_bsp_addr}),
        .i_input_size(w_input_size),
        .i_stride(w_stride),
        .i_weight_size(w_weight_size),
        .i_ib_sign(i_ib_sign),
        .i_ib_offset(i_ib_offset),
        .o_ib_addr(o_ib_addr),
        .o_ksp_addr(w_ksp_addr),
        .o_osp_addr(w_osp_addr),
        .o_bsp_addr(w_bsp_addr)
    );

    // Each memory uses the low address bits appropriate to its depth.
    assign o_ksp_addr = w_ksp_addr[KSP_ADDR_W-1:0];
    assign o_osp_addr = w_osp_addr[OSP_ADDR_W-1:0];
    assign o_bsp_addr = w_bsp_addr[BSP_ADDR_W-1:0];

    generate
        for (genvar w_lane = 0; w_lane < LANES; w_lane++) begin : g_lane
            mem #(.DATA_W(DATA_W), .ADDR_W(KSP_ADDR_W), .DEPTH(512)) u_ksp (
                .i_clk(i_clk),
                .i_en(i_ksp_en[w_lane]),
                .i_we(i_ksp_we[w_lane]),
                .i_addr(o_ksp_addr),
                .i_wdata(i_ksp_wdata[w_lane]),
                .o_rdata(o_ksp_rdata[w_lane])
            );

            mem #(.DATA_W(DATA_W), .ADDR_W(OSP_ADDR_W), .DEPTH(512)) u_osp (
                .i_clk(i_clk),
                .i_en(i_osp_en[w_lane]),
                .i_we(i_osp_we[w_lane]),
                .i_addr(o_osp_addr),
                .i_wdata(o_eoa_out[w_lane]),
                .o_rdata(o_osp_rdata[w_lane])
            );
        end
    endgenerate

    mem #(.DATA_W(DATA_W), .ADDR_W(IB_ADDR_W), .DEPTH(1024)) u_ib (
        .i_clk(i_clk),
        .i_en(i_ib_en),
        .i_we(i_ib_we),
        .i_addr(o_ib_addr),
        .i_wdata(i_ib_wdata),
        .o_rdata(o_ib_rdata)
    );

    mem #(.DATA_W(DATA_W), .ADDR_W(BSP_ADDR_W), .DEPTH(64)) u_bsp (
        .i_clk(i_clk),
        .i_en(i_bsp_en),
        .i_we(i_bsp_we),
        .i_addr(o_bsp_addr),
        .i_wdata(i_bsp_wdata),
        .o_rdata(o_bsp_rdata)
    );

    // ML -> EXE operands. Load enables are supplied by the caller and must
    // account for the preceding synchronous memory-read edge.
    reg_ml_exe #(.DATA_W(DATA_W), .LANES(LANES)) u_reg_ml_exe (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_mli_en(i_mli_en),
        .i_mlk_en(i_mlk_en),
        .i_mlo_en(i_mlo_en),
        .i_ib_rdata(o_ib_rdata),
        .i_ksp_rdata(o_ksp_rdata),
        .i_osp_rdata(o_osp_rdata),
        .o_mli_out(o_mli_out),
        .o_mlk_out(o_mlk_out),
        .o_mlo_out(o_mlo_out)
    );

    // EXE datapath. Decoder select ports are intentionally left unconnected.
    generate
        for (genvar w_lane = 0; w_lane < LANES; w_lane++) begin : g_dalu
            if (w_lane == 0) begin : g_first_lane
                assign w_seoa[w_lane] = '0;
            end else begin : g_neighbor
                assign w_seoa[w_lane] = o_eoa_out[w_lane-1];
            end

            dalu #(.DATA_W(DATA_W), .DECIMAL_BIT(8)) u_dalu (
                .i_mult_sel_1(),
                .i_mult_sel_2(),
                .i_acc_sel(),
                .i_mli_out(o_mli_out[w_lane]),
                .i_mlk_out(o_mlk_out[w_lane]),
                .i_mlo_out(o_mlo_out[w_lane]),
                .i_eoa_out(o_eoa_out[w_lane]),
                .i_seoa(w_seoa[w_lane]),
                .o_acc_result(w_dalu_result[w_lane])
            );
        end
    endgenerate

    // EXE -> NL results. These registers break the DALU feedback path.
    reg_exe_nl #(.DATA_W(DATA_W), .LANES(LANES)) u_reg_exe_nl (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_eoa_en(i_eoa_en),
        .i_dalu_result(w_dalu_result),
        .o_eoa_out(o_eoa_out)
    );

    
endmodule
