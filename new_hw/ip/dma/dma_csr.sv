// DMA configuration registers, selected by a 32-bit byte offset:
//   0x00: source address, 0x04: destination address, 0x08: transfer size.
//   0x0C: control; writing bit 0 as one generates o_dma_start for one clock.
// Each asserted i_csr_wen cycle represents one accepted write.
// Configuration writes update one complete 32-bit register. Other offsets and
// control bits are ignored. START is a command, so software need not clear it.
// Reset is asynchronous and active low; all registers and START reset to zero.
module dma_csr (
    input  logic        i_clk,
    input  logic        i_rst_n,
    input  logic [31:0] i_csr_offset,
    input  logic [31:0] i_csr_data,
    input  logic        i_csr_wen,
    output logic [31:0] o_source_addr,
    output logic [31:0] o_dest_addr,
    output logic [31:0] o_transfer_size,
    output logic        o_dma_start
);
    localparam logic [31:0] SOURCE_ADDR_OFFSET   = 32'h0000_0000;
    localparam logic [31:0] DEST_ADDR_OFFSET     = 32'h0000_0004;
    localparam logic [31:0] TRANSFER_SIZE_OFFSET = 32'h0000_0008;
    localparam logic [31:0] CONTROL_OFFSET       = 32'h0000_000C;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_dma_start <= 1'b0;
        end else begin
            o_dma_start <= 1'b0;
            if (i_csr_wen && (i_csr_offset == CONTROL_OFFSET) && i_csr_data[0])
                o_dma_start <= 1'b1;
        end
    end

    register #(.DATA_W(32)) u_source_addr (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_en(i_csr_wen && (i_csr_offset == SOURCE_ADDR_OFFSET)),
        .i_data(i_csr_data),
        .o_data(o_source_addr)
    );

    register #(.DATA_W(32)) u_dest_addr (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_en(i_csr_wen && (i_csr_offset == DEST_ADDR_OFFSET)),
        .i_data(i_csr_data),
        .o_data(o_dest_addr)
    );

    register #(.DATA_W(32)) u_transfer_size (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_en(i_csr_wen && (i_csr_offset == TRANSFER_SIZE_OFFSET)),
        .i_data(i_csr_data),
        .o_data(o_transfer_size)
    );
endmodule
