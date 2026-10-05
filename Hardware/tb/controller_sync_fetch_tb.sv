`timescale 1ns/1ps
// Only program/handshake/reset ports drive the DUT. Internal signals are probes.
module controller_sync_fetch_case #(parameter MODEL=1)(output reg finished=0);
    reg clk=0,rst=1,start=0,wen=0;
    reg [5:0] wr_addr=0;
    reg [31:0] wr_data=0;
    reg vi=0,hi=0,done=1,prev=0,prevv=0;
    wire vo,ho,launch,ending;
    Controller #(.MCMEM_W(64),.MODEL(MODEL),.IS_FIRST_ROW(0),.IS_FIRST_COL(0)) dut(
        .clk(clk),.rst(rst),.start(start),.mcmem_wen(wen),
        .mcmem_wr_addr(wr_addr),.mcmem_wr_data(wr_data),
        .vsync_in(vi),.hsync_in(hi),.dnn_done(done),
        .vsync_out(vo),.hsync_out(ho),.start_DNN(launch),.end_flag(ending),
        .command_P0_in(68'd0),.data_P0_in(16'd0),.command_P1_in(68'd0),
        .data_P1_in(16'd0),.inst_P1_in(212'd0),.OM_rd_data(16'd0),
        .OM_inst_rd(212'd0),.DNN_rd_data(16'd0),
        .done_transfer_prev(prev),.done_vtransfer_prev(prevv));
    always #5 clk=~clk;
    generate if(MODEL==1) begin : check_single_mode_acceptance
        // Preserve the old accepted-opcode behavior through reset, invalid
        // fetches, delayed handshakes, repeated start, END and restart.
        always @(posedge clk) if(!rst) begin
            if({dut.single_mode.accept_end,dut.single_mode.accept_vsync,
                dut.single_mode.accept_sdc} !==
               {(dut.mode_opcode==6'd23),(dut.mode_opcode==6'd22),
                (dut.mode_opcode==6'd21)})
                $fatal(1,"SINGLE direct mode acceptance differs from legacy opcode");
        end
    end endgenerate
    reg [31:0] program_words[0:63];
    reg [31:0] ref_rf[0:31];
    reg [5:0] ref_pc=0,read_addr,old_pc,legacy_read_addr;
    reg [31:0] read_word,old_instruction,stable_instruction,ins;
    reg [3:0] stable_meta,old_meta;
    bit read_en,old_valid,was_reset,was_end;
    integer i,k,opc,rd,ra,ticks=0,core_wait=0;
    integer reads=0,holds=0,invalid_cycles=0,issues=0,waits=0,ends=0;
    integer checked_reads=0,bootstrap_reads=0,lookahead_holds=0;
    function [31:0] enc(input integer op,input integer d,input integer a,input integer imm);
        enc={op[5:0],d[4:0],a[4:0],imm[15:0]};
    endfunction
    function [3:0] expected_meta(input [31:0] word);
        reg [5:0] code;
        reg is_mem;
        begin
            code=word[31:26]; is_mem=(code>=32 && code<=39);
            expected_meta={(code==20),is_mem,(code<=4 || is_mem),(code<=13 || is_mem)};
        end
    endfunction
    always @(negedge clk) begin
        if(dut.instruction !== stable_instruction)
            $fatal(1,"MODEL%0d instruction changed outside rising edge",MODEL);
        if(dut.instruction_meta !== stable_meta)
            $fatal(1,"MODEL%0d metadata changed outside rising edge",MODEL);
        // Delayed external handshakes exercise every mode's PC-enable waits.
        ticks=ticks+1;
        vi=(ticks%7==0); hi=(ticks%11==0);
        prev=(ticks%13==0); prevv=(ticks%17==0);
        if(rst) begin done=1; core_wait=0; end
        else if(launch) begin done=0; core_wait=4; end
        else if(core_wait>0) begin
            core_wait=core_wait-1;
            if(core_wait==0) done=1;
        end
    end
    always @(posedge clk) begin
        was_reset=rst; was_end=ending;
        read_en=dut.instruction_read_en; read_addr=dut.PC_next;
        read_word=program_words[read_addr];
        old_pc=dut.PC; old_instruction=dut.instruction; old_valid=dut.instruction_valid;
        old_meta=dut.instruction_meta;
        if(!rst && dut.wb_dest_mask !==
           ((dut.rf_wen_reg2 && dut.rd_reg2!=0) ? (32'b1 << dut.rd_reg2) : 32'b0))
            $fatal(1,"MODEL%0d WB mask/tag alignment mismatch",MODEL);
        // Address changes while read enable is low are intentional. On every
        // enabled edge, however, the candidate must equal the former
        // issue-gated address, including bootstrap and truncated branch targets.
        legacy_read_addr=old_pc;
        if(ending) legacy_read_addr=0;
        else if(dut.issue_valid)
            legacy_read_addr=dut.PC_sel ? dut.imm16 : old_pc+1'b1;
        if(read_en) begin
            if(read_addr !== legacy_read_addr)
                $fatal(1,"MODEL%0d enabled read differs from legacy address",MODEL);
            checked_reads=checked_reads+1;
            if(!dut.start_flag) bootstrap_reads=bootstrap_reads+1;
        end else if(!rst && !ending && dut.start_flag && old_valid && read_addr !== old_pc)
            lookahead_holds=lookahead_holds+1;
        if(read_en !== (!rst && !ending && ((start && !dut.start_flag) || dut.issue_valid)))
            $fatal(1,"MODEL%0d unexpected instruction read enable",MODEL);
        if((!dut.instruction_valid || ending || rst) && dut.issue_valid !== 0)
            $fatal(1,"MODEL%0d invalid/reset/END instruction issued",MODEL);
        if(!dut.issue_valid && dut.mode_opcode !== 6'd63)
            $fatal(1,"MODEL%0d stalled/invalid opcode reached mode FSM",MODEL);
        if(!rst && dut.instruction_valid && !ending) begin
            if(dut.instruction !== program_words[dut.PC] || dut.PC !== ref_pc)
                $fatal(1,"MODEL%0d instruction-order/alignment error PC=%0d ref=%0d",MODEL,dut.PC,ref_pc);
            if(!dut.PC_en) waits=waits+1;
        end
        if(rst) begin
            ref_pc=0;
            for(k=0;k<32;k=k+1) ref_rf[k]=0;
        end else if(ending) begin ref_pc=0; ends=ends+1; end
        else if(dut.issue_valid) begin
            ins=program_words[ref_pc]; opc=ins[31:26]; rd=ins[25:21]; ra=ins[20:16];
            ref_pc=ref_pc+1'b1;
            case(opc)
                14: if(rd!=0) ref_rf[rd]={16'd0,ins[15:0]};
                6: if(rd!=0) ref_rf[rd]=ref_rf[ra]-1;
                19: ref_pc=ins[5:0];
                20: if(ref_rf[ra]!=0) ref_pc=ins[5:0];
            endcase
            issues=issues+1;
        end
        // Read-first shadow RAM: the synchronous read observes the pre-write
        // word. Programs are uploaded while stopped, never patched in flight.
        if(wen) program_words[wr_addr]=wr_data;
        #1;
        if(was_reset || was_end) begin
            if(dut.PC !== 0 || dut.instruction_valid !== 0)
                $fatal(1,"MODEL%0d reset/END did not invalidate instruction",MODEL);
        end else if(read_en) begin
            if(dut.PC !== read_addr || dut.instruction !== read_word || dut.instruction_valid !== 1)
                $fatal(1,"MODEL%0d synchronous fetch/address/valid mismatch",MODEL);
            if(dut.instruction_meta !== expected_meta(read_word))
                $fatal(1,"MODEL%0d instruction/predecode metadata misalignment",MODEL);
            reads=reads+1;
        end else begin
            if(dut.PC !== old_pc || dut.instruction_valid !== old_valid)
                $fatal(1,"MODEL%0d stall changed PC/valid",MODEL);
            holds=holds+1;
        end
        if(!read_en && dut.instruction !== old_instruction)
            $fatal(1,"MODEL%0d disabled RAM read did not hold instruction",MODEL);
        if(!read_en && dut.instruction_meta !== old_meta)
            $fatal(1,"MODEL%0d disabled RAM read did not hold metadata",MODEL);
        if(!dut.instruction_valid) invalid_cycles=invalid_cycles+1;
        stable_instruction=dut.instruction;
        stable_meta=dut.instruction_meta;
    end
    task write_word(input integer addr,input [31:0] word);
        begin @(negedge clk); #2; wen=1; wr_addr=addr; wr_data=word; end
    endtask
    task stop_write;
        begin @(negedge clk); #2; wen=0; end
    endtask
    task kick;
        begin @(negedge clk); #2; start=1; @(negedge clk); #2; start=0; end
    endtask
    task async_reset;
        begin
            #2; rst=1; start=0;
            #1;
            if(dut.instruction_valid !== 0 || dut.issue_valid !== 0 || dut.PC !== 0 ||
               dut.rf_wen_reg1 !== 0 || dut.rf_wen_mid !== 0 || dut.rf_wen_reg2 !== 0 ||
               dut.rf_nonzero !== 0 || dut.wb_nonzero !== 0 || dut.wb_dest_mask !== 0 ||
               dut.rf_pending !== 0 || dut.ex1_dest_mask !== 0)
                $fatal(1,"MODEL%0d asynchronous reset failed",MODEL);
            repeat(2) @(negedge clk); #2; rst=0;
        end
    endtask
    task check_finished(input integer value);
        begin
            wait(ending); #2;
            if(dut.rf.mem[1] !== 0 || dut.rf.mem[2] !== value || dut.rf.mem[31] !== 0)
                $fatal(1,"MODEL%0d architectural final/poison state wrong",MODEL);
            repeat(6) @(negedge clk); #2;
            if(dut.instruction_valid !== 0 || dut.issue_valid !== 0 || dut.PC !== 0 || dut.start_flag !== 0)
                $fatal(1,"MODEL%0d END did not stop fetch/issue",MODEL);
        end
    endtask
    initial begin
        // Every unused fall-through is poisonous, exposing stale/extra issue.
        for(i=0;i<64;i=i+1) write_word(i,enc(14,31,0,16'hdead));
        write_word(0,enc(19,0,0,16'h123f)); // target truncates to address 63
        write_word(63,enc(63,0,0,0));       // sequential advance wraps to zero
        stop_write(); rst=0; kick();
        wait(dut.issue_valid && dut.PC==63); @(posedge clk); #2;
        if(dut.PC !== 0 || dut.instruction !== enc(19,0,0,16'h123f))
            $fatal(1,"MODEL%0d sequential PC wrap fetch failed",MODEL);
        async_reset();
        write_word(0,enc(14,1,0,2)); write_word(1,enc(6,1,1,0));
        write_word(2,enc(20,0,1,1)); write_word(3,enc(19,0,0,8));
        write_word(8,enc(14,2,0,123));
        i=9;
        write_word(i,enc(22,0,0,0)); i=i+1;
        if(MODEL==3) begin write_word(i,enc(22,0,0,0)); i=i+1; end
        write_word(i,enc(21,0,0,0)); i=i+1;
        if(MODEL!=1) begin
            write_word(i,enc(24,0,0,0)); i=i+1;
            write_word(i,enc(24,0,0,0)); i=i+1;
        end
        write_word(i,enc(23,0,0,0)); stop_write();
        kick();
        wait(dut.branch_wait); // A repeated start must not discard a held CBR.
        @(negedge clk); #2; start=1; @(negedge clk); #2; start=0;
        check_finished(123);
        // Change word zero while idle: restart must fetch new data, not the
        // old registered output (which contains the post-END poison word).
        write_word(0,enc(14,1,0,3)); write_word(8,enc(14,2,0,456)); stop_write();
        repeat(3) @(negedge clk);
        kick(); check_finished(456);
        // Abort in a dependency stall and start again after asynchronous reset.
        kick(); wait(dut.data_wait && dut.instruction_valid); async_reset();
        kick(); check_finished(456);
        if(waits==0 || ends!=3 || reads==0 || holds==0 || invalid_cycles==0 ||
           checked_reads==0 || bootstrap_reads==0 || lookahead_holds==0)
            $fatal(1,"MODEL%0d fetch/control coverage incomplete",MODEL);
        $display("CONTROLLER_SYNC_FETCH_RESULT model=%0d reads=%0d holds=%0d invalid=%0d issues=%0d mode_waits=%0d ends=%0d errors=0",MODEL,reads,holds,invalid_cycles,issues,waits,ends);
        $display("CONTROLLER_LOOKAHEAD_RESULT model=%0d equivalent_reads=%0d bootstrap_reads=%0d held_candidate_changes=%0d errors=0",MODEL,checked_reads,bootstrap_reads,lookahead_holds);
        finished=1;
    end
    initial begin #30000; if(!finished) $fatal(1,"MODEL%0d fetch test timeout",MODEL); end
endmodule

module controller_sync_fetch_tb;
    wire f1,f2,f3;
    controller_sync_fetch_case #(.MODEL(1)) single_case(f1);
    controller_sync_fetch_case #(.MODEL(2)) one_one_case(f2);
    controller_sync_fetch_case #(.MODEL(3)) two_two_case(f3);
    initial begin
        wait(f1 && f2 && f3);
        $display("TEST_PASS: synchronous PC/instruction pairing, read-enable holds, branches/wrap, invalid gating, idle updates, repeated start, END/restart, active reset and all three controller modes");
        $finish;
    end
endmodule
