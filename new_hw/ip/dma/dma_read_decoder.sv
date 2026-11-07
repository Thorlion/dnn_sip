// DMA1 OB read-address decoder. Addresses count 16-bit words, not bytes.
//   OB buffer 0: 0x0004_0000..0x0004_03FF (1024 words)
//   OB buffer 1: 0x0004_0400..0x0004_07FF (1024 words)
// Address bit 10 selects the buffer; bits [9:0] select its local word.
// Unmapped addresses and inactive DMA requests do not enable an OB read.
// Address/buffer outputs follow the input and are qualified by o_ob_ren.
//
// Combinational only: the slave OB supplies the one-cycle read latency.
// Connect slave o_ob_rdata directly to DMA1 i_ob_data; no data mux/register
// is needed here. There is no error, retry, or buffer-ownership handshake.
module dma_read_decoder (
    input  logic [31:0] i_dma_addr,
    input  logic        i_dma_ren,

    output logic        o_ob_ren,
    output logic [9:0]  o_ob_raddr,
    output logic        o_ob_rbuf_sel
);
    assign o_ob_raddr = i_dma_addr[9:0];
    assign o_ob_rbuf_sel = i_dma_addr[10];

    // Check all upper bits so other regions and high-address aliases cannot
    // access OB. The low-word range includes exactly the two buffers.
    assign o_ob_ren = i_dma_ren &&
                      (i_dma_addr[31:16] == 16'h0004) &&
                      (i_dma_addr[15:0] < 16'h0800);
endmodule
