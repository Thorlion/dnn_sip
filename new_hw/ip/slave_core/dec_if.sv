// IF decoder for the 58-bit instruction, ordered top-to-bottom as specified.
//   [57:53] set iteration, [52] SBP, [51] CLP
//   [50:40] IB address control  (sign [50], value [49:40])
//   [39:30] KSP address control (sign [39], value [38:30])
//   [29:20] OSP address control (sign [29], value [28:20])
//   [19:13] BSP address control (sign [19], value [18:13])
//   [12:9]  load IB, KSP, OSP, BSP
//   [8:2]   arithmetic (decoded later)
//   [1:0]   store OSP, OB (decoded later)
// IF consumes only flow control, address control and memory load.
// The caller supplies a zero word when no instruction is being issued.
module dec_if (
    input  logic [57:0] i_instruction,

    output logic [4:0]  o_set_iteration,
    output logic        o_set_breakpoint,
    output logic        o_conditional_loop,

    output logic        o_ib_sign,
    output logic [9:0]  o_ib_offset,
    output logic        o_ksp_sign,
    output logic [8:0]  o_ksp_offset,
    output logic        o_osp_sign,
    output logic [8:0]  o_osp_offset,
    output logic        o_bsp_sign,
    output logic [5:0]  o_bsp_offset,

    output logic        o_load_ib,
    output logic        o_load_ksp,
    output logic        o_load_osp,
    output logic        o_load_bsp
);
    assign {o_set_iteration, o_set_breakpoint, o_conditional_loop} =
        i_instruction[57:51];
    assign {o_ib_sign, o_ib_offset} = i_instruction[50:40];
    assign {o_ksp_sign, o_ksp_offset} = i_instruction[39:30];
    assign {o_osp_sign, o_osp_offset} = i_instruction[29:20];
    assign {o_bsp_sign, o_bsp_offset} = i_instruction[19:13];
    assign {o_load_ib, o_load_ksp, o_load_osp, o_load_bsp} =
        i_instruction[12:9];
endmodule
