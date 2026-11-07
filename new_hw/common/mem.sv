// Single-port, synchronous 1RW memory. At each rising edge:
//   i_en=0        : no access; retain o_rdata
//   i_en=1,i_we=1 : write i_wdata to i_addr; retain o_rdata (no-change mode)
//   i_en=1,i_we=0 : capture w_memory[i_addr] in o_rdata
// Memory is uninitialized unless MEM_INIT_FILE names a hexadecimal image.
// INIT_DATA_W/INIT_BIT_OFFSET select a DATA_W-bit slice from each file record;
// defaults load one complete DATA_W-bit word per record. o_rdata is not
// initialized by the image: it still updates only on an enabled read edge.
module mem #(
    parameter int unsigned DATA_W = 16,
    parameter int unsigned ADDR_W = 9,
    parameter int unsigned DEPTH = 2 ** ADDR_W,
    parameter RAM_STYLE = "block",
    parameter MEM_INIT_FILE = "",
    parameter int unsigned INIT_DATA_W = DATA_W,
    parameter int unsigned INIT_BIT_OFFSET = 0
)(
    input  logic                   i_clk,
    input  logic                   i_en,
    input  logic                   i_we,
    input  logic [ADDR_W-1:0]      i_addr,
    input  logic [DATA_W-1:0]      i_wdata,
    output logic [DATA_W-1:0]      o_rdata
);
    (* ram_style = RAM_STYLE *) logic [DATA_W-1:0] r_memory [0:DEPTH-1];

    generate
        if (MEM_INIT_FILE != "") begin : g_init
            logic [INIT_DATA_W-1:0] r_init_image [0:DEPTH-1];

            initial begin
                $readmemh(MEM_INIT_FILE, r_init_image);
                for (int w_addr = 0; w_addr < DEPTH; w_addr++)
                    r_memory[w_addr] = r_init_image[w_addr][INIT_BIT_OFFSET +: DATA_W];
            end
        end
    endgenerate

    always_ff @(posedge i_clk) begin
        if (i_en) begin
            if (i_we)
                r_memory[i_addr] <= i_wdata;
            else
                o_rdata <= r_memory[i_addr];
        end
    end
endmodule
