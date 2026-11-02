// Synchronous single-port instruction memory. One access per rising edge:
// enabled reads update o_rdata after the edge; writes retain o_rdata.
// No reset or initialization of instruction storage is performed.
// Default depth matches the 9-bit PC and each word holds the 58-bit instruction.
module imem #(
    parameter int unsigned INSTR_W = 58,
    parameter int unsigned ADDR_W = 9,
    parameter int unsigned DEPTH = 2 ** ADDR_W
)(
    input  logic                   i_clk,
    input  logic                   i_en,
    input  logic                   i_we,
    input  logic [ADDR_W-1:0]      i_addr,
    input  logic [INSTR_W-1:0]     i_wdata,
    output logic [INSTR_W-1:0]     o_rdata
);
    mem #(.DATA_W(INSTR_W), .ADDR_W(ADDR_W), .DEPTH(DEPTH)) u_mem (
        .i_clk(i_clk),
        .i_en(i_en),
        .i_we(i_we),
        .i_addr(i_addr),
        .i_wdata(i_wdata),
        .o_rdata(o_rdata)
    );
endmodule
