module DecoderNL (
    input  logic [8:0] slot5,

    output logic sel_lut,           // 0: LUT0 1: LUT1
    output logic [7:0] sel_NOA      //
);

    assign sel_lut      = slot5[8];
    assign sel_NOA      = slot5[7:0]; // Select 0-63 EOA_read to NOA 
endmodule