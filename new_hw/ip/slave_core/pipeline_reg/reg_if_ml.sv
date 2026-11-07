// IF to memory-load control pipeline register.
// The low nine-bit payload includes EXE controls, OSP select copies and stores.
// The instruction's OSP address advances alongside that payload for stores.
// OSP mux selection advances to ML; OB write-buffer selection follows stores.
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
    input  logic [5:0]              i_osp_mux_sel,
    input  logic                    i_ob_wbuf_sel,
    output logic                    o_valid,
    output logic [INSTR_W-1:0]      o_instruction,
    output logic [OSP_ADDR_W-1:0]   o_osp_addr,
    output logic [5:0]              o_osp_mux_sel,
    output logic                    o_ob_wbuf_sel
);
    logic [INSTR_W-1:0] w_instruction;
    logic [OSP_ADDR_W-1:0] w_osp_addr;
    logic [5:0] w_osp_mux_sel;
    logic w_ob_wbuf_sel;

    assign w_instruction = i_valid ? i_instruction : '0;
    assign w_osp_addr = i_valid ? i_osp_addr : '0;
    assign w_osp_mux_sel = i_valid ? i_osp_mux_sel : '0;
    assign w_ob_wbuf_sel = i_valid && i_ob_wbuf_sel;

    register #(.DATA_W(6), .DEFAULT_VALUE('0)) u_osp_mux_sel (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_en(1'b1),
        .i_data(w_osp_mux_sel),
        .o_data(o_osp_mux_sel)
    );

    register #(.DATA_W(1), .DEFAULT_VALUE(1'b0)) u_ob_wbuf_sel (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_en(1'b1),
        .i_data(w_ob_wbuf_sel),
        .o_data(o_ob_wbuf_sel)
    );

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
