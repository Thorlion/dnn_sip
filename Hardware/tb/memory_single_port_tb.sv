`timescale 1ns / 1ps

module tb_memory_single_port;
    // Parameters
    parameter SIZE = 1024;
    parameter DATA_WIDTH = 16;

    // Inputs
    reg clk;
    reg rst;
    reg wen;
    reg ren;
    reg [$clog2(SIZE)-1:0] addr_w;
    reg [$clog2(SIZE)-1:0] addr_r;
    reg [DATA_WIDTH-1:0] din;

    // Outputs
    wire [DATA_WIDTH-1:0] dout;

    // Instantiate the Unit Under Test (UUT)
    memory_single_port #(
        .SIZE(SIZE),
        .DATA_WIDTH(DATA_WIDTH)
    ) uut (
        .clk(clk),
        .rst(rst),
        .wen(wen),
        .ren(ren),
        .addr_w(addr_w),
        .addr_r(addr_r),
        .din(din),
        .dout(dout)
    );

    // Clock generation with 4ns period
    initial clk = 0;
    always #2 clk = ~clk; // Toggle clk every 2ns for a 4ns period

    // Testbench sequence
    initial begin
        integer i;
        reg [DATA_WIDTH-1:0] expected_data;
        
        // Initialize inputs
        wen = 0;
        rst = 1;
        ren = 0;
        addr_w = 0;
        addr_r = 0;
        din = 0;

        $display("Starting Testbench...");
        #120
        rst = 0;
        // Test Case 1-10: Write and Read to specific addresses
        for (i = 0; i < 10; i = i + 1) begin
            // Write to address `i`
            wen = 1;
            addr_w = i;
            din = i * 16'h1110 + 16'h10AB; // Some test data
            #4; // Wait for one clock cycle
            wen = 0;

            // Read back from the same address
            ren = 1;
            addr_r = i;
            expected_data = din;
            #4; // Wait for one clock cycle
            if (dout == expected_data) begin
                $display("PASS: Addr %h, Data %h", addr_r, dout);
            end else begin
                $display("FAIL: Addr %h, Expected %h, Got %h", addr_r, expected_data, dout);
            end
            ren = 0;
        end

        // Test Case 11: Write to the lowest address (0)
        wen = 1;
        addr_w = 0;
        din = 16'hABCD;
        #4;
        wen = 0;

        // Test Case 12: Read from the lowest address
        ren = 1;
        addr_r = 0;
        expected_data = 16'hABCD;
        #4;
        if (dout == expected_data) begin
            $display("PASS: Lowest Address, Data %h", dout);
        end else begin
            $display("FAIL: Lowest Address, Expected %h, Got %h", expected_data, dout);
        end
        ren = 0;

        // Test Case 13: Write to the highest address (255)
        wen = 1;
        addr_w = 255;
        din = 16'hBEEF;
        #4;
        wen = 0;

        // Test Case 14: Read from the highest address
        ren = 1;
        addr_r = 255;
        expected_data = 16'hBEEF;
        #4;
        if (dout == expected_data) begin
            $display("PASS: Highest Address, Data %h", dout);
        end else begin
            $display("FAIL: Highest Address, Expected %h, Got %h", expected_data, dout);
        end
        ren = 0;

        // Test Case 15-20: Edge cases and random writes/reads
        for (i = 0; i < 6; i = i + 1) begin
            // Randomized write
            addr_w = $random % SIZE;
            din = $random;
            wen = 1;
            #4;
            wen = 0;

            // Read back from the same address
            addr_r = addr_w;
            expected_data = din;
            ren = 1;
            #4;
            if (dout == expected_data) begin
                $display("PASS: Random Addr %h, Data %h", addr_r, dout);
            end else begin
                $display("FAIL: Random Addr %h, Expected %h, Got %h", addr_r, expected_data, dout);
            end
            ren = 0;
        end

        $display("Testbench complete.");
        $finish;
    end
endmodule
