`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/17/2024 09:27:54 PM
// Design Name: 
// Module Name: testcode
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module testcode();
    bit [15:0] OSP_read [0:63];
    wire [16 * 64 - 1:0] OSP_read_array;
    initial begin
        OSP_read[0] = 16'hABCD;
        OSP_read[2] = 16'h9876;
        OSP_read[3] = 16'hFEDC;
    end
    genvar i;
    generate
        for (i = 0; i < 64; i = i + 1) begin : mux_MLOM_array
            assign OSP_read_array[i*16 +: 16] = OSP_read[i];
        end
    endgenerate 
       
endmodule
