// Four 16-bit single-port banks store one 64-bit record per instruction.
// ADDR_W is the instruction-index width; DEPTH is the instruction count.
// i_raddr is an instruction index and selects a complete row for reads.
// i_waddr is a 16-bit-word address: [ADDR_W+1:2] selects the instruction row,
// and [1:0] selects a bank for writes. Word 0 holds record [15:0], word 3
// holds [63:48]. i_we selects the write address; otherwise use the read address.
// Enabled reads update all four bank outputs after one edge. Writes update
// only the selected bank and retain all read outputs. Disabled accesses hold.
// o_rdata returns the low INSTR_W bits (supported range 1..64). The current
// instruction uses all 64 record bits, including output-path selection fields.
// MEM_INIT_FILE optionally preloads one 64-bit hexadecimal record per line.
// Each bank loads its corresponding 16-bit slice. An empty parameter disables
// preloading; an empty file supplies no defined instructions. DMA writes can
// overwrite the image later. Instruction storage has no reset.
module imem #(
    parameter int unsigned INSTR_W = 64,
    parameter int unsigned ADDR_W = 9,
    parameter int unsigned DEPTH = 2 ** ADDR_W,
    parameter MEM_INIT_FILE = ""
)(
    input  logic                   i_clk,
    input  logic                   i_en,
    input  logic                   i_we,
    input  logic [ADDR_W-1:0]      i_raddr,
    input  logic [ADDR_W+1:0]      i_waddr,
    input  logic [15:0]            i_wdata,
    output logic [INSTR_W-1:0]     o_rdata
);
    logic [63:0] w_record;
    logic [ADDR_W-1:0] w_row_addr;

    // The banks remain single-port: select one row address for this access.
    assign w_row_addr = i_we ? i_waddr[ADDR_W+1:2] : i_raddr;

    generate
        for (genvar w_bank = 0; w_bank < 4; w_bank++) begin : g_bank
            mem #(
                .DATA_W(16), .ADDR_W(ADDR_W), .DEPTH(DEPTH),
                .MEM_INIT_FILE(MEM_INIT_FILE),
                .INIT_DATA_W(64), .INIT_BIT_OFFSET(w_bank * 16)
            ) u_mem (
                .i_clk(i_clk),
                // Read every bank; write only the bank selected by i_waddr.
                .i_en(i_en && (!i_we || (i_waddr[1:0] == 2'(w_bank)))),
                .i_we(i_we),
                .i_addr(w_row_addr),
                .i_wdata(i_wdata),
                .o_rdata(w_record[w_bank*16 +: 16])
            );
        end
    endgenerate

    assign o_rdata = w_record[INSTR_W-1:0];
endmodule
