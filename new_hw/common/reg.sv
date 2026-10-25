// Parameterized register. Priority: active-low asynchronous reset > enabled load > hold.
// DEFAULT_VALUE is the reset value; no power-up initialization is assumed.
// The module is named register because reg is a SystemVerilog keyword.
module register #(
    parameter int unsigned DATA_W = 16,
    parameter logic [DATA_W-1:0] DEFAULT_VALUE = '0
)(
    input  logic                  i_clk,
    input  logic                  i_rst_n,
    input  logic                  i_en,
    input  logic [DATA_W-1:0]     i_data,
    output logic [DATA_W-1:0]     o_data
);
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n)
            o_data <= DEFAULT_VALUE;
        else if (i_en)
            o_data <= i_data;
    end
endmodule
