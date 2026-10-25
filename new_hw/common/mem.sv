// Single-port, synchronous 1RW memory. At each rising edge:
//   i_en=0        : no access; retain o_rdata
//   i_en=1,i_we=1 : write i_wdata to i_addr; retain o_rdata (no-change mode)
//   i_en=1,i_we=0 : capture w_memory[i_addr] in o_rdata
// Memory and o_rdata are intentionally uninitialized. Write before reading.
module mem #(
    parameter int unsigned DATA_W = 16,
    parameter int unsigned ADDR_W = 9,
    parameter int unsigned DEPTH = 2 ** ADDR_W,
    parameter RAM_STYLE = "block"
)(
    input  logic                   i_clk,
    input  logic                   i_en,
    input  logic                   i_we,
    input  logic [ADDR_W-1:0]      i_addr,
    input  logic [DATA_W-1:0]      i_wdata,
    output logic [DATA_W-1:0]      o_rdata
);
    (* ram_style = RAM_STYLE *) logic [DATA_W-1:0] w_memory [0:DEPTH-1];

    always_ff @(posedge i_clk) begin
        if (i_en) begin
            if (i_we)
                w_memory[i_addr] <= i_wdata;
            else
                o_rdata <= w_memory[i_addr];
        end
    end
endmodule