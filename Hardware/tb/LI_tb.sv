`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/07/2024 08:14:32 PM
// Design Name: 
// Module Name: LI_tb
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


module LI_tb;
parameter DATA_WIDTH = 16;
    parameter DECIMAL_BITS = 8;

    reg [DATA_WIDTH - 1:0] x;
    reg [DATA_WIDTH - 1:0] x1;
    reg [DATA_WIDTH - 1:0] y1;
    reg [DATA_WIDTH - 1:0] x2;
    reg [DATA_WIDTH - 1:0] y2;
    wire [DATA_WIDTH - 1:0] y;
    Linear_Inter #(
        .DATA_WIDTH(DATA_WIDTH),
        .DECIMAL_BITS(DECIMAL_BITS)
    ) uut (
        .x(x),
        .x1(x1),
        .y1(y1),
        .x2(x2),
        .y2(y2),
        .y(y)
    );
   

    initial begin
        repeat (10) begin
            #100
            x1 = $random; 
            y1 = $random;
            x2 = $random;
            y2 = $random; 
            x = $random;
        end
        #100
        $stop;
    end
endmodule
