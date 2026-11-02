// Configuration registers: 0 stride, 1 input size, 2 input channels,
// 3 weight size, 4 weight channels, 5 linear activation.
// Reset is asynchronous and active low.
// i_offset is a register index shared by writes and combinational readback.
module reg_map #(
    parameter int unsigned REG_W = 16
)(
    input  logic                     i_clk,
    input  logic                     i_rst_n,
    input  logic                     i_we,
    input  logic [2:0]               i_offset,
    input  logic [REG_W-1:0]         i_wdata,
    output logic [REG_W-1:0]         o_rdata,
    output logic [REG_W-1:0]         o_stride,
    output logic [REG_W-1:0]         o_input_size,
    output logic [REG_W-1:0]         o_input_channels,
    output logic [REG_W-1:0]         o_weight_size,
    output logic [REG_W-1:0]         o_weight_channels,
    output logic                     o_linear_activation
);
    register #(.DATA_W(REG_W), .DEFAULT_VALUE(1)) u_stride (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_en(i_we && (i_offset == 3'd0)),
        .i_data(i_wdata),
        .o_data(o_stride)
    );

    register #(.DATA_W(REG_W), .DEFAULT_VALUE(224)) u_input_size (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_en(i_we && (i_offset == 3'd1)),
        .i_data(i_wdata),
        .o_data(o_input_size)
    );

    register #(.DATA_W(REG_W), .DEFAULT_VALUE(3)) u_input_channels (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_en(i_we && (i_offset == 3'd2)),
        .i_data(i_wdata),
        .o_data(o_input_channels)
    );

    register #(.DATA_W(REG_W), .DEFAULT_VALUE(11)) u_weight_size (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_en(i_we && (i_offset == 3'd3)),
        .i_data(i_wdata),
        .o_data(o_weight_size)
    );

    register #(.DATA_W(REG_W), .DEFAULT_VALUE(96)) u_weight_channels (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_en(i_we && (i_offset == 3'd4)),
        .i_data(i_wdata),
        .o_data(o_weight_channels)
    );

    register #(.DATA_W(1), .DEFAULT_VALUE(1'b0)) u_linear_activation (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_en(i_we && (i_offset == 3'd5)),
        .i_data(i_wdata[0]),
        .o_data(o_linear_activation)
    );

    always_comb begin
        case (i_offset)
            3'd0: o_rdata = o_stride;
            3'd1: o_rdata = o_input_size;
            3'd2: o_rdata = o_input_channels;
            3'd3: o_rdata = o_weight_size;
            3'd4: o_rdata = o_weight_channels;
            3'd5: o_rdata = {{(REG_W-1){1'b0}}, o_linear_activation};
            default: o_rdata = '0;
        endcase
    end
endmodule
