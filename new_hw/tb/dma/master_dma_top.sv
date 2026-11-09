// Master + DMA integration DUT. All payload memories remain outside this module.
// DMA0: asynchronous OM reads -> clocked input-buffer writes.
// DMA1: one-cycle synchronous OB reads -> clocked OM writes.
// OM and local memory addresses/counts are DATA_WIDTH-bit words, not bytes.
// The two OM ports are independent and have no wait-state handshake.
module master_dma_top #(
    parameter int unsigned DATA_WIDTH = 16,
    parameter IMEM_INIT_FILE = "led_blink.mem"
)(
    input  logic                  i_clk,
    input  logic                  i_rst_n,

    // DMA0 OM read port: data is combinational for the requested address.
    input  logic [DATA_WIDTH-1:0] i_om_rdata,
    output logic [31:0]           o_om_raddr,
    output logic                  o_om_ren,

    // DMA1 OM write port: the memory samples a write on each enabled edge.
    output logic [DATA_WIDTH-1:0] o_om_wdata,
    output logic [31:0]           o_om_waddr,
    output logic                  o_om_wen,

    // DMA0 local destination, representing IB/KSP/BSP write interfaces.
    output logic [DATA_WIDTH-1:0] o_slave_wdata,
    output logic [31:0]           o_slave_waddr,
    output logic                  o_slave_wen,

    // DMA1 local source, representing the synchronous OB read interface.
    input  logic [DATA_WIDTH-1:0] i_ob_rdata,
    output logic [31:0]           o_ob_raddr,
    output logic                  o_ob_ren,

    output logic                  o_dma0_done,
    output logic                  o_dma1_done
);
    logic [31:0] w_dma_csr_data;
    logic [31:0] w_dma_csr_offset;
    logic        w_wen_dma0;
    logic        w_wen_dma1;

    dsip_master #(
        .IMEM_INIT_FILE(IMEM_INIT_FILE)
    ) u_master (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        // No slave in this DMA-only harness; WAIT_ROW would wait indefinitely.
        .i_slave_row_done(1'b0),
        .i_slave_done(1'b0),
        .o_dma_csr_data(w_dma_csr_data),
        .o_dma_csr_offset(w_dma_csr_offset),
        .o_wen_dma0(w_wen_dma0),
        .o_wen_dma1(w_wen_dma1),
        // This DMA-only bench does not instantiate a slave for SCR.
        .o_slave_start(),
        .o_slave_pc()
    );

    dma_write_top #(.DATA_WIDTH(DATA_WIDTH)) u_dma0 (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_csr_offset(w_dma_csr_offset),
        .i_csr_data(w_dma_csr_data),
        .i_csr_wen(w_wen_dma0),
        .o_dma_done(o_dma0_done),
        .i_om_data(i_om_rdata),
        .o_om_addr(o_om_raddr),
        .o_om_ren(o_om_ren),
        .o_slave_data(o_slave_wdata),
        .o_slave_addr(o_slave_waddr),
        .o_slave_wen(o_slave_wen)
    );

    dma_read_top #(.DATA_WIDTH(DATA_WIDTH)) u_dma1 (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_csr_offset(w_dma_csr_offset),
        .i_csr_data(w_dma_csr_data),
        .i_csr_wen(w_wen_dma1),
        .o_dma_done(o_dma1_done),
        .i_ob_data(i_ob_rdata),
        .o_ob_addr(o_ob_raddr),
        .o_ob_ren(o_ob_ren),
        .o_om_data(o_om_wdata),
        .o_om_addr(o_om_waddr),
        .o_om_wen(o_om_wen)
    );
endmodule
