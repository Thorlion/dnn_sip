// Execution to nonlinear-stage pipeline registers: one EOA result per lane.
// Each EOA also provides the stored partial sum for the next DALU operation.
// Reset is asynchronous and active low; disabled lanes retain their results.
module reg_exe_nl #(
    parameter int unsigned DATA_W = 16,
    parameter int unsigned LANES = 64
)(
    input  logic                         i_clk,
    input  logic                         i_rst_n,
    input  logic [LANES-1:0]             i_eoa_en,
    input  logic signed [DATA_W-1:0]     i_dalu_result [0:LANES-1],
    output logic signed [DATA_W-1:0]     o_eoa_out [0:LANES-1]
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
