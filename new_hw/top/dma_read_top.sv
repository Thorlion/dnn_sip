// OB -> OM transfer engine.
// Source/destination addresses and transfer size use DATA_WIDTH-bit words,
// matching dma_write_top's address increments. Configure CSRs while idle,
// then write 1 to control bit 0 at byte offset 0x0C. The registered CSR start
// pulse is consumed on the following rising edge. Starts while transferring
// are ignored.
// OB reads complete after one rising edge and retain their output when disabled.
// OM accepts a write on each rising edge with o_om_wen asserted; no wait states.
// One initial OB read primes the data path, followed by one OM write per clock.
module dma_read_top #(
    parameter int unsigned DATA_WIDTH = 16
)(
    input  logic                  i_clk,
    input  logic                  i_rst_n,

    // CSR byte offsets: 0x00 source, 0x04 destination, 0x08 size, 0x0C control.
    input  logic [31:0]           i_csr_offset,
    input  logic [31:0]           i_csr_data,
    input  logic                  i_csr_wen,

    output logic                  o_dma_done,

    // OB synchronous read interface.
    input  logic [DATA_WIDTH-1:0] i_ob_data,
    output logic [31:0]           o_ob_addr,
    output logic                  o_ob_ren,

    // OM clocked write interface.
    output logic [DATA_WIDTH-1:0] o_om_data,
    output logic [31:0]           o_om_addr,
    output logic                  o_om_wen
);
    logic [31:0] w_source_addr;
    logic [31:0] w_dest_addr;
    logic [31:0] w_transfer_size;
    logic        w_dma_start;
    logic [31:0] r_counter;
    logic        w_last_transfer;

    typedef enum logic [1:0] {
        IDLE       = 2'd0,
        READ_FIRST = 2'd1,
        TRANSFER   = 2'd2
    } dma_state_t;

    dma_state_t r_current_state;
    dma_state_t w_next_state;

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

    assign w_last_transfer = (r_counter == (w_transfer_size - 32'd1));

    always_comb begin
        w_next_state = r_current_state;
        case (r_current_state)
            IDLE: begin
                if (w_dma_start && (w_transfer_size != 32'd0))
                    w_next_state = READ_FIRST;
            end
            READ_FIRST: w_next_state = TRANSFER;
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
            r_counter       <= '0;
            o_dma_done      <= 1'b0;
         end else begin
            r_current_state <= w_next_state;
            o_dma_done      <= 1'b0;

            case (r_current_state)
               IDLE: begin
                  r_counter <= '0;
                  // An empty transfer completes without any memory access.
                  if (w_dma_start && (w_transfer_size == 32'd0))
                     o_dma_done <= 1'b1;
               end
               TRANSFER: begin
                  // OM samples the current word on this edge. The next OB
                  // word, if requested, becomes available after this edge.
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
         o_ob_addr = '0;
         o_ob_ren  = 1'b0;
         o_om_data = '0;
         o_om_addr = '0;
         o_om_wen  = 1'b0;

         case (r_current_state)
            READ_FIRST: begin
               o_ob_addr = w_source_addr;
               o_ob_ren  = 1'b1;
            end
            TRANSFER: begin
               o_om_data = i_ob_data;
               o_om_addr = w_dest_addr + r_counter;
               o_om_wen  = 1'b1;

               if (!w_last_transfer) begin
                  o_ob_addr = w_source_addr + r_counter + 32'd1;
                  o_ob_ren  = 1'b1;
               end
            end
            default: begin
            end
        endcase
   end
endmodule
