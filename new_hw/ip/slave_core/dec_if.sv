// IF decoder for the 64-bit instruction.
//   [63] OB buffer switch; {[62:59], [4:3]} OSP mux selection
//   [58:53] set iteration, [52] DONE, [45:44] SBP selector, [43:42] CLP selector
//   [51:46] IB control  (switch, clear, sign, 3-bit magnitude)
//   [39:31] KSP control (switch, sign, 7-bit magnitude; no clear)
//   [30:20] OSP control (clear, sign, 9-bit magnitude)
//   [19:15] BSP control (clear, sign, 3-bit magnitude)
//   [41] ROW_DONE; [40], [14:13] reserved, encode zero
//   [12:9]  load IB, KSP, OSP, BSP
//   [8:5], [2] arithmetic (decoded later); [4:3] no longer encode MAX1/MAX2
//   [1:0]   store OSP, OB (decoded later)
// IF consumes flow control, address control, memory load and output selections.
// The caller supplies a zero word when no instruction is being issued.
module dec_if (
    input  logic [63:0] i_instruction,

    output logic        o_ob_switch,
    output logic [5:0]  o_osp_mux_sel,

    output logic [5:0]  o_set_iteration,
    output logic [1:0]  o_set_breakpoint,
    output logic [1:0]  o_conditional_loop,
    output logic        o_done,
    output logic        o_row_done,

    output logic        o_ib_switch,
    output logic        o_ib_clear,
    output logic        o_ib_sign,
    output logic [2:0]  o_ib_offset,
    output logic        o_ksp_switch,
    output logic        o_ksp_sign,
    output logic [6:0]  o_ksp_offset,
    output logic        o_osp_clear,
    output logic        o_osp_sign,
    output logic [8:0]  o_osp_offset,
    output logic        o_bsp_clear,
    output logic        o_bsp_sign,
    output logic [2:0]  o_bsp_offset,

    output logic        o_load_ib,
    output logic        o_load_ksp,
    output logic        o_load_osp,
    output logic        o_load_bsp
);
    assign o_ob_switch = i_instruction[63];
    assign o_osp_mux_sel = {i_instruction[62:59], i_instruction[4:3]};
    assign o_set_iteration = i_instruction[58:53];
    assign o_set_breakpoint = i_instruction[45:44];
    assign o_conditional_loop = i_instruction[43:42];
    assign o_done = i_instruction[52];
    assign o_row_done = i_instruction[41];
    assign {o_ib_switch, o_ib_clear, o_ib_sign, o_ib_offset} = i_instruction[51:46];
    assign {o_ksp_switch, o_ksp_sign, o_ksp_offset} = i_instruction[39:31];
    assign {o_osp_clear, o_osp_sign, o_osp_offset} = i_instruction[30:20];
    assign {o_bsp_clear, o_bsp_sign, o_bsp_offset} = i_instruction[19:15];
    assign {o_load_ib, o_load_ksp, o_load_osp, o_load_bsp} =
        i_instruction[12:9];
endmodule
