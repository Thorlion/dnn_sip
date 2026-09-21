module agu_adder #(
    parameter SCRATCHPAD_W = 512
)(
    input  logic [$clog2(SCRATCHPAD_W)-1:0] cur_addr,       // Current base address in register
    input  logic [$clog2(SCRATCHPAD_W)-1:0] new_addr,       // New base address to write
    input  logic select_addr,       // select new base address
    input  logic select_offset,     // select offset

    input  logic [7:0] add_buf,     // adder buffer

    output logic [$clog2(SCRATCHPAD_W)-1:0] addr_out
);
    logic [$clog2(SCRATCHPAD_W)-1:0] addr;

    // Select current address or new address
    always_comb begin
        if (select_addr == '0) begin
            addr = cur_addr;
        end else begin
            addr = new_addr;
        end
    end

    // Iter_en = 1: back to 0 (loop end)
    // Select offset = 1: add adder buffer; Select offset = 0: keep base
    assign addr_out = select_offset ? (addr + add_buf) : addr;
endmodule