// DMA0 programming-side decoder. All addresses count 16-bit words, not bytes.
// No clock, reset, storage or added pipeline latency; memories sample the
// decoded write controls and forwarded data on their rising clock edge.
//
// Valid word-address ranges at PC_W=9:
//   IB:   0x0000_0000..0x0000_07FF (two buffers x 1024 words)
//   KSP:  0x0001_0000..0x0001_7FFF (two buffers x 64 banks x 256 words)
//   BSP:  0x0002_0000..0x0002_003F (64 words)
//   IMEM: 0x0003_0000..0x0003_07FF (512 records x four words)
// IB write buffer = address[10]; local IB word = address[9:0].
// KSP write buffer = address[14]; bank = address[13:8]; word = address[7:0].
// IMEM record n uses local word addresses 4*n through 4*n+3.
// Address holes, OB/OSP regions and nonzero upper region bits enable no write.
// Data/addresses are meaningful only with the corresponding write strobe.
//
// These are programming controls only. Execution read-buffer selectors and
// lane-enable masks remain external; write addresses use dedicated slave ports.
// PC_W must be in 1..14 so all four IMEM words fit in its 64K-word region.
module dma_write_decoder #(
    parameter int unsigned PC_W = 9
)(
    input  logic [31:0]         i_dma_addr,
    input  logic [15:0]         i_dma_data,
    input  logic                i_dma_wen,

    output logic                o_ib_en,
    output logic                o_ib_we,
    output logic                o_ib_wbuf_sel,
    output logic [9:0]         o_ib_addr,
    output logic [15:0]        o_ib_wdata,

    output logic [63:0]        o_ksp_en,
    output logic [63:0]        o_ksp_we,
    output logic                o_ksp_wbuf_sel,
    output logic [7:0]         o_ksp_addr,
    output logic [15:0]        o_ksp_wdata [0:63],

    output logic                o_bsp_en,
    output logic                o_bsp_we,
    output logic [5:0]         o_bsp_addr,
    output logic [15:0]        o_bsp_wdata,

    output logic                o_imem_we,
    output logic [PC_W+1:0]    o_imem_waddr,
    output logic [15:0]        o_imem_wdata
);
    localparam logic [31:0] IMEM_WORD_COUNT = 32'd1 << (PC_W + 2);

    // Each local address starts at zero within its memory region.
    assign o_ib_addr = i_dma_addr[9:0];
    assign o_ib_wbuf_sel = i_dma_addr[10];
    assign o_ksp_addr = i_dma_addr[7:0];
    assign o_ksp_wbuf_sel = i_dma_addr[14];
    assign o_bsp_addr = i_dma_addr[5:0];
    assign o_imem_waddr = i_dma_addr[PC_W+1:0];

    // Share the data bus. Only a decoded write strobe permits storage updates.
    assign o_ib_wdata = i_dma_data;
    assign o_bsp_wdata = i_dma_data;
    assign o_imem_wdata = i_dma_data;
    generate
        for (genvar w_bank = 0; w_bank < 64; w_bank++) begin : g_ksp_data
            assign o_ksp_wdata[w_bank] = i_dma_data;
        end
    endgenerate

    always_comb begin
        o_ib_en = 1'b0;
        o_ib_we = 1'b0;
        o_ksp_en = 64'd0;
        o_ksp_we = 64'd0;
        o_bsp_en = 1'b0;
        o_bsp_we = 1'b0;
        o_imem_we = 1'b0;

        if (i_dma_wen) begin
            // Decode every upper bit so higher addresses cannot alias a region.
            case (i_dma_addr[31:16])
                16'h0000: begin
                    if (i_dma_addr[15:0] < 16'h0800) begin
                        o_ib_en = 1'b1;
                        o_ib_we = 1'b1;
                    end
                end
                16'h0001: begin
                    if (i_dma_addr[15:0] < 16'h8000) begin
                        o_ksp_en[i_dma_addr[13:8]] = 1'b1;
                        o_ksp_we[i_dma_addr[13:8]] = 1'b1;
                    end
                end
                16'h0002: begin
                    if (i_dma_addr[15:0] < 16'h0040) begin
                        o_bsp_en = 1'b1;
                        o_bsp_we = 1'b1;
                    end
                end
                16'h0003: begin
                    if ({16'd0, i_dma_addr[15:0]} < IMEM_WORD_COUNT)
                        o_imem_we = 1'b1;
                end
                default: begin
                    // Unmapped writes leave every memory disabled.
                end
            endcase
        end
    end
endmodule
