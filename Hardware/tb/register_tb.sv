`timescale 1ns / 1ps

module register_tb;

// Parameter
parameter DATA_WIDTH = 16;

// Inputs
reg clk;
reg rst;
reg wen;
reg [DATA_WIDTH-1:0] data_in;

// Outputs
wire [DATA_WIDTH-1:0] data_out;

// Instantiate the Unit Under Test (UUT)
register #(.DATA_WIDTH(DATA_WIDTH)) uut (
    .clk(clk),
    .rst(rst),
    .wen(wen),
    .data_in(data_in),
    .data_out(data_out)
);

// Clock generation
initial begin
    clk = 0;
    forever #5 clk = ~clk; // 4ns clock period - 250MHz
end

// Test cases
initial begin
    // Initialize signals
    rst = 0;
    wen = 0;
    data_in = 0;

    // Display format
    $monitor("Time = %0t | rst = %b | wen = %b | data_in = %h | data_out = %h", 
              $time, rst, wen, data_in, data_out);

    // Test Case 1: Reset
    #10 rst = 1; // Assert reset
    #200 rst = 0; // Deassert reset

    // Test Case 2: Write data with wen = 1
    #10 wen = 1; data_in = 16'hA5A5; // Write A5A5
    #10 wen = 1; data_in = 16'hABCD; // Write 5A5A

    // Test Case 3: Hold data with wen = 0
//    #10 wen = 0; data_in = 16'hFFFF; // Data_out should not change

    // Test Case 4: Reset while holding data
//    #10 rst = 1; // Assert reset
//    #10 rst = 0; wen = 1; data_in = 16'h1234; // Write 1234

    // Test Case 5: Write again after reset
    #10 wen = 1; data_in = 16'hFFFF; // Write FFFF

    // Test Case 6: Test edge cases
    #10 wen = 1; data_in = 16'h0000; // Write minimum value
    #10 wen = 1; data_in = 16'hFFFF; // Write maximum value
    #10 wen = 1; data_in = 16'h1234; // Write maximum value
    #10 wen = 1; data_in = 16'hCD12; // Write maximum value
    #10 wen = 1; data_in = 16'h9838; // Write maximum value
    #10 wen = 1; data_in = 16'h1010; // Write maximum value
    #10 wen = 1; data_in = 16'h3030; // Write maximum value
    #10 wen = 1; data_in = 16'h09CD; // Write maximum value
    #10 wen = 1; data_in = 16'hEFF9; // Write maximum value
    #10 wen = 1; data_in = 16'hE189; // Write maximum value
    #10 wen = 1; data_in = 16'h92F9; // Write maximum value
    #10 wen = 1; data_in = 16'h0901; // Write maximum value
    #10 wen = 1; data_in = 16'h0703; // Write maximum value

    // End simulation
    #20 $finish;
end

endmodule
