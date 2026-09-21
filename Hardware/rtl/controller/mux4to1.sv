module mux4to1 #(
    parameter DATA_W = 32
)(
    input  logic [DATA_W-1:0] d0,
    input  logic [DATA_W-1:0] d1,
    input  logic [DATA_W-1:0] d2,
    input  logic [DATA_W-1:0] d3,

    input  logic [1:0] sel,

    output logic [DATA_W-1:0] dout    
);
    always_comb begin
        case(sel)
            2'b00: dout = d0;
            2'b01: dout = d1;
            2'b10: dout = d2;
            2'b11: dout = d3;
            default: dout = '0;
        endcase
    end
endmodule