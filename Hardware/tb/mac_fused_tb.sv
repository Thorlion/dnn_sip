`timescale 1ns/1ps
// Compare against the pre-fusion order: multiply, scale, then add modulo 16 bits.
// All selector encodings, sign/fraction/overflow boundaries and deterministic
// random operands are covered. The reference does not use the fused identity.
module mac_fused_tb;
    logic signed [1:0] mult_sel_1 = 0, acc_sel = 0;
    logic mult_sel_2 = 0;
    logic signed [15:0] local_input = 0, broadcast_input = 0, weight = 0;
    logic signed [15:0] memory_sum = 0, self_sum = 0, neighbor_sum = 0;
    wire signed [15:0] actual [0:3];
    integer decimal_bits [0:3];
    integer boundary [0:16];
    integer checks = 0;
    reg [31:0] random_state = 32'h5d1f1234;

    genvar g;
    generate for (g = 0; g < 4; g = g + 1) begin: configurations
        localparam integer FRACTION = (g == 0) ? 0 :
                                      (g == 1) ? 4 : (g == 2) ? 8 : 15;
        mac #(.DATA_W(16), .DECIMAL_BIT(FRACTION)) dut (
            .mult_sel_1(mult_sel_1), .mult_sel_2(mult_sel_2), .acc_sel(acc_sel),
            .MLIout(local_input), .MLIout_all(broadcast_input), .MLKout(weight),
            .MLOout(memory_sum), .EOAout(self_sum), .SEOAout(neighbor_sum),
            .acc_result(actual[g])
        );
    end endgenerate

    function automatic [15:0] original_result(input integer fraction);
        reg signed [15:0] a, b;
        reg signed [31:0] product;
        begin
            case (mult_sel_1)
                2'b01: a = local_input;
                2'b10: a = broadcast_input;
                default: a = 0;
            endcase
            b = mult_sel_2 ? weight : (16'b1 << fraction);
            product = a * b;
            product = product >> fraction;
            case (acc_sel)
                2'b00: original_result = product[15:0];
                2'b01: original_result = memory_sum + product[15:0];
                2'b10: original_result = self_sum + product[15:0];
                2'b11: original_result = neighbor_sum + product[15:0];
                default: original_result = 0;
            endcase
        end
    endfunction

    function automatic [15:0] random_word();
        begin
            random_state = random_state * 32'd1664525 + 32'd1013904223;
            random_word = random_state[31:16];
        end
    endfunction

    task check_all_selectors;
        integer s1, s2, sa, config_index;
        reg [15:0] expected;
        begin
            for (s1 = 0; s1 < 4; s1 = s1 + 1)
                for (s2 = 0; s2 < 2; s2 = s2 + 1)
                    for (sa = 0; sa < 4; sa = sa + 1) begin
                        mult_sel_1 = s1; mult_sel_2 = s2; acc_sel = sa;
                        #1;
                        for (config_index = 0; config_index < 4; config_index = config_index + 1) begin
                            expected = original_result(decimal_bits[config_index]);
                            if (actual[config_index] !== expected)
                                $fatal(1, "MAC mismatch fraction=%0d sel=%0d/%0d/%0d input=%h broadcast=%h weight=%h sums=%h/%h/%h actual=%h expected=%h",
                                    decimal_bits[config_index], s1, s2, sa,
                                    local_input, broadcast_input, weight,
                                    memory_sum, self_sum, neighbor_sum,
                                    actual[config_index], expected);
                            checks = checks + 1;
                        end
                    end
        end
    endtask

    integer i, j, k;
    initial begin
        decimal_bits[0] = 0; decimal_bits[1] = 4;
        decimal_bits[2] = 8; decimal_bits[3] = 15;
        boundary[0] = -32768; boundary[1] = -32767; boundary[2] = -30000;
        boundary[3] = -257; boundary[4] = -256; boundary[5] = -255;
        boundary[6] = -1; boundary[7] = 0; boundary[8] = 1;
        boundary[9] = 127; boundary[10] = 128; boundary[11] = 255;
        boundary[12] = 256; boundary[13] = 257; boundary[14] = 30000;
        boundary[15] = 32766; boundary[16] = 32767;
        // Exhaust all boundary input/weight/accumulator combinations. Rotate
        // the remaining inputs so the broadcast and feedback choices differ.
        for (i = 0; i < 17; i = i + 1)
            for (j = 0; j < 17; j = j + 1)
                for (k = 0; k < 17; k = k + 1) begin
                    local_input = boundary[i];
                    broadcast_input = boundary[(i + 5) % 17];
                    weight = boundary[j];
                    memory_sum = boundary[k];
                    self_sum = boundary[(k + 3) % 17];
                    neighbor_sum = boundary[(k + 9) % 17];
                    check_all_selectors();
                end
        for (i = 0; i < 8192; i = i + 1) begin
            local_input = random_word(); broadcast_input = random_word();
            weight = random_word(); memory_sum = random_word();
            self_sum = random_word(); neighbor_sum = random_word();
            check_all_selectors();
        end
        // Retain the old default behavior for unknown accumulator selectors.
        acc_sel = 2'bxx; #1;
        for (i = 0; i < 4; i = i + 1)
            if (actual[i] !== 16'b0) $fatal(1, "Unknown acc_sel default changed");
        $display("MAC_FUSED_RESULT checks=%0d configurations=4 random_vectors=8192 boundary_vectors=4913", checks);
        $display("TEST_PASS: fused MAC matches original multiplication/scaling/accumulation order");
        $finish;
    end
    initial begin #1000000; $fatal(1, "MAC fused test timeout"); end
endmodule
