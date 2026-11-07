// OM reads are asynchronous; the slave accepts each enabled write on a rising edge.
// Addresses and transfer size use DATA_WIDTH-bit words. Configure CSRs while idle,
// then write 1 to control bit 0 at byte offset 0x0C. The registered CSR start
// pulse is consumed on the following rising edge. Starts while transferring
// are ignored.
// o_dma_done pulses for one clock after the final write, or for an empty transfer.
module dma_write_top #(
    parameter DATA_WIDTH = 16
    )(
    input logic i_clk,
    input logic i_rst_n,

    // Config CSR
    input logic [31:0] i_csr_offset,
    input logic [31:0] i_csr_data,
    input logic        i_csr_wen,

    output logic        o_dma_done,

    // OM -> Input
    // OM Interface read
    input  logic [DATA_WIDTH-1:0] i_om_data,
    output logic [31:0] o_om_addr,
    output logic o_om_ren,

    // IB, KSP, BSP, Slave IMEM write interface
    output logic [DATA_WIDTH-1:0] o_slave_data,
    output logic [31:0] o_slave_addr,
    output logic o_slave_wen
   
);

    logic [31:0] w_source_addr;
    logic [31:0] w_dest_addr;
    logic [31:0] w_transfer_size;
    logic        w_dma_start;

    dma_csr u_dma_csr (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_csr_offset(i_csr_offset),
        .i_csr_data(i_csr_data),
        .i_csr_wen(i_csr_wen),
        .o_source_addr(w_source_addr),
        .o_dest_addr(w_dest_addr),
        .o_transfer_size(w_transfer_size),
        .o_dma_start(w_dma_start)
    );

    logic [31:0] r_counter;
    logic        r_current_state;
    logic        w_next_state;
    logic        w_last_transfer;

    localparam logic IDLE = 1'b0, TRANSFER = 1'b1;

    assign w_last_transfer = (r_counter == (w_transfer_size - 32'd1));

    always_comb begin
        w_next_state = r_current_state;
        case (r_current_state)
            IDLE: begin
                if (w_dma_start && (w_transfer_size != 32'd0))
                    w_next_state = TRANSFER;
            end
            TRANSFER: begin
                if (w_last_transfer)
                    w_next_state = IDLE;
            end
            default: w_next_state = IDLE;
        endcase
    end 

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin 
            r_current_state <= IDLE;
            r_counter <= '0;
            o_dma_done <= 1'b0;
        end
        else begin
            r_current_state <= w_next_state;
            o_dma_done <= 1'b0;

            case (r_current_state)
                IDLE: begin
                    r_counter <= '0;
                    if (w_dma_start && (w_transfer_size == 32'd0))
                        o_dma_done <= 1'b1;
                end
                TRANSFER: begin
                    // The slave captures the final word on this edge.
                    if (w_last_transfer)
                        o_dma_done <= 1'b1;
                    else
                        r_counter <= r_counter + 32'd1;
                end
                default: begin
                end
            endcase
        end
    end     

    always_comb begin
        o_slave_wen = (r_current_state == TRANSFER);
        o_om_ren = (r_current_state == TRANSFER);
    end 

    assign o_slave_data = i_om_data;
    assign o_slave_addr = w_dest_addr + r_counter;
    assign o_om_addr = w_source_addr + r_counter;

endmodule 
