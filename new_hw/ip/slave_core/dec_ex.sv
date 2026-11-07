// EXE decoder for the nine instruction bits forwarded from IF.
//   [8]   MULT1: 0 = zero, 1 = MLI
//   [7]   MULT2: 0 = fixed-point unity, 1 = MLK
//   [6:5] ACC:   00 = zero, 01 = MLO, 10 = EOA, 11 = reserved by the ISA
//   [4:3] OSP mux select low bits, already consumed in ML
//   [2]   MAX/MAC: 0 = MAC, 1 = MAX
//   [1:0] store fields are reserved for a later-stage decoder.
// MAX1/MAX2 have been repurposed; the MAX datapath is not connected yet.
module dec_ex (
    input  logic       i_valid,
    input  logic [8:0] i_instruction,

    output logic       o_mult_sel_1,
    output logic       o_mult_sel_2,
    output logic [1:0] o_acc_sel,
    output logic       o_max_or_mac,
    output logic       o_mac_en
);
    assign o_mult_sel_1 = i_instruction[8];
    assign o_mult_sel_2 = i_instruction[7];
    assign o_acc_sel = i_instruction[6:5];
    assign o_max_or_mac = i_instruction[2];

    // Do not commit MAC results for bubbles or the unimplemented MAX mode.
    assign o_mac_en = i_valid && !i_instruction[2];
endmodule
