// IF to memory-load control pipeline register.
// The remaining instruction payload is arithmetic [8:2] plus store [1:0].
// The instruction's OSP address advances alongside that payload for stores.
// Validity is separate from the instruction encoding. Invalid inputs insert
// a zero-valued bubble; active-low asynchronous reset clears all outputs.
module reg_if_ml #(
    parameter int unsigned INSTR_W = 9,
    parameter int unsigned OSP_ADDR_W = 9
)(
    input  logic                    i_clk,
    input  logic                    i_rst_n,
    input  logic                    i_valid,
    input  logic [INSTR_W-1:0]      i_instruction,
    input  logic [OSP_ADDR_W-1:0]   i_osp_addr,
    output logic                    o_valid,
    output logic [INSTR_W-1:0]      o_instruction,
    output logic [OSP_ADDR_W-1:0]   o_osp_addr
);
    logic [INSTR_W-1:0] w_instruction;
    logic [OSP_ADDR_W-1:0] w_osp_addr;

    assign w_instruction = i_valid ? i_instruction : '0;
    assign w_osp_addr = i_valid ? i_osp_addr : '0;

    register #(.DATA_W(INSTR_W), .DEFAULT_VALUE('0)) u_instruction (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_en(1'b1),
        .i_data(w_instruction),
        .o_data(o_instruction)
    );

    register #(.DATA_W(OSP_ADDR_W), .DEFAULT_VALUE('0)) u_osp_addr (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_en(1'b1),
        .i_data(w_osp_addr),
        .o_data(o_osp_addr)
    );

    register #(.DATA_W(1), .DEFAULT_VALUE(1'b0)) u_valid (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_en(1'b1),
        .i_data(i_valid),
        .o_data(o_valid)
    );
endmodule
