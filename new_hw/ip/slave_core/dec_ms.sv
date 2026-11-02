// Memory-store decoder for the two remaining instruction bits at NL output.
// [1] = Store OSP, [0] = Store OB. Invalid entries request neither store.
module dec_ms (
    input  logic       i_valid,
    input  logic [1:0] i_instruction,
    output logic       o_store_osp,
    output logic       o_store_ob
);
    assign o_store_osp = i_valid && i_instruction[1];
    assign o_store_ob = i_valid && i_instruction[0];
endmodule
