module DecoderCONV (
    input  logic [5:0] slot4,

    output logic [1:0] src_mult1,       // Select first operand for MAC (MLIout, MLIout_all, MLOout)
    output logic src_mult2,             // Select second operand for MAC (MLKout)
    output logic [1:0] src_acc,         // Select between MLOM (Memory Load OSP Muxed) and MLFC (Memory Load Fully Connected)
    output logic src_add_bias           // 0: MLOM_read 1: MLFC_read
);

    assign src_mult1    = slot4[5:4];
    assign src_mult2    = slot4[3];
    assign src_acc      = slot4[2:1];
    assign src_add_bias = slot4[0];
endmodule