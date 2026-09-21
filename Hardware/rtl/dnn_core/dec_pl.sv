module DecoderPL (
    input  logic [11:0]slot6,

    output logic [2:0]src_max,  // Select source of max pool (0: MLIout, 1: MLOout, 2: EOAout, 3: SEOAout)
    output logic [7:0]sel_POA,  // Select POA (Processing Operation Array)
    output logic sel_adder      // Select adder for
);
    assign src_max      = slot6[11:9];
    assign sel_POA      = slot6[8:1];
    assign sel_adder    = slot6[0];
endmodule