// One master, one 64-lane slave, DMA0 (OM -> slave) and DMA1 (OB -> OM).
// Payload data is 16 bits; DMA addresses/counts use 16-bit words.
// OM remains outside the synthesis boundary: asynchronous read, clocked write,
// independent ports and no wait states. All modules share i_clk/i_rst_n.
//
// DMA_CONFIG drives the two DMA CSR write ports. SCR directly starts the slave
// at its forwarded instruction index. DMA0 programs memories through the write
// decoder; DMA1 selects an OB buffer/word through the read decoder.
// Execution bank/lane masks are all enabled, matching the current slave bench.
// WAIT_ROW consumes the slave's ROW_DONE events before the master proceeds.
module single_system_top #(
    parameter int unsigned PC_W = 9,
    parameter MASTER_IMEM_FILE = "single_master_imem.mem",
    parameter SLAVE_IMEM_FILE = "single_slave_imem.mem"
)(
    input  logic        i_clk,
    input  logic        i_rst_n,

    input  logic [15:0] i_om_rdata,
    output logic [31:0] o_om_raddr,
    output logic        o_om_ren,
    output logic [15:0] o_om_wdata,
    output logic [31:0] o_om_waddr,
    output logic        o_om_wen,

    output logic        o_dma0_done,
    output logic        o_dma1_done,
    output logic        o_slave_done,
    output logic        o_slave_row_done
);
    logic [31:0] w_dma_csr_data;
    logic [31:0] w_dma_csr_offset;
    logic w_wen_dma0;
    logic w_wen_dma1;
    logic w_slave_start;
    logic [31:0] w_slave_start_pc;
    logic [PC_W-1:0] w_slave_pc;

    logic [31:0] w_dma0_addr;
    logic [15:0] w_dma0_data;
    logic w_dma0_wen;
    logic w_ib_we;
    logic w_ib_wbuf_sel;
    logic [9:0] w_ib_waddr;
    logic [15:0] w_ib_wdata;
    logic [63:0] w_ksp_we;
    logic w_ksp_wbuf_sel;
    logic [7:0] w_ksp_waddr;
    logic [15:0] w_ksp_wdata [0:63];
    logic w_bsp_we;
    logic [5:0] w_bsp_waddr;
    logic [15:0] w_bsp_wdata;
    logic w_imem_we;
    logic [PC_W+1:0] w_imem_waddr;
    logic [15:0] w_imem_wdata;

    logic [31:0] w_dma1_addr;
    logic w_dma1_ren;
    logic w_ob_ren;
    logic [9:0] w_ob_raddr;
    logic w_ob_rbuf_sel;
    logic [15:0] w_ob_rdata;

    dsip_master #(.IMEM_INIT_FILE(MASTER_IMEM_FILE)) u_master (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_slave_row_done(o_slave_row_done),
        .o_dma_csr_data(w_dma_csr_data),
        .o_dma_csr_offset(w_dma_csr_offset),
        .o_wen_dma0(w_wen_dma0),
        .o_wen_dma1(w_wen_dma1),
        .o_slave_start(w_slave_start),
        .o_slave_pc(w_slave_start_pc)
    );

    dma_write_top #(.DATA_WIDTH(16)) u_dma0 (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_csr_offset(w_dma_csr_offset),
        .i_csr_data(w_dma_csr_data),
        .i_csr_wen(w_wen_dma0),
        .o_dma_done(o_dma0_done),
        .i_om_data(i_om_rdata),
        .o_om_addr(o_om_raddr),
        .o_om_ren(o_om_ren),
        .o_slave_data(w_dma0_data),
        .o_slave_addr(w_dma0_addr),
        .o_slave_wen(w_dma0_wen)
    );

    dma_write_decoder #(.PC_W(PC_W)) u_dma_write_decoder (
        .i_dma_addr(w_dma0_addr),
        .i_dma_data(w_dma0_data),
        .i_dma_wen(w_dma0_wen),
        // Runtime enables are always high, so they already cover programming.
        .o_ib_en(),
        .o_ib_we(w_ib_we),
        .o_ib_wbuf_sel(w_ib_wbuf_sel),
        .o_ib_addr(w_ib_waddr),
        .o_ib_wdata(w_ib_wdata),
        .o_ksp_en(),
        .o_ksp_we(w_ksp_we),
        .o_ksp_wbuf_sel(w_ksp_wbuf_sel),
        .o_ksp_addr(w_ksp_waddr),
        .o_ksp_wdata(w_ksp_wdata),
        .o_bsp_en(),
        .o_bsp_we(w_bsp_we),
        .o_bsp_addr(w_bsp_waddr),
        .o_bsp_wdata(w_bsp_wdata),
        .o_imem_we(w_imem_we),
        .o_imem_waddr(w_imem_waddr),
        .o_imem_wdata(w_imem_wdata)
    );

    dma_read_top #(.DATA_WIDTH(16)) u_dma1 (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_csr_offset(w_dma_csr_offset),
        .i_csr_data(w_dma_csr_data),
        .i_csr_wen(w_wen_dma1),
        .o_dma_done(o_dma1_done),
        .i_ob_data(w_ob_rdata),
        .o_ob_addr(w_dma1_addr),
        .o_ob_ren(w_dma1_ren),
        .o_om_data(o_om_wdata),
        .o_om_addr(o_om_waddr),
        .o_om_wen(o_om_wen)
    );

    dma_read_decoder u_dma_read_decoder (
        .i_dma_addr(w_dma1_addr),
        .i_dma_ren(w_dma1_ren),
        .o_ob_ren(w_ob_ren),
        .o_ob_raddr(w_ob_raddr),
        .o_ob_rbuf_sel(w_ob_rbuf_sel)
    );

    dsip_slave #(
        .PC_W(PC_W), .IMEM_INIT_FILE(SLAVE_IMEM_FILE)
    ) u_slave (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_start(w_slave_start),
        .i_start_pc(w_slave_start_pc[PC_W-1:0]),
        .i_pc_en(1'b1),
        .o_pc(w_slave_pc),
        .o_done(o_slave_done),
        .o_row_done(o_slave_row_done),
        .i_imem_we(w_imem_we),
        .i_imem_waddr(w_imem_waddr),
        .i_imem_wdata(w_imem_wdata),
        .o_exe_instruction(),
        .o_exe_valid(),
        .o_nl_instruction(),
        .o_nl_valid(),
        .o_pc_load(),
        .o_pc_target(),
        .o_ib_addr(),
        .o_ksp_addr(),
        .o_osp_addr(),
        .o_bsp_addr(),
        .o_ob_addr(),
        .i_ksp_en(64'hFFFF_FFFF_FFFF_FFFF),
        .i_ksp_we(w_ksp_we),
        .i_ksp_wbuf_sel(w_ksp_wbuf_sel),
        .i_ksp_waddr(w_ksp_waddr),
        .i_ksp_wdata(w_ksp_wdata),
        .o_ksp_rdata(),
        .i_osp_en(64'hFFFF_FFFF_FFFF_FFFF),
        .i_osp_we(64'hFFFF_FFFF_FFFF_FFFF),
        .o_osp_rdata(),
        .i_ob_ren(w_ob_ren),
        .i_ob_raddr(w_ob_raddr),
        .i_ob_rbuf_sel(w_ob_rbuf_sel),
        .o_ob_rdata(w_ob_rdata),
        .i_ib_en(1'b1),
        .i_ib_we(w_ib_we),
        .i_ib_wbuf_sel(w_ib_wbuf_sel),
        .i_ib_waddr(w_ib_waddr),
        .i_ib_wdata(w_ib_wdata),
        .o_ib_rdata(),
        .i_mli_en(64'hFFFF_FFFF_FFFF_FFFF),
        .i_mlk_en(64'hFFFF_FFFF_FFFF_FFFF),
        .i_mlo_en(64'hFFFF_FFFF_FFFF_FFFF),
        .o_mli_out(),
        .o_mlk_out(),
        .o_mlo_out(),
        .i_eoa_en(64'hFFFF_FFFF_FFFF_FFFF),
        .o_eoa_out(),
        .i_bsp_en(1'b1),
        .i_bsp_we(w_bsp_we),
        .i_bsp_waddr(w_bsp_waddr),
        .i_bsp_wdata(w_bsp_wdata),
        .o_bsp_rdata()
    );
endmodule
