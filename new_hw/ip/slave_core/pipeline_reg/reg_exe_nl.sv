// Execution to nonlinear-stage pipeline registers: one EOA result per lane.
// Each EOA also provides the stored partial sum for the next DALU operation.
// Reset is asynchronous and active low; disabled lanes retain their results.
// Remaining instruction bits are store OSP [1] and store OB [0]. The payload,
// OSP address and valid flag advance every clock, independently of the
// EOA lane enables.
// Invalid control inputs insert a zero-valued bubble.
module reg_exe_nl #(
    parameter int unsigned DATA_W = 16,
    parameter int unsigned LANES = 64,
    parameter int unsigned INSTR_W = 2,
    parameter int unsigned OSP_ADDR_W = 9
)(
    input  logic                         i_clk,
    input  logic                         i_rst_n,
    input  logic                         i_instruction_valid,
    input  logic [INSTR_W-1:0]           i_instruction,
    input  logic [OSP_ADDR_W-1:0]        i_osp_addr,
    output logic                         o_instruction_valid,
    output logic [INSTR_W-1:0]           o_instruction,
    output logic [OSP_ADDR_W-1:0]        o_osp_addr,
    input  logic [LANES-1:0]             i_eoa_en,
    input  logic signed [DATA_W-1:0]     i_dalu_result [0:LANES-1],
    output logic signed [DATA_W-1:0]     o_eoa_out [0:LANES-1]
);
    logic [INSTR_W-1:0] w_instruction;
    logic [OSP_ADDR_W-1:0] w_osp_addr;

    assign w_instruction = i_instruction_valid ? i_instruction : '0;
    assign w_osp_addr = i_instruction_valid ? i_osp_addr : '0;

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

    generate
        for (genvar w_lane = 0; w_lane < LANES; w_lane++) begin : g_lane
            register #(.DATA_W(DATA_W), .DEFAULT_VALUE('0)) u_eoa (
                .i_clk(i_clk),
                .i_rst_n(i_rst_n),
                .i_en(i_eoa_en[w_lane]),
                .i_data(i_dalu_result[w_lane]),
                .o_data(o_eoa_out[w_lane])
            );
        end
    endgenerate
endmodule
