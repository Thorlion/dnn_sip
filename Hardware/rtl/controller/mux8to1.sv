module mux8to1 #(
    parameter DATA_W = 32
)(
    input  logic [DATA_W-1:0] d0,
    input  logic [DATA_W-1:0] d1,
    input  logic [DATA_W-1:0] d2,
    input  logic [DATA_W-1:0] d3,
    input  logic [DATA_W-1:0] d4,
    input  logic [DATA_W-1:0] d5,
    input  logic [DATA_W-1:0] d6,
    input  logic [DATA_W-1:0] d7,

    input  logic [2:0] sel,

    output logic [DATA_W-1:0] dout
);
    always_comb begin
        case (sel)
            3'b000: dout = d0;
            3'b001: dout = d1;
            3'b010: dout = d2;    
            3'b011: dout = d3;
            3'b100: dout = d4;
            3'b101: dout = d5;
            3'b110: dout = d6;
            3'b111: dout = d7;
            default: dout = '0;
        endcase
    end
endmodule