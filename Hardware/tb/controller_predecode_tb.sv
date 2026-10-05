`timescale 1ns/1ps
// Exercise every opcode through the real upload/read ports. Also verify the
// instruction and its metadata observe the same read-first collision behavior.
module controller_predecode_tb;
    reg clk=0,rst=1,start=0,wen=0;
    reg [6:0] wr_addr=0;
    reg [31:0] wr_data=0;
    wire ending;
    Controller #(.MCMEM_W(128)) dut(
        .clk(clk),.rst(rst),.start(start),.mcmem_wen(wen),
        .mcmem_wr_addr(wr_addr),.mcmem_wr_data(wr_data),
        .vsync_in(1'b1),.hsync_in(1'b0),.dnn_done(1'b1),.end_flag(ending),
        .command_P0_in(68'd0),.data_P0_in(16'd0),.command_P1_in(68'd0),
        .data_P1_in(16'd0),.inst_P1_in(212'd0),.OM_rd_data(16'd0),
        .OM_inst_rd(212'd0),.DNN_rd_data(16'd0),
        .done_transfer_prev(1'b0),.done_vtransfer_prev(1'b0)
    );
    always #5 clk=~clk;
    reg [63:0] seen=0;
    reg [31:0] held_instruction;
    reg [3:0] held_meta;
    integer i,checks=0,issues=0,collisions=0;
    function [3:0] ref_meta(input [31:0] word);
        reg [5:0] op;
        reg mem_op;
        begin
            op=word[31:26]; mem_op=(op>=32 && op<=39);
            ref_meta={(op==20),mem_op,(op<=4 || mem_op),(op<=13 || mem_op)};
        end
    endfunction
    task write_word(input integer addr,input [31:0] word);
        begin @(negedge clk); #1; wen=1; wr_addr=addr; wr_data=word; end
    endtask
    always @(posedge clk) begin
        if(!rst && dut.issue_valid) begin
            seen[dut.instruction[31:26]]=1'b1;
            issues=issues+1;
        end
        #1;
        if(dut.instruction_valid) begin
            if(dut.instruction_meta !== ref_meta(dut.instruction))
                $fatal(1,"Opcode %0d stored metadata differs from ISA source rules",dut.instruction[31:26]);
            if(dut.cbr_signal !== dut.decoded_cbr ||
               dut.instruction_meta[2:0] !== dut.decoded_operand_use)
                $fatal(1,"Stored metadata differs from live decoder");
            checks=checks+1;
        end
        held_instruction=dut.instruction; held_meta=dut.instruction_meta;
    end
    always @(negedge clk) begin
        if(dut.instruction !== held_instruction || dut.instruction_meta !== held_meta)
            $fatal(1,"Instruction or metadata updated outside the rising edge");
    end
    initial begin
        // R0 destinations prevent incidental ALU results from affecting flow.
        // BR goes to the next word; CBR reads R0 and falls through. The mode
        // FSM's existing VSYNC -> SDC protocol is completed by words 64/65.
        for(i=0;i<64;i=i+1)
            write_word(i,(i==19)?{6'd19,10'd0,16'd20}:{i[5:0],26'd0});
        write_word(64,{6'd21,26'd0});
        write_word(65,{6'd23,26'd0});
        write_word(66,{6'd14,5'd31,5'd0,16'hdead});
        @(negedge clk); #1; wen=0; rst=0; start=1;
        @(negedge clk); #1; start=0;
        wait(ending); #2;
        if(seen !== 64'hffffffffffffffff || dut.rf.mem[31] !== 0)
            $fatal(1,"Opcode coverage or post-END suppression failed seen=%h",seen);
        repeat(4) @(negedge clk); #1;

        // Bootstrap reads old word zero while rewriting it to MOVLO. All four
        // byte/metadata banks must observe old ADD, not mixed old/new pieces.
        wen=1; wr_addr=0; wr_data={6'd14,26'd0}; start=1;
        @(posedge clk); #2;
        if(dut.instruction !== 32'd0 || dut.instruction_meta !== 4'b0011 || dut.PC !== 0)
            $fatal(1,"Banked bootstrap read/write collision is not read-first");
        collisions=collisions+1; rst=1; wen=0; start=0;
        #1;
        if(dut.rf_pending !== 0 || dut.ex1_dest_mask !== 0 || dut.instruction_valid !== 0)
            $fatal(1,"Scoreboard reset failed after collision");
        repeat(2) @(negedge clk); #1; rst=0; start=1;
        @(posedge clk); #2;
        if(dut.instruction !== {6'd14,26'd0} || dut.instruction_meta !== 4'd0)
            $fatal(1,"Rewritten word zero or metadata not visible on restart");
        collisions=collisions+1; rst=1; start=0;
        $display("CONTROLLER_PREDECODE_RESULT opcodes=64 checks=%0d issues=%0d read_first_restart_checks=%0d errors=0",checks,issues,collisions);
        $display("TEST_PASS: all opcode metadata, synchronized banks, read-first upload collision, restart and scoreboard reset");
        $finish;
    end
    initial begin #20000; $fatal(1,"Predecode test timeout"); end
endmodule
