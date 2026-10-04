`timescale 1ns/1ps
// Public-port stimulus, independent MAC arithmetic, instruction tags and native
// memory probes. No DUT force/deposit is used. Exercise main and debug cores.
module posedge_flow_tb;
    reg clk=0, rst=1, start=0, iw=0, bw=0, obren=0;
    reg [8:0] ia=0, iba=0, ka=0, ba=0, obra=0;
    reg [211:0] id=0;
    reg [63:0] ibw=0, kw=0;
    reg [15:0] wd=0;
    wire done, debug_done;
    wire [15:0] obout, debug_obout;
    DNN_Core dut(.clk(clk),.rst(rst),.start(start),
        .DC_write_en(iw),.DC_addr_w(ia),.DC_inst_w(id),
        .en_write_IB(ibw),.en_write_KSP(kw),.en_write_BSP(bw),
        .IB_wr_addr(iba),.KSP_wr_addr(ka),.BSP_wr_addr(ba),.data_write(wd),
        .en_C_read_OB(obren),.OB_MC_rd_addr(obra),.OB_MC_read(obout),.dnn_done(done),
        .OB_data_read(),.MEM_data_read(),.addr_write_OSP_ML_out(),.addr_write_OSP_CONV_out(),
        .addr_write_FCSP_ML_out(),.addr_write_FCSP_CONV_out(),.addr_write_OB_ML_out(),
        .addr_write_OB_CONV_out(),.addr_read_OB_ML_out());
    DNN_Core_debug debug_dut(.clk(clk),.rst(rst),.start(start),
        .DC_write_en(iw),.DC_addr_w(ia),.DC_inst_w(id),
        .en_write_IB(ibw),.en_write_KSP(kw),.en_write_BSP(bw),
        .IB_wr_addr(iba),.KSP_wr_addr(ka),.BSP_wr_addr(ba),.data_write(wd),
        .en_C_read_OB(obren),.OB_MC_rd_addr(obra),.OB_MC_read(debug_obout),.dnn_done(debug_done),
        .OB_data_read(),.MEM_data_read());
    always #5 clk=~clk;

    reg collision_we=0, collision_re=0;
    reg [8:0] collision_wa=0, collision_ra=0;
    reg [15:0] collision_data=0;
    wire [15:0] collision_q, generic_q;
    bit collision_test_done=0;
    BRAM collision_ram(.clka(clk),.clkb(clk),.ena(1'b1),.enb(collision_re),
        .wea(collision_we),.addra(collision_wa),.addrb(collision_ra),
        .dina(collision_data),.doutb(collision_q));
    mem #(.EN_OUT_FF(1)) generic_ram(.clk(clk),.wen(collision_we),.ren(collision_re),
        .addr_w(collision_wa),.addr_r(collision_ra),.wdata(collision_data),.rdata(generic_q));
    initial begin
        @(negedge clk); #1; collision_we=1; collision_data=16'h1111;
        @(negedge clk); #1; collision_wa=1; collision_data=16'h2222;
        @(negedge clk); #1;
        collision_wa=0; collision_data=16'h3333; collision_re=1;
        @(posedge clk); #2;
        if(collision_q !== 16'h1111 || generic_q !== 16'h1111)
            $fatal(1,"Same-address collision did not return pre-write data");
        collision_we=0;
        @(negedge clk); #1;
        if(collision_q !== 16'h1111) $fatal(1,"BRAM read updated at falling edge");
        @(posedge clk); #2;
        if(collision_q !== 16'h3333 || generic_q !== 16'h3333)
            $fatal(1,"BRAM did not expose committed data on next rising edge");
        collision_re=0; collision_ra=1;
        @(posedge clk); #2;
        if(collision_q !== 16'h3333) $fatal(1,"Disabled BRAM read did not hold");
        collision_re=1;
        @(posedge clk); #2;
        if(collision_q !== 16'h2222 || generic_q !== 16'h2222)
            $fatal(1,"BRAM address/read latency mismatch");
        collision_re=0; collision_test_done=1;
    end

    reg [211:0] program_mem[0:11];
    reg signed [15:0] ref_eoa[0:4][0:63];
    reg signed [15:0] old_eoa[0:63], next_eoa[0:63];
    reg signed [15:0] ref_ob[0:3];
    integer tags[0:5];
    integer issued=0, stores=0, bypasses=0, commits=0, eoa_checks=0;
    integer i,j,k,step,lane,product,value,operand,accumulator,read_addr=0;
    integer pre_tag, s;
    reg [63:0] mask;
    reg pre_eoa_valid, pre_end_commit;
    wire [15:0] osp_probe[0:63], debug_osp_probe[0:63];
    wire [15:0] eoa_probe[0:63], debug_eoa_probe[0:63];
    genvar p;
    generate for(p=0;p<64;p=p+1) begin: probes
        assign osp_probe[p]=dut.OSP_array[p].OSP.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[read_addr];
        assign debug_osp_probe[p]=debug_dut.OSP_array[p].OSP.memory[read_addr];
        assign eoa_probe[p]=dut.EOA_read[p];
        assign debug_eoa_probe[p]=debug_dut.EOA_read[p];
    end endgenerate

    function integer pixel(input integer l,input integer a);
        pixel=(l-20)*(a+1)*21+a*3+7;
    endfunction
    function integer weight(input integer l,input integer a);
        weight=(l%7-3)*65+17+a*19;
    endfunction
    function [211:0] instruction(input [63:0] enables,input bit last,
        input integer ib,input integer kernel,input integer osw,input integer osr,
        input integer obw,input integer obr,input integer load_mode,
        input integer mul1,input integer mul2,input integer acc,
        input integer max_source,input integer store_mode,input integer store_source);
        reg [211:0] ins;
        begin
            ins=0; ins[211:148]=enables; ins[147]=last; ins[135]=1;
            ins[134:125]=ib; ins[124:115]=kernel;
            ins[114:105]=osw; ins[104:95]=osr;
            ins[94:85]=obw; ins[84:75]=obr;
            ins[44:34]={load_mode[2:0],8'd9};
            ins[33:28]={mul1[1:0],mul2[0],acc[1:0],1'b0};
            ins[18:7]={max_source[2:0],8'b0,1'b0};
            ins[6:0]={store_mode[2:0],store_source[1:0],2'd2};
            instruction=ins;
        end
    endfunction

    // Check the pre-edge write packet and the post-edge EOA state separately.
    always @(posedge clk) begin
        if(rst) begin
            for(s=0;s<6;s=s+1) tags[s]=-1;
        end else begin
            pre_tag=tags[2]; pre_eoa_valid=dut.pipe_valid[2];
            pre_end_commit=dut.pipe_valid[5] && dut.pipe_end[5];
            if(dut.issue_valid) begin
                if(dut.PC>10) $fatal(1,"Instruction after END was issued");
                issued=issued+1;
            end
            if(dut.OSP_store_en) begin
                if(tags[5]<0 || tags[5]>4 || dut.OSP_MS_wr_addr!==tags[5][8:0])
                    $fatal(1,"OSP instruction/address misalignment");
                for(j=1;j<64;j=j+1) if(dut.OSP_enable[j]) begin
                    if(dut.PEOA_read[j] !== ref_eoa[tags[5]][j-1] ||
                       debug_dut.PEOA_read[j] !== ref_eoa[tags[5]][j-1])
                        $fatal(1,"OSP data misalignment tag=%0d lane=%0d",tags[5],j);
                end
            end
            if(dut.OB_store_en) begin
                if(tags[5]<7 || tags[5]>10 || dut.OB_MS_wr_addr!==(tags[5]-7))
                    $fatal(1,"OB instruction/address misalignment tag=%0d",tags[5]);
                if(dut.OB_data_wr !== ref_ob[tags[5]-7] ||
                   debug_dut.OB_data_wr !== ref_ob[tags[5]-7])
                    $fatal(1,"OB data mismatch tag=%0d got=%0d expected=%0d",tags[5],$signed(dut.OB_data_wr),ref_ob[tags[5]-7]);
                stores=stores+1;
            end
            if(dut.pipe_valid[4] && dut.src_max==2 && dut.OB_store_en &&
               dut.OB_MS_wr_addr==dut.OB_PL_rd_addr) bypasses=bypasses+1;
            if(pre_end_commit) commits=commits+1;
            for(s=5;s>0;s=s-1) tags[s]=tags[s-1];
            tags[0]=dut.issue_valid ? dut.PC : -1;
            #1;
            if(pre_eoa_valid && pre_tag>=0 && pre_tag<=4)
                for(j=0;j<64;j=j+1) begin
                    if(eoa_probe[j] !== ref_eoa[pre_tag][j] ||
                       debug_eoa_probe[j] !== ref_eoa[pre_tag][j])
                        $fatal(1,"MAC flow mismatch instruction=%0d lane=%0d",pre_tag,j);
                    eoa_checks=eoa_checks+1;
                end
            if(pre_end_commit && (!done || !debug_done))
                $fatal(1,"Completion did not coincide with final committed store");
            if(done !== debug_done) $fatal(1,"Main/debug completion disagree");
        end
    end

    task check_idle;
        integer idle_cycle, idle_lane;
        begin
            repeat(12) begin
                @(posedge clk); #2;
                if(dut.issue_valid || dut.OSP_store_en || dut.OB_store_en || dut.FCSP_store_en)
                    $fatal(1,"Idle core issued or stored an instruction");
                for(idle_lane=0;idle_lane<64;idle_lane=idle_lane+1)
                    if(eoa_probe[idle_lane] !== ref_eoa[4][idle_lane])
                        $fatal(1,"Idle changed EOA state");
            end
        end
    endtask
    task launch_and_check;
        integer a,l;
        begin
            @(negedge clk); #1; start=1;
            @(negedge clk); #1; start=0;
            wait(done); #2;
            for(a=0;a<5;a=a+1) begin
                read_addr=a; #1;
                for(l=1;l<64;l=l+1)
                    if(program_mem[a][148+l-1]) begin
                        if(osp_probe[l] !== ref_eoa[a][l-1] || debug_osp_probe[l] !== ref_eoa[a][l-1])
                            $fatal(1,"Native OSP memory mismatch address=%0d lane=%0d",a,l);
                    end
            end
            for(a=0;a<4;a=a+1) begin
                if(dut.OBIP.inst.ram_data[a] !== ref_ob[a] ||
                   dut.OB_MC.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[a] !== ref_ob[a] ||
                   debug_dut.OB.memory[a] !== ref_ob[a] || debug_dut.OB_MC.memory[a] !== ref_ob[a])
                    $fatal(1,"Native output memories mismatch address=%0d",a);
                // Request is sampled at one rising edge; the consumer sees
                // the registered output afterward, not in the same event.
                @(negedge clk); #1; obren=1; obra=a;
                @(posedge clk); #2;
                if(obout !== ref_ob[a] || debug_obout !== ref_ob[a])
                    $fatal(1,"Controller OB read failed address=%0d",a);
            end
            @(negedge clk); #1; obren=0;
            check_idle();
        end
    endtask

    initial begin
        // Alternating lanes, broadcast and local operands, held weights,
        // self accumulation and neighbor accumulation, all with fractional data.
        program_mem[0]=instruction('1,0,0,0,0,0,0,0,2,2,1,0,0,2,0);
        program_mem[1]=instruction('1,0,1,0,1,0,0,0,1,2,1,3,0,2,0);
        program_mem[2]=instruction('1,0,2,0,2,0,0,0,0,2,1,2,0,2,0);
        program_mem[3]=instruction('1,0,3,1,3,0,0,0,2,1,1,0,0,2,0);
        program_mem[4]=instruction(64'haaaaaaaaaaaaaaaa,0,4,1,4,0,0,0,1,1,0,2,0,2,0);
        program_mem[5]=0; program_mem[6]=0;
        program_mem[7]=instruction(0,0,0,0,0,0,0,0,5,0,0,0,0,1,3);
        program_mem[8]=instruction(0,0,0,0,0,1,1,0,5,0,0,0,2,1,2);
        program_mem[9]=instruction(0,0,0,0,0,2,2,1,5,0,0,0,2,1,2);
        program_mem[10]=instruction(0,1,0,0,0,3,3,2,5,0,0,0,2,1,2);
        // The former LUT-select bit is reserved in the ReLU-only core. Exercise
        // both encodings in actual issued instructions and committed OB stores.
        program_mem[8][27]=1'b1;
        program_mem[10][27]=1'b1;
        program_mem[11]=instruction('1,0,0,0,0,0,31,0,2,1,0,0,0,1,0);
        for(lane=0;lane<64;lane=lane+1) old_eoa[lane]=0;
        for(step=0;step<5;step=step+1) begin
            mask=program_mem[step][211:148];
            for(lane=0;lane<64;lane=lane+1) begin
                case(step)
                    0: begin operand=pixel(0,0); value=weight(lane,0); accumulator=0; end
                    1: begin operand=pixel(0,1); value=weight(lane,0); accumulator=(lane==0)?0:old_eoa[lane-1]; end
                    2: begin operand=pixel(0,1); value=weight(lane,0); accumulator=old_eoa[lane]; end
                    3: begin operand=pixel(lane,3); value=weight(lane,1); accumulator=0; end
                    4: begin operand=pixel(lane,4); value=256; accumulator=old_eoa[lane]; end
                endcase
                product=(operand*value) >>> 8;
                next_eoa[lane]=mask[lane] ? accumulator+product : old_eoa[lane];
                ref_eoa[step][lane]=next_eoa[lane];
            end
            for(lane=0;lane<64;lane=lane+1) old_eoa[lane]=next_eoa[lane];
        end
        for(step=0;step<4;step=step+1) begin
            value=ref_eoa[step][8]+37;
            if(value<0) value=0;
            if(step>0 && value<ref_ob[step-1]) value=ref_ob[step-1];
            ref_ob[step]=value;
        end
        for(i=0;i<12;i=i+1) begin
            @(negedge clk); #1; iw=1; ia=i; id=program_mem[i];
        end
        @(negedge clk); #1; iw=0;
        for(i=0;i<5;i=i+1) for(lane=0;lane<64;lane=lane+1) begin
            ibw=64'b1<<lane; iba=i; wd=pixel(lane,i);
            @(negedge clk); #1;
        end
        ibw=0;
        for(i=0;i<2;i=i+1) for(lane=0;lane<64;lane=lane+1) begin
            kw=64'b1<<lane; ka=i; wd=weight(lane,i);
            @(negedge clk); #1;
        end
        kw=0; bw=1; ba=0; wd=37;
        @(negedge clk); #1; bw=0;
        // Explicit memory clock check, starting with a known existing word.
        @(posedge clk); #2; ibw=1; iba=0; wd=16'h1234;
        @(negedge clk); #1;
        if($signed(dut.IB_array[0].IB.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[0]) !== pixel(0,0))
            $fatal(1,"IB changed at falling edge");
        @(posedge clk); #2;
        if(dut.IB_array[0].IB.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[0] !== 16'h1234)
            $fatal(1,"IB did not write at rising edge");
        wd=pixel(0,0);
        @(posedge clk); #2; ibw=0;
        @(negedge clk); #1; rst=0;
        launch_and_check();
        launch_and_check();
        // Abort a partially issued run, then verify a clean restart.
        @(negedge clk); #1; start=1;
        @(negedge clk); #1; start=0;
        repeat(3) @(negedge clk);
        #1; rst=1;
        repeat(2) @(negedge clk);
        #1; rst=0;
        launch_and_check();
        if(stores!=12 || bypasses!=9 || commits!=3 || !collision_test_done)
            $fatal(1,"Unexpected commit counts stores=%0d bypasses=%0d commits=%0d",stores,bypasses,commits);
        $display("POSEDGE_FLOW_RESULT MAC_checks=%0d stores=%0d same_edge_OB_forwards=%0d completed_runs=%0d",eoa_checks,stores,bypasses,commits);
        $display("TEST_PASS: rising-edge memory, X-loop flow, masks, holds, END store, idle, restart, reset and OB reads");
        $finish;
    end
    initial begin #100000; $fatal(1,"Posedge flow timeout"); end
endmodule
