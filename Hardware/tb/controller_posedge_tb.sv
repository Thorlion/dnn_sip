`timescale 1ns/1ps
// Public controller ports only, with read-only probes at issue/retire boundaries.
// Architectural reference executes accepted instructions in order, independently
// of the hardware forwarding implementation and physical pipeline stages.
module controller_posedge_tb;
    reg clk=0,rst=1,start=0,iw=0;
    reg [7:0] ia=0;
    reg [31:0] id=0;
    wire vsync,start_dnn,end_flag;
    reg dnn_done=1;
    wire [31:0] om_addr;
    wire om_ren,om_wen,ir,ob_ren,sc_we,bsp_we;
    wire [15:0] om_wdata,dnn_wdata;
    reg [15:0] om_rdata=0,dnn_rdata=0;
    wire [8:0] dnn_addr;
    wire [63:0] ib_we,ksp_we;
    wire [211:0] sc_data;
    reg [211:0] inst_rdata=0;
    wire [67:0] p0_cmd,p1_cmd;
    wire [15:0] p0_data,p1_data;
    wire [211:0] p1_inst;
    reg [67:0] p0_in=0;
    Controller #(.MCMEM_W(256),.IS_FIRST_COL(1)) dut(
        .clk(clk),.rst(rst),.start(start),.mcmem_wen(iw),
        .mcmem_wr_addr(ia),.mcmem_wr_data(id),.vsync_in(vsync),.hsync_in(1'b0),
        .dnn_done(dnn_done),.vsync_out(vsync),.start_DNN(start_dnn),.end_flag(end_flag),
        .command_P0_in(p0_in),.data_P0_in(16'hcafe),.command_P1_in(68'd0),
        .data_P1_in(16'd0),.inst_P1_in(212'd0),
        .command_P0_out(p0_cmd),.data_P0_out(p0_data),
        .command_P1_out(p1_cmd),.data_P1_out(p1_data),.inst_P1_out(p1_inst),
        .OM_addr(om_addr),.OM_ren(om_ren),.OM_wen(om_wen),.OM_wr_data(om_wdata),
        .OM_rd_data(om_rdata),.OM_inst_ren(ir),.OM_inst_rd(inst_rdata),
        .DNN_addr(dnn_addr),.IB_wen(ib_we),.KSP_wen(ksp_we),.BSP_wen(bsp_we),
        .DNN_wr_data(dnn_wdata),.OB_ren(ob_ren),.DNN_rd_data(dnn_rdata),
        .mem_inst_wen(sc_we),.DNN_inst_wr(sc_data),
        .done_transfer_prev(1'b0),.done_vtransfer_prev(1'b0));
    always #5 clk=~clk;

    reg [31:0] prog[0:255], ref_rf[0:31];
    reg [31:0] pipe_data[0:1];
    reg [4:0] pipe_rd[0:1];
    bit pipe_wen[0:1];
    reg [67:0] transfers[0:31];
    bit incoming[0:31];
    integer tail=0,head=0,ref_pc=0,issued=0,retired=0,cycles=0,launches=0;
    integer n=0,i,ref_init,op,rd,ra,rb,rt,imm,next_pc,core_ticks=0;
    integer branch_stalls=0,cbr_taken=0,cbr_not_taken=0;
    reg [31:0] ins,answer,random_state=32'h617e51;
    reg [67:0] req;
    reg [31:0] source_addr,dest_addr;
    reg [63:0] lane_mask;
    bit commit,retire_we;
    reg [4:0] retire_rd;
    reg [31:0] retire_data,held_pc,held_alu;
    reg [7:0] stalled_pc;
    bit expected_branch_wait,branch_stalled;

    function [31:0] enc(input integer opc,input integer d,input integer a,
                        input integer b,input integer t);
        enc={opc[5:0],d[4:0],a[4:0],b[4:0],t[4:0],6'd0};
    endfunction
    function [31:0] enc_i(input integer opc,input integer d,input integer a,input integer k);
        enc_i={opc[5:0],d[4:0],a[4:0],k[15:0]};
    endfunction
    function [15:0] word_at(input [31:0] a);
        word_at=a[15:0]^16'h52a7;
    endfunction
    function [211:0] instruction_at(input [31:0] a);
        instruction_at={20'h517a3,{6{a}}};
    endfunction
    task append(input [31:0] x);
        begin prog[n]=x; n=n+1; end
    endtask

    always @(posedge clk) begin
        cycles=cycles+1;
        if(cycles>4000) $fatal(1,"Controller test timeout ref_pc=%0d head=%0d tail=%0d",ref_pc,head,tail);
        if(rst) begin
            for(ref_init=0;ref_init<32;ref_init=ref_init+1) ref_rf[ref_init]=0;
            pipe_wen[0]=0; pipe_wen[1]=0; ref_pc=0;
        end else begin
            // The independent expected EX packet was created only when the
            // reference accepted an instruction at the preceding edge.
            expected_branch_wait=(prog[dut.PC][31:26]==6'd20) &&
                                 pipe_wen[0] && (pipe_rd[0]!=0) &&
                                 (pipe_rd[0]==prog[dut.PC][20:16]);
            if(dut.branch_wait !== expected_branch_wait)
                $fatal(1,"CBR dependency-stall mismatch PC=%0d",dut.PC);
            branch_stalled=dut.branch_wait;
            stalled_pc=dut.PC;
            if(branch_stalled) begin
                branch_stalls=branch_stalls+1;
                if(dut.issue_valid || dut.mode_opcode!==6'b111111)
                    $fatal(1,"Dependent CBR issued or reached mode control during stall");
            end
            // Check the actual pending WB packet before the rising-edge write.
            retire_we=pipe_wen[1]; retire_rd=pipe_rd[1]; retire_data=pipe_data[1];
            if(dut.rf_wen_reg2 !== retire_we)
                $fatal(1,"WB validity mismatch");
            if(retire_we && (dut.rd_reg2 !== retire_rd || dut.alu_result_reg !== retire_data))
                $fatal(1,"WB data/tag mismatch rd=%0d got=%h expected=%h",retire_rd,dut.alu_result_reg,retire_data);
            if(retire_we) retired=retired+1;
            pipe_wen[1]=pipe_wen[0]; pipe_rd[1]=pipe_rd[0]; pipe_data[1]=pipe_data[0];
            pipe_wen[0]=0;
            if(p0_in!=0 && !dut.memory_busy) begin
                // Incoming request accepts on the same edge as the first
                // local memory instruction enters decode. It must finish
                // first without discarding the pending local command.
                transfers[tail]=p0_in; incoming[tail]=1; tail=tail+1;
            end
            if(dut.issue_valid) begin
                if(dut.PC !== ref_pc[7:0]) $fatal(1,"PC mismatch got=%0d expected=%0d",dut.PC,ref_pc);
                ins=prog[ref_pc]; op=ins[31:26]; rd=ins[25:21]; ra=ins[20:16];
                rb=ins[15:11]; rt=ins[10:6]; imm=ins[15:0];
                next_pc=ref_pc+1; answer=0;
                case(op)
                    0: answer=ref_rf[ra]+ref_rf[rb];
                    1: answer=ref_rf[ra]-ref_rf[rb];
                    2: answer=ref_rf[ra]*ref_rf[rb];
                    3: answer=ref_rf[ra]&ref_rf[rb];
                    4: answer=ref_rf[ra]|ref_rf[rb];
                    5: answer=ref_rf[ra]+1;
                    6: answer=ref_rf[ra]-1;
                    7: answer=ref_rf[ra] >> imm; // Preserve current unsigned-shift RTL semantics.
                    8: answer=ref_rf[ra]+imm;
                    9: answer=ref_rf[ra]-imm;
                    10: answer=ref_rf[ra]*imm;
                    11: answer=ref_rf[ra]&imm;
                    12: answer=ref_rf[ra]|imm;
                    13: answer=ref_rf[ra];
                    14: answer=imm;
                    15: answer=imm << 16;
                    19: next_pc=imm;
                    20: begin
                        if(dut.branch_ra_data !== ref_rf[ra])
                            $fatal(1,"CBR WB/RF operand mismatch PC=%0d",dut.PC);
                        if(ref_rf[ra]!=0) begin
                            next_pc=imm; cbr_taken=cbr_taken+1;
                        end else cbr_not_taken=cbr_not_taken+1;
                    end
                endcase
                if(op<16) begin
                    pipe_wen[0]=1; pipe_rd[0]=rd; pipe_data[0]=answer;
                    if(rd!=0) ref_rf[rd]=answer;
                end
                if(op>=32 && op<=39) begin
                    transfers[tail]={4'(op-31),(ref_rf[rd]+ref_rf[ra]),(ref_rf[rb]+ref_rf[rt])};
                    incoming[tail]=0;
                    tail=tail+1;
                end
                ref_pc=next_pc; issued=issued+1;
            end
            if(om_ren) om_rdata <= word_at(om_addr);
            if(ir) inst_rdata <= instruction_at(om_addr);
            if(ob_ren) dnn_rdata <= word_at({23'd0,dnn_addr});
            commit=(|ib_we)||(|ksp_we)||bsp_we||sc_we||om_wen||(p0_cmd!=0)||(p1_cmd!=0);
            if(om_ren || ir || ob_ren || commit) begin
                if(head>=tail) $fatal(1,"Unexpected memory operation");
                req=transfers[head]; source_addr=req[63:32]; dest_addr=req[31:0];
                if((om_ren||ir) && om_addr !== source_addr) $fatal(1,"Memory source-address forwarding failed");
                if(ob_ren && dnn_addr !== source_addr[8:0]) $fatal(1,"OB read address mismatch");
                if(commit) begin
                    if(incoming[head]) begin
                        if(!om_wen || om_addr !== dest_addr || om_wdata !== 16'hcafe)
                            $fatal(1,"Incoming P0/local command arbitration mismatch");
                    end else if(req[67:64]==4) begin
                        if(!om_wen || om_addr !== dest_addr || om_wdata !== word_at(source_addr))
                            $fatal(1,"OB-to-OM transfer mismatch");
                    end else if(req[67:64]==2 || req[67:64]==7) begin
                        if(p0_cmd !== req || p0_data !== word_at(source_addr)) $fatal(1,"P0 transfer mismatch");
                    end else if(req[67:64]==3 || req[67:64]==8) begin
                        if(p1_cmd !== req || p1_data !== word_at(source_addr)) $fatal(1,"P1 transfer mismatch");
                    end else begin
                        if(dnn_addr !== dest_addr[8:0]) $fatal(1,"DNN destination-address forwarding failed");
                        lane_mask=64'b1 << dest_addr[15:9];
                        case(dest_addr[18:16])
                            1: if(ib_we !== lane_mask || dnn_wdata !== word_at(source_addr)) $fatal(1,"IB transfer mismatch");
                            2: if(ksp_we !== lane_mask || dnn_wdata !== word_at(source_addr)) $fatal(1,"KSP transfer mismatch");
                            3: if(!bsp_we || dnn_wdata !== word_at(source_addr)) $fatal(1,"BSP transfer mismatch");
                            5: if(!sc_we || sc_data !== instruction_at(source_addr)) $fatal(1,"SC transfer mismatch");
                            default: $fatal(1,"Invalid test descriptor");
                        endcase
                        if(req[67:64]==6 && (p1_cmd !== req || p1_inst !== instruction_at(source_addr)))
                            $fatal(1,"Broadcast instruction/data packet mismatch");
                    end
                    head=head+1;
                end
            end
            if(start_dnn) begin
                if(core_ticks!=0 || dut.memory_inflight) $fatal(1,"DNN launched before drain or launched twice");
                launches=launches+1; dnn_done<=0; core_ticks=4;
            end else if(core_ticks>0) begin
                core_ticks=core_ticks-1;
                if(core_ticks==0) dnn_done<=1;
            end
            #1;
            if(branch_stalled) begin
                if(dut.PC !== stalled_pc || dut.instruction[31:26]!==6'd20 ||
                   dut.rf_wen_reg1!==0 || dut.type_access_reg!==0)
                    $fatal(1,"Branch bubble advanced PC or issued a side effect");
                if(dut.branch_wait || !dut.rf_wen_reg2 ||
                   dut.rd_reg2 !== prog[stalled_pc][20:16] ||
                   dut.alu_result_reg !== ref_rf[prog[stalled_pc][20:16]])
                    $fatal(1,"Branch stall froze its producer or failed to drain into WB");
            end
            if(retire_we && retire_rd!=0 && dut.rf.mem[retire_rd] !== retire_data)
                $fatal(1,"RF rising-edge commit mismatch");
            if(dut.rf.mem[0] !== 0) $fatal(1,"R0 changed");
        end
        #1; held_pc=dut.PC; held_alu=dut.alu_result_reg;
    end
    always @(negedge clk) if(!rst) begin
        if(dut.PC !== held_pc || dut.alu_result_reg !== held_alu)
            $fatal(1,"Controller register changed at falling edge");
    end

    initial begin
        for(i=0;i<256;i=i+1) prog[i]=enc(23,0,0,0,0);
        append(enc_i(14,1,0,5)); append(enc_i(8,1,1,7)); append(enc(0,2,1,1,0));
        append(enc_i(15,3,0,1)); append(0); append(enc(13,4,3,0,0));
        append(enc(0,5,4,2,0)); append(enc(1,6,5,4,0)); append(enc(2,7,6,1,0));
        append(enc_i(14,8,0,3)); append(enc(6,8,8,0,0)); append(enc_i(20,0,8,10));
        append(enc_i(19,0,0,14)); append(enc_i(14,31,0,16'hdead));
        for(i=0;i<96;i=i+1) begin
            random_state=random_state*1664525+1013904223;
            op=i%16; rd=1+(i%12); ra=1+((i+11)%12); rb=1+((i+10)%12);
            if(op<7 || op==13) append(enc(op,rd,ra,rb,0));
            else append(enc_i(op,rd,ra,(op==7)?i%32:random_state[15:0]));
        end
        // EX must win over an older WB writer to the same register, including
        // a newest zero result. Poison instructions expose wrong-path issue.
        append(enc_i(14,21,0,1)); append(enc_i(14,21,0,0));
        append(enc_i(20,0,21,n+2)); append(enc_i(14,22,0,123));
        append(enc_i(14,21,0,0)); append(enc_i(14,21,0,9));
        append(enc_i(20,0,21,n+2)); append(enc_i(14,31,0,16'hdead));
        // The low 32-bit multiply result can be zero for nonzero operands.
        append(enc_i(15,21,0,1)); append(enc(2,21,21,21,0));
        append(enc_i(20,0,21,n+2)); append(enc_i(14,22,0,124));
        append(enc_i(15,21,0,16'h8000)); append(enc_i(10,21,21,1));
        append(enc_i(20,0,21,n+2)); append(enc_i(14,31,0,16'hdead));
        // R0 is not a producer; unrelated EX writes must not stall a CBR.
        append(enc_i(14,0,0,5)); append(enc_i(20,0,0,n+2));
        append(enc_i(14,22,0,125));
        append(enc_i(14,21,0,0)); append(enc_i(14,23,0,7));
        append(enc_i(20,0,21,n+2)); append(enc_i(14,22,0,126));
        // WB forwarding without an EX dependency, plus unconditional BR.
        append(enc_i(14,21,0,1)); append(enc_i(14,23,0,8));
        append(enc_i(20,0,21,n+2)); append(enc_i(14,31,0,16'hdead));
        append(enc_i(14,23,0,9)); append(enc_i(19,0,23,n+2));
        append(enc_i(14,31,0,16'hdead));
        // A held CBR issues once; the next CBR does not inherit its stall.
        append(enc_i(14,21,0,0)); append(enc_i(20,0,21,n+2));
        append(enc_i(20,0,21,n+2)); append(enc_i(14,22,0,127));
        append(enc_i(15,10,0,1)); append(enc_i(14,11,0,17));
        append(enc_i(15,12,0,1)); append(enc_i(14,13,0,(63<<9)+5));
        append(enc(32,10,11,12,13)); append(enc(32,10,11,12,13));
        append(enc_i(15,12,0,2)); append(enc(32,10,11,12,13));
        append(enc_i(15,12,0,3)); append(enc(32,10,11,12,13));
        append(enc_i(14,10,0,0)); append(enc_i(14,11,0,7));
        append(enc_i(15,12,0,5)); append(enc(32,10,11,12,13));
        append(enc(37,10,11,12,13)); // Instruction broadcast and local SC write.
        append(enc_i(15,10,0,1)); append(enc_i(14,11,0,19));
        append(enc_i(14,12,0,0)); append(enc_i(14,13,0,9));
        append(enc(33,10,11,12,13)); append(enc(34,10,11,12,13));
        append(enc(38,10,11,12,13)); append(enc(39,10,11,12,13));
        append(enc_i(14,10,0,3)); append(enc_i(14,11,0,0));
        append(enc_i(15,12,0,1)); append(enc_i(14,13,0,27));
        append(enc(35,10,11,12,13));
        append(enc(22,0,0,0,0)); append(enc(21,0,0,0,0));
        append(enc_i(14,20,0,93)); // Must wait for DNN completion, not execute while held.
        append(enc(22,0,0,0,0)); append(enc(21,0,0,0,0));
        append(enc_i(8,20,20,7)); append(enc(23,0,0,0,0));
        for(i=0;i<n;i=i+1) begin
            @(negedge clk); #1; iw=1; ia=i; id=prog[i];
        end
        @(negedge clk); #1; iw=0; rst=0;
        repeat(4) @(negedge clk);
        if(issued!=0) $fatal(1,"Controller executed before start");
        #1; start=1; @(negedge clk); #1; start=0;
        wait(end_flag); #2;
        if(head!=tail || tail!=12 || launches!=2 || dut.rf.mem[20] !== 100 ||
           dut.rf.mem[31] !== 0 || dut.rf.mem[22] !== 127)
            $fatal(1,"Counts/final state mismatch head=%0d tail=%0d launches=%0d r20=%h",head,tail,launches,dut.rf.mem[20]);
        repeat(8) @(negedge clk);
        if(dut.issue_valid || dut.start_flag || dut.PC!=0) $fatal(1,"END did not stop fetch");
        // Restart without resetting the RF or instruction memory. The reference
        // retains architectural RF state, just as the physical controller does.
        ref_pc=0; #1; start=1; @(negedge clk); #1; start=0;
        wait(end_flag); #2;
        if(head!=tail || tail!=23 || launches!=4 || dut.rf.mem[20] !== 100 ||
           dut.rf.mem[31] !== 0 || dut.rf.mem[22] !== 127)
            $fatal(1,"Restart state/count mismatch head=%0d tail=%0d launches=%0d",head,tail,launches);
        repeat(8) @(negedge clk);
        if(dut.issue_valid || dut.start_flag || dut.PC!=0) $fatal(1,"Restart END did not stop fetch");
        if(branch_stalls!=16 || cbr_taken==0 || cbr_not_taken==0)
            $fatal(1,"Branch coverage/stall count mismatch stalls=%0d taken=%0d not_taken=%0d",branch_stalls,cbr_taken,cbr_not_taken);
        $display("CONTROLLER_RESULT issued=%0d retired=%0d transfers=%0d launches=%0d branch_stalls=%0d cbr_taken=%0d cbr_not_taken=%0d errors=0",issued,retired,head,launches,branch_stalls,cbr_taken,cbr_not_taken);
        $display("TEST_PASS: rising-edge controller, EX/WB ALU forwarding, WB-only branches with one-cycle dependency bubbles, memory packets, backpressure, start/drain/END and restart");
        $finish;
    end
    initial begin
        wait(!rst && dut.issue_valid && dut.instruction[31:26]==6'd32);
        @(negedge clk); #1; p0_in={4'd2,32'd0,32'h0001abcd};
        @(negedge clk); #1; p0_in=0;
    end
endmodule
