`timescale 1ns/1ps
// Direct pipeline-boundary checks supplement the controller's ISA scoreboard.
module controller_alu_pipe_tb;
    reg clk=0, rst=1, wen=0;
    reg [31:0] a=0, b=0;
    reg [2:0] op=0;
    wire [31:0] result;
    reg [31:0] expected=0, held=0, random_state=32'h613508ab;
    reg [63:0] full_product;
    integer i, checks=0, holds=0, resets=0;
    MC_alu dut(.clk(clk),.rst(rst),.wen(wen),.operand_1(a),.operand_2(b),.alu_op(op),.result(result));
    always #5 clk=~clk;

    task sample;
        begin
            // Controls/data may change while wen=0; the registered result holds.
            if(wen) begin
                case(op)
                    0: expected=a+b;
                    1: expected=a-b;
                    2: begin full_product={32'd0,a}*{32'd0,b}; expected=full_product[31:0]; end
                    3: expected=a >> b; // Preserve unsigned shift semantics.
                    4: expected=a & b;
                    5: expected=a | b;
                    default: expected=0;
                endcase
            end else holds=holds+1;
            @(posedge clk); #1;
            if(result !== expected) $fatal(1,"ALU pipeline mismatch op=%0d a=%h b=%h got=%h expected=%h",op,a,b,result,expected);
            checks=checks+1; held=result;
            @(negedge clk); #1;
            if(result !== held) $fatal(1,"Arithmetic/result-select register changed on falling edge");
        end
    endtask

    task reset_between_edges;
        begin
            // Assert while the clock is low, with nonzero state and wen set.
            #1; rst=1; #1;
            if(result !== 0 || dut.multiply_stage !== 0 || dut.other_stage !== 0 ||
               dut.multiply_selected !== 0) $fatal(1,"ALU asynchronous reset retained stage state");
            expected=0; resets=resets+1;
            @(negedge clk); #1; rst=0; wen=0;
            sample();
        end
    endtask

    initial begin
        repeat(2) @(negedge clk);
        #1; rst=0;
        // Product overflow, high bit, zero, and consecutive operation changes.
        wen=1; op=2; a=32'hffffffff; b=32'hffffffff; sample();
        op=0; a=32'hffffffff; b=1; sample();
        op=2; a=32'h80000000; b=2; sample();
        op=1; a=0; b=1; sample();
        op=2; a=32'h80000000; b=1; sample();
        reset_between_edges();
        for(i=0;i<4096;i=i+1) begin
            random_state=random_state*1664525+1013904223; a=random_state;
            random_state=random_state*1664525+1013904223; b=random_state;
            op=i%6;
            if(op==3) b=i%66; // Include zero, 31, 32 and larger shifts.
            wen=(i%7)!=0;
            sample();
        end
        wen=1; op=0; a=32'h7fffffff; b=1; sample();
        reset_between_edges();
        wen=1; op=2; a=7; b=9; sample();
        wen=0; op=1; a=32'hdeadbeef; b=3;
        repeat(4) sample();
        $display("CONTROLLER_ALU_RESULT checks=%0d holds=%0d async_resets=%0d errors=0",checks,holds,resets);
        $display("TEST_PASS: registered multiply/non-MUL selection, latency, wrap, valid holds, rising-edge updates and asynchronous reset");
        $finish;
    end
    initial begin #100000; $fatal(1,"ALU pipeline test timeout"); end
endmodule
