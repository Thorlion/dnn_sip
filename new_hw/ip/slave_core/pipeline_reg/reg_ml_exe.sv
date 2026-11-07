// Memory-load to execution pipeline registers: MLI, MLK, MLO, MLOM and MLB.
// The single IB output is broadcast to all MLI registers. KSP lane p feeds MLK p.
// OSP lane p feeds MLO p.
// The selected OSP word feeds the single MLOM; BSP feeds the single MLB.
// MLOM/MLB capture on valid ML instructions and hold across bubbles.
// Each lane has a separate load enable so its previous operand can be held.
// Reset is asynchronous and active low; all operands reset to zero.
// The remaining instruction bits, OSP address, OB buffer and valid flag advance
// on each edge.
// Invalid control inputs insert a zero-valued bubble. Operand enables remain
// independent so each lane can retain previously loaded operands.
//
// With synchronous memories, a read issued at edge N becomes available after
// that edge. Assert the corresponding load enable at edge N+1 to capture it.
module reg_ml_exe #(
    parameter int unsigned DATA_W = 16,
    parameter int unsigned LANES = 64,
    parameter int unsigned INSTR_W = 9,
    parameter int unsigned OSP_ADDR_W = 9
)(
    input  logic                         i_clk,
    input  logic                         i_rst_n,
    input  logic                         i_instruction_valid,
    input  logic [INSTR_W-1:0]           i_instruction,
    input  logic [OSP_ADDR_W-1:0]        i_osp_addr,
    input  logic                         i_ob_wbuf_sel,
    output logic                         o_instruction_valid,
    output logic [INSTR_W-1:0]           o_instruction,
    output logic [OSP_ADDR_W-1:0]        o_osp_addr,
    output logic                         o_ob_wbuf_sel,
    input  logic [LANES-1:0]             i_mli_en,
    input  logic [LANES-1:0]             i_mlk_en,
    input  logic [LANES-1:0]             i_mlo_en,
    input  logic [DATA_W-1:0]            i_ib_rdata,
    input  logic [DATA_W-1:0]            i_ksp_rdata [0:LANES-1],
    input  logic [DATA_W-1:0]            i_osp_rdata [0:LANES-1],
    input  logic [DATA_W-1:0]            i_mlom_data,
    input  logic [DATA_W-1:0]            i_bsp_rdata,
    output logic signed [DATA_W-1:0]     o_mli_out [0:LANES-1],
    output logic signed [DATA_W-1:0]     o_mlk_out [0:LANES-1],
    output logic signed [DATA_W-1:0]     o_mlo_out [0:LANES-1],
    output logic signed [DATA_W-1:0]     o_mlom_out,
    output logic signed [DATA_W-1:0]     o_mlb_out
);
    logic [INSTR_W-1:0] w_instruction;
    logic [OSP_ADDR_W-1:0] w_osp_addr;
    logic w_ob_wbuf_sel;

    assign w_instruction = i_instruction_valid ? i_instruction : '0;
    assign w_osp_addr = i_instruction_valid ? i_osp_addr : '0;
    assign w_ob_wbuf_sel = i_instruction_valid && i_ob_wbuf_sel;

    register #(.DATA_W(1), .DEFAULT_VALUE(1'b0)) u_ob_wbuf_sel (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_en(1'b1),
        .i_data(w_ob_wbuf_sel),
        .o_data(o_ob_wbuf_sel)
    );

    register #(.DATA_W(INSTR_W), .DEFAULT_VALUE('0)) u_instruction (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_en(1'b1),
        .i_data(w_instruction),
        .o_data(o_instruction)
    );

    register #(.DATA_W(OSP_ADDR_W), .DEFAULT_VALUE('0)) u_osp_addr (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_en(1'b1),
        .i_data(w_osp_addr),
        .o_data(o_osp_addr)
    );

    register #(.DATA_W(1), .DEFAULT_VALUE(1'b0)) u_instruction_valid (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_en(1'b1),
        .i_data(i_instruction_valid),
        .o_data(o_instruction_valid)
    );

    register #(.DATA_W(DATA_W), .DEFAULT_VALUE('0)) u_mlom (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_en(i_instruction_valid),
        .i_data(i_mlom_data),
        .o_data(o_mlom_out)
    );

    register #(.DATA_W(DATA_W), .DEFAULT_VALUE('0)) u_mlb (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_en(i_instruction_valid),
        .i_data(i_bsp_rdata),
        .o_data(o_mlb_out)
    );

    generate
        for (genvar w_lane = 0; w_lane < LANES; w_lane++) begin : g_lane
            register #(.DATA_W(DATA_W), .DEFAULT_VALUE('0)) u_mli (
                .i_clk(i_clk),
                .i_rst_n(i_rst_n),
                .i_en(i_mli_en[w_lane]),
                .i_data(i_ib_rdata),
                .o_data(o_mli_out[w_lane])
            );

            register #(.DATA_W(DATA_W), .DEFAULT_VALUE('0)) u_mlk (
                .i_clk(i_clk),
                .i_rst_n(i_rst_n),
                .i_en(i_mlk_en[w_lane]),
                .i_data(i_ksp_rdata[w_lane]),
                .o_data(o_mlk_out[w_lane])
            );

            register #(.DATA_W(DATA_W), .DEFAULT_VALUE('0)) u_mlo (
                .i_clk(i_clk),
                .i_rst_n(i_rst_n),
                .i_en(i_mlo_en[w_lane]),
                .i_data(i_osp_rdata[w_lane]),
                .o_data(o_mlo_out[w_lane])
            );
        end
    endgenerate
endmodule
