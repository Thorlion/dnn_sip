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
    reg [31:0] pipe_data[0:2];
    reg [4:0] pipe_rd[0:2];
    bit pipe_wen[0:2];
    reg [67:0] transfers[0:31];
    bit incoming[0:31];
    integer tail=0,head=0,ref_pc=0,issued=0,retired=0,cycles=0,launches=0;
    integer n=0,i,ref_init,op,rd,ra,rb,rt,imm,next_pc,core_ticks=0;
    integer branch_stalls=0,cbr_taken=0,cbr_not_taken=0;
    integer data_stalls=0,raw_ra=0,raw_rb=0,raw_rd=0,raw_rt=0;
    integer ignored_rb=0,ignored_rd=0,ignored_ra=0,r0_exclusions=0,dual_raw=0;
    integer stage_index;
    integer flag_index;
    integer predicate_checks=0;
    integer mode_accept_checks=0,accepted_sdc=0,accepted_vsync=0,accepted_end=0;
    integer mode_field_matches=0,mode_memory_waits=0,mode_end_drains=0;
    reg [31:0] ins,answer,random_state=32'h617e51;
    reg [67:0] req;
    reg [31:0] source_addr,dest_addr;
    reg [63:0] lane_mask;
    bit commit,retire_we;
    reg [4:0] retire_rd;
    reg [31:0] retire_data,held_pc,held_alu;
    reg [7:0] stalled_pc;
    bit expected_branch_wait,branch_stalled;
    bit expected_data_wait,data_stalled;
    reg [3:0] used_sources,raw_sources;
    reg [31:0] decode_ins,stalled_ins;

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
    // Independent ISA source mask, not copied from the DUT's selector logic.
    // Bits 0..3 represent RA, RB, RD, RTEMP; CBR is checked separately.
    function [3:0] source_mask(input [31:0] x);
        begin
            if(x[31:26]<=4) source_mask=4'b0011;
            else if(x[31:26]<=13) source_mask=4'b0001;
            else if(x[31:26]>=32 && x[31:26]<=39) source_mask=4'b1111;
            else source_mask=0;
        end
    endfunction
    task append(input [31:0] x);
        begin
            if(n>=256) $fatal(1,"Test program exceeds instruction memory");
            prog[n]=x; n=n+1;
        end
    endtask

    always @(posedge clk) begin
        cycles=cycles+1;
        if(cycles>4000) $fatal(1,"Controller test timeout ref_pc=%0d head=%0d tail=%0d",ref_pc,head,tail);
        if(rst) begin
            for(ref_init=0;ref_init<32;ref_init=ref_init+1) ref_rf[ref_init]=0;
            pipe_wen[0]=0; pipe_wen[1]=0; pipe_wen[2]=0; ref_pc=0;
        end else begin
            // Each predicate must mirror the data at the same pipeline edge,
            // including bubbles, overwrites and ignored R0 destinations.
            if(dut.wb_nonzero !== (dut.alu_result_reg != 0))
                $fatal(1,"WB predicate/result alignment mismatch");
            for(flag_index=0;flag_index<32;flag_index=flag_index+1)
                if(dut.rf_nonzero[flag_index] !== (dut.rf.mem[flag_index] != 0))
                    $fatal(1,"RF nonzero predicate mismatch R%0d",flag_index);
            // Independent producer packets establish both scoreboard stages.
            // Include simultaneous same-register writers, R0 and drain bubbles.
            for(flag_index=0;flag_index<32;flag_index=flag_index+1) begin
                if(dut.wb_dest_mask[flag_index] !==
                   (pipe_wen[2] && pipe_rd[2]!=0 && pipe_rd[2]==flag_index))
                    $fatal(1,"WB one-hot destination mismatch R%0d",flag_index);
                if(dut.visible_nonzero[flag_index] !==
                   ((pipe_wen[2] && pipe_rd[2]!=0 && pipe_rd[2]==flag_index) ?
                    dut.wb_nonzero : dut.rf_nonzero[flag_index]))
                    $fatal(1,"Visible branch predicate mismatch R%0d",flag_index);
                if(dut.ex1_dest_mask[flag_index] !==
                   (pipe_wen[0] && pipe_rd[0]!=0 && pipe_rd[0]==flag_index))
                    $fatal(1,"EX1 one-hot destination mismatch R%0d",flag_index);
                if(dut.rf_pending[flag_index] !==
                   ((pipe_wen[0] && pipe_rd[0]!=0 && pipe_rd[0]==flag_index) ||
                    (pipe_wen[1] && pipe_rd[1]!=0 && pipe_rd[1]==flag_index)))
                    $fatal(1,"Pending scoreboard mismatch R%0d",flag_index);
            end
            predicate_checks=predicate_checks+1;
            // The direct events must equal the former masked-opcode decoder
            // every cycle, including invalid words, holds, memory waits and
            // END draining. Unused encoded fields must never create a RAW.
            if({dut.single_mode.accept_end,dut.single_mode.accept_vsync,
                dut.single_mode.accept_sdc} !==
               {(dut.mode_opcode==6'd23),(dut.mode_opcode==6'd22),
                (dut.mode_opcode==6'd21)})
                $fatal(1,"Direct mode acceptance differs from legacy issue gating");
            mode_accept_checks=mode_accept_checks+1;
            if(dut.single_mode.accept_sdc) accepted_sdc=accepted_sdc+1;
            if(dut.single_mode.accept_vsync) accepted_vsync=accepted_vsync+1;
            if(dut.single_mode.accept_end) accepted_end=accepted_end+1;
            if(dut.instruction_valid && dut.start_flag && !end_flag &&
               dut.instruction[31:26]>=6'd21 && dut.instruction[31:26]<=6'd23) begin
                if(dut.data_wait || dut.branch_wait)
                    $fatal(1,"Operand-free mode instruction has a register dependency");
                if((dut.rf_wen_reg1 && dut.rd_reg1!=0 && dut.rd_reg1==dut.rtemp) ||
                   (dut.rf_wen_mid && dut.rd_mid!=0 && dut.rd_mid==dut.rtemp))
                    mode_field_matches=mode_field_matches+1;
                if(dut.fetch_memory_wait) mode_memory_waits=mode_memory_waits+1;
                if(dut.end_drain) mode_end_drains=mode_end_drains+1;
            end
            // Independent EX1/EX2 packets come from accepted instructions,
            // not the DUT's operand muxes or physical pipeline registers.
            expected_branch_wait=(prog[dut.PC][31:26]==6'd20) &&
                                 ((pipe_wen[0] && pipe_rd[0]!=0 &&
                                   pipe_rd[0]==prog[dut.PC][20:16]) ||
                                  (pipe_wen[1] && pipe_rd[1]!=0 &&
                                   pipe_rd[1]==prog[dut.PC][20:16]));
            // END may prefetch an unused/uninitialized fall-through word;
            // end_flag suppresses issue immediately and invalidates it next edge.
            if(dut.instruction_valid && !end_flag && dut.instruction !== prog[dut.PC])
                $fatal(1,"Synchronous instruction/PC misalignment PC=%0d",dut.PC);
            if(!dut.instruction_valid && (dut.issue_valid !== 0 || dut.mode_opcode !== 6'b111111))
                $fatal(1,"Invalid instruction issued or reached mode control");
            if(dut.instruction_valid && !end_flag && dut.branch_wait !== expected_branch_wait)
                $fatal(1,"CBR dependency-stall mismatch PC=%0d",dut.PC);
            decode_ins=prog[dut.PC]; used_sources=source_mask(decode_ins);
            raw_sources=0;
            for(stage_index=0;stage_index<2;stage_index=stage_index+1)
                if(pipe_wen[stage_index] && pipe_rd[stage_index]!=0)
                    raw_sources=raw_sources | (used_sources & {
                        (pipe_rd[stage_index]==decode_ins[10:6]),
                        (pipe_rd[stage_index]==decode_ins[25:21]),
                        (pipe_rd[stage_index]==decode_ins[15:11]),
                        (pipe_rd[stage_index]==decode_ins[20:16])});
            expected_data_wait=(|raw_sources);
            if(dut.instruction_valid && !end_flag &&
               ({dut.data_use_rtemp,dut.data_use_rd,dut.data_use_rb,dut.data_use_ra} !== used_sources ||
                dut.data_wait !== expected_data_wait))
                $fatal(1,"Data source-mask/dependency mismatch PC=%0d",dut.PC);
            data_stalled=dut.instruction_valid && !end_flag && dut.data_wait;
            stalled_ins=decode_ins;
            branch_stalled=dut.instruction_valid && !end_flag && dut.branch_wait;
            stalled_pc=dut.PC;
            if(data_stalled) begin
                data_stalls=data_stalls+1;
                if(raw_sources[0]) raw_ra=raw_ra+1;
                if(raw_sources[1]) raw_rb=raw_rb+1;
                if(raw_sources[2]) raw_rd=raw_rd+1;
                if(raw_sources[3]) raw_rt=raw_rt+1;
                if(raw_sources[1:0]==2'b11) dual_raw=dual_raw+1;
                if(dut.issue_valid || dut.mode_opcode!==6'b111111)
                    $fatal(1,"Dependent data instruction issued during stall");
            end
            if(dut.issue_valid && pipe_wen[0]) begin
                if(pipe_rd[0]==0) r0_exclusions=r0_exclusions+1;
                else begin
                    if(!used_sources[0] && pipe_rd[0]==decode_ins[20:16]) ignored_ra=ignored_ra+1;
                    if(!used_sources[1] && pipe_rd[0]==decode_ins[15:11]) ignored_rb=ignored_rb+1;
                    if(!used_sources[2] && pipe_rd[0]==decode_ins[25:21]) ignored_rd=ignored_rd+1;
                end
            end
            if(branch_stalled) begin
                branch_stalls=branch_stalls+1;
                if(dut.issue_valid || dut.mode_opcode!==6'b111111)
                    $fatal(1,"Dependent CBR issued or reached mode control during stall");
            end
            // Check the actual pending WB packet before the rising-edge write.
            if(dut.rf_wen_reg1 !== pipe_wen[0] || dut.rf_wen_mid !== pipe_wen[1])
                $fatal(1,"EX1/EX2 validity mismatch");
            if(pipe_wen[0] && dut.rd_reg1 !== pipe_rd[0])
                $fatal(1,"EX1 destination mismatch");
            if(pipe_wen[1] && (dut.rd_mid !== pipe_rd[1] || dut.alu_result !== pipe_data[1]))
                $fatal(1,"Registered arithmetic/result-mux data or tag mismatch");
            retire_we=pipe_wen[2]; retire_rd=pipe_rd[2]; retire_data=pipe_data[2];
            if(dut.rf_wen_reg2 !== retire_we)
                $fatal(1,"WB validity mismatch");
            if(retire_we && (dut.rd_reg2 !== retire_rd || dut.alu_result_reg !== retire_data))
                $fatal(1,"WB data/tag mismatch rd=%0d got=%h expected=%h",retire_rd,dut.alu_result_reg,retire_data);
            if(retire_we) retired=retired+1;
            pipe_wen[2]=pipe_wen[1]; pipe_rd[2]=pipe_rd[1]; pipe_data[2]=pipe_data[1];
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
                if(used_sources[0] && dut.ra_forwarded !== ref_rf[ra])
                    $fatal(1,"WB/RF RA operand mismatch PC=%0d",dut.PC);
                if(used_sources[1] && dut.rb_forwarded !== ref_rf[rb])
                    $fatal(1,"WB/RF RB operand mismatch PC=%0d",dut.PC);
                if(used_sources[2] && dut.rd_forwarded !== ref_rf[rd])
                    $fatal(1,"WB/RF RD address operand mismatch PC=%0d",dut.PC);
                if(used_sources[3] && dut.rtemp_forwarded !== ref_rf[rt])
                    $fatal(1,"WB/RF RTEMP address operand mismatch PC=%0d",dut.PC);
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
                        if(dut.branch_ra_nonzero !== (ref_rf[ra] != 0) ||
                           dut.PC_sel !== (ref_rf[ra] != 0))
                            $fatal(1,"CBR predicate/decision mismatch PC=%0d",dut.PC);
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
            if(data_stalled) begin
                if(dut.PC !== stalled_pc || dut.instruction !== stalled_ins ||
                   dut.rf_wen_reg1!==0 || dut.type_access_reg!==0)
                    $fatal(1,"Data bubble advanced PC/instruction or issued a side effect");
            end
            if(branch_stalled) begin
                if(dut.PC !== stalled_pc || dut.instruction[31:26]!==6'd20 ||
                   dut.rf_wen_reg1!==0 || dut.type_access_reg!==0)
                    $fatal(1,"Branch bubble advanced PC or issued a side effect");
            end
            // Both execution stages advance during either dependency wait.
            if(dut.rf_wen_mid !== pipe_wen[1] || dut.rf_wen_reg2 !== pipe_wen[2])
                $fatal(1,"Stall froze execution validity instead of draining");
            if(pipe_wen[1] && (dut.rd_mid !== pipe_rd[1] || dut.alu_result !== pipe_data[1]))
                $fatal(1,"EX1 did not drain into arithmetic registers with aligned tag");
            if(pipe_wen[2] && (dut.rd_reg2 !== pipe_rd[2] || dut.alu_result_reg !== pipe_data[2]))
                $fatal(1,"EX2 did not drain into WB with aligned tag/data");
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
        // Real RAWs, dual-source RAWs, newest-zero priority, and MUL consumers.
        append(enc_i(14,24,0,3)); append(enc_i(14,25,0,4));
        append(enc(2,26,24,25,0)); append(enc(0,27,26,26,0));
        append(enc_i(15,26,0,1)); append(enc_i(14,26,0,0));
        append(enc(0,28,26,0,0));
        append(enc_i(14,26,0,3)); append(enc_i(10,26,26,7));
        append(enc(0,28,0,26,0));
        // These matching encoded fields are not read operands: no bubble.
        append(enc_i(14,26,0,9)); append(enc_i(8,27,0,(26<<11)+5));
        append(enc_i(14,26,0,9)); append(enc_i(14,27,26,6));
        append(enc_i(14,26,0,9)); append(enc_i(15,27,26,3));
        append(enc_i(14,26,0,9)); append(enc(0,26,0,0,0));
        append(enc_i(14,0,0,5)); append(enc(0,28,0,0,0));
        // An independent instruction needs no bubble; WB still forwards.
        append(enc_i(14,26,0,9)); append(enc(0,27,0,0,0));
        append(enc(0,28,26,0,0));
        // The newest EX writer must replace an older WB writer after draining
        // to WB, including a newest zero. Poison instructions expose bad issue.
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
        // Explicitly exercise adjacent producers on each memory-address port.
        append(enc_i(15,12,0,1)); append(enc_i(14,13,0,0));
        append(enc_i(14,11,0,0));
        append(enc_i(15,10,0,1)); append(enc(32,10,11,12,13)); // RD
        append(enc_i(14,11,0,29)); append(enc(32,10,11,12,13)); // RA
        append(enc_i(15,12,0,1)); append(enc(32,10,11,12,13)); // RB
        append(enc_i(14,13,0,33)); append(enc(32,10,11,12,13)); // RTEMP
        // Mode instructions ignore all encoded register fields, even when
        // an EX1/EX2 producer has the same tag. VSYNC still waits for memory.
        append(enc_i(14,24,0,9));
        append(enc(22,24,24,24,24)); append(enc(21,24,24,24,24));
        append(enc_i(14,20,0,93)); // Must wait for DNN completion, not execute while held.
        append(enc(22,0,0,0,0)); append(enc(21,0,0,0,0));
        append(enc_i(8,20,20,7)); append(enc(23,20,20,20,20));
        for(i=0;i<n;i=i+1) begin
            @(negedge clk); #1; iw=1; ia=i; id=prog[i];
        end
        @(negedge clk); #1; iw=0; rst=0;
        repeat(4) @(negedge clk);
        if(issued!=0) $fatal(1,"Controller executed before start");
        #1; start=1; @(negedge clk); #1; start=0;
        wait(end_flag); #2;
        if(head!=tail || tail!=16 || launches!=2 || dut.rf.mem[20] !== 100 ||
           dut.rf.mem[31] !== 0 || dut.rf.mem[22] !== 127)
            $fatal(1,"Counts/final state mismatch head=%0d tail=%0d launches=%0d r20=%h",head,tail,launches,dut.rf.mem[20]);
        repeat(8) @(negedge clk);
        if(dut.issue_valid || dut.start_flag || dut.PC!=0) $fatal(1,"END did not stop fetch");
        // Restart without resetting the RF or instruction memory. The reference
        // retains architectural RF state, just as the physical controller does.
        ref_pc=0; #1; start=1; @(negedge clk); #1; start=0;
        wait(end_flag); #2;
        if(head!=tail || tail!=31 || launches!=4 || dut.rf.mem[20] !== 100 ||
           dut.rf.mem[31] !== 0 || dut.rf.mem[22] !== 127)
            $fatal(1,"Restart state/count mismatch head=%0d tail=%0d launches=%0d",head,tail,launches);
        repeat(8) @(negedge clk);
        if(dut.issue_valid || dut.start_flag || dut.PC!=0) $fatal(1,"Restart END did not stop fetch");
        if(branch_stalls!=36 || cbr_taken==0 || cbr_not_taken==0)
            $fatal(1,"Branch coverage/stall count mismatch stalls=%0d taken=%0d not_taken=%0d",branch_stalls,cbr_taken,cbr_not_taken);
        if(raw_ra==0 || raw_rb==0 || raw_rd==0 || raw_rt==0 || dual_raw==0 ||
           ignored_ra==0 || ignored_rb==0 || ignored_rd==0 || r0_exclusions==0)
            $fatal(1,"Data RAW/source-mask coverage incomplete");
        if(accepted_sdc!=4 || accepted_vsync!=4 || accepted_end!=2 ||
           mode_field_matches==0 || mode_memory_waits==0 || mode_end_drains==0)
            $fatal(1,"Mode-acceptance coverage incomplete sdc=%0d vsync=%0d end=%0d matches=%0d memory=%0d drain=%0d",
                   accepted_sdc,accepted_vsync,accepted_end,mode_field_matches,mode_memory_waits,mode_end_drains);
        $display("CONTROLLER_RESULT issued=%0d retired=%0d transfers=%0d launches=%0d branch_stalls=%0d cbr_taken=%0d cbr_not_taken=%0d errors=0",issued,retired,head,launches,branch_stalls,cbr_taken,cbr_not_taken);
        $display("CONTROLLER_RAW_RESULT stalls=%0d ra=%0d rb=%0d rd=%0d rtemp=%0d dual=%0d ignored_ra=%0d ignored_rb=%0d ignored_rd=%0d r0_exclusions=%0d errors=0",data_stalls,raw_ra,raw_rb,raw_rd,raw_rt,dual_raw,ignored_ra,ignored_rb,ignored_rd,r0_exclusions);
        $display("CONTROLLER_PREDICATE_RESULT cycles=%0d RF_flags=32 WB_flag=1 CBR=checked errors=0",predicate_checks);
        $display("CONTROLLER_WB_MASK_RESULT cycles=%0d WB_mask=checked visible_flags=checked bubbles_R0_overwrites=checked errors=0",predicate_checks);
        $display("CONTROLLER_MODE_ACCEPT_RESULT checks=%0d sdc=%0d vsync=%0d end=%0d unused_field_matches=%0d memory_waits=%0d end_drains=%0d errors=0",
                 mode_accept_checks,accepted_sdc,accepted_vsync,accepted_end,mode_field_matches,mode_memory_waits,mode_end_drains);
        $display("TEST_PASS: multiplier-output pipeline, EX1/EX2 tag/data alignment, WB-only forwarding with dependency bubbles, memory packets, backpressure, start/drain/END and restart");
        $finish;
    end
    always @(posedge rst) begin
        #1;
        if(dut.wb_nonzero !== 0 || dut.rf_nonzero !== 0 || dut.wb_dest_mask !== 0 ||
           dut.rf_pending !== 0 || dut.ex1_dest_mask !== 0)
            $fatal(1,"Branch predicate asynchronous reset failed");
    end
    initial begin
        wait(!rst && dut.issue_valid && dut.instruction[31:26]==6'd32);
        @(negedge clk); #1; p0_in={4'd2,32'd0,32'h0001abcd};
        @(negedge clk); #1; p0_in=0;
    end
endmodule
