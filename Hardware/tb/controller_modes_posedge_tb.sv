`timescale 1ns/1ps
module controller_modes_posedge_tb;
    reg clk=0,rst=1,s3=0,s4=0,v3=0,v4=0,h3=0,h4=0;
    reg d3=1,d4=1,prev3=0,prev4=0,prevv4=0;
    reg [5:0] op3=63,op4=63;
    wire start3,start4,en3,en4,vs3,vs4,hs3,hs4,end3,end4,tx3,tx4,vtx4;
    Mode_ctrller_3 #(.IS_FIRST_ROW(0),.IS_FIRST_COL(0)) m3(
        .clk(clk),.rst(rst),.start(s3),.opcode(op3),.DNN_done(d3),
        .vsync_in(v3),.hsync_in(h3),.done_transfer_prev(prev3),
        .start_DNN_core(start3),.enable_PC(en3),.vsync_out(vs3),.hsync_out(hs3),
        .end_flag(end3),.done_transfer(tx3));
    Mode_ctrller_4 #(.IS_FIRST_ROW(0),.IS_FIRST_COL(0)) m4(
        .clk(clk),.rst(rst),.start(s4),.opcode(op4),.DNN_done(d4),
        .vsync_in(v4),.hsync_in(h4),.done_transfer_prev(prev4),.done_vtransfer_prev(prevv4),
        .start_DNN_core(start4),.enable_PC(en4),.vsync_out(vs4),.hsync_out(hs4),
        .end_flag(end4),.done_transfer(tx4),.done_vtransfer(vtx4));
    always #5 clk=~clk;
    reg [3:0] held3=0,held4=0;
    integer checks=0;
    always @(posedge clk) begin #2; held3=m3.state; held4=m4.state; end
    always @(negedge clk) if(!rst && (held3 !== m3.state || held4 !== m4.state))
        $fatal(1,"Mode state changed at falling edge");
    task tick3(input integer state_expected,input bit enable_expected);
        begin
            @(posedge clk); #1;
            if(m3.state !== state_expected[3:0] || en3 !== enable_expected)
                $fatal(1,"Mode3 transition got=%0d expected=%0d en=%0d",m3.state,state_expected,en3);
            checks=checks+1; @(negedge clk); #1;
        end
    endtask
    task tick4(input integer state_expected,input bit enable_expected);
        begin
            @(posedge clk); #1;
            if(m4.state !== state_expected[3:0] || en4 !== enable_expected)
                $fatal(1,"Mode4 transition got=%0d expected=%0d en=%0d",m4.state,state_expected,en4);
            checks=checks+1; @(negedge clk); #1;
        end
    endtask
    initial begin
        repeat(2) @(negedge clk); #1;
        if(start3 !== 0 || start4 !== 0) $fatal(1,"Mode start output not reset");
        rst=0; s3=1; tick3(1,1); s3=0;
        op3=22; tick3(2,0); if(vs3 !== 1) $fatal(1,"Mode3 VSYNC missing");
        op3=63; tick3(2,0); v3=1; tick3(3,1); v3=0;
        op3=21; tick3(4,0); if(start3 !== 1) $fatal(1,"Mode3 start missing");
        op3=63; tick3(4,0); // Sticky previous-run done=1 must be ignored here.
        if(start3 !== 0) $fatal(1,"Mode3 start pulse wider than one cycle");
        d3=0; tick3(4,0); d3=1; tick3(5,1);
        op3=24; tick3(6,0); if(hs3 !== 1) $fatal(1,"Mode3 HSYNC missing");
        op3=63; h3=1; tick3(7,0); h3=0;
        tick3(7,0); prev3=1; tick3(8,1); prev3=0;
        op3=24; tick3(9,0); if(tx3 !== 1) $fatal(1,"Mode3 completion missing");
        op3=63; h3=1; tick3(10,1); h3=0;
        op3=23; tick3(1,1); if(end3 !== 1) $fatal(1,"Mode3 END missing");
        op3=63;

        s4=1; tick4(1,1); s4=0;
        op4=22; tick4(2,0); if(vs4 !== 1) $fatal(1,"Mode4 VSYNC missing");
        op4=63; v4=1; tick4(3,0); v4=0;
        tick4(3,0); prevv4=1; tick4(4,1); prevv4=0;
        op4=22; tick4(5,0); if(vtx4 !== 1) $fatal(1,"Mode4 vertical completion missing");
        op4=63; v4=1; tick4(6,1); v4=0;
        op4=21; tick4(7,0); if(start4 !== 1) $fatal(1,"Mode4 start missing");
        op4=63; tick4(7,0);
        if(start4 !== 0) $fatal(1,"Mode4 start pulse wider than one cycle");
        d4=0; tick4(7,0); d4=1; tick4(8,1);
        op4=24; tick4(9,0); if(hs4 !== 1) $fatal(1,"Mode4 HSYNC missing");
        op4=63; h4=1; tick4(10,0); h4=0;
        tick4(11,1); // Diagonal non-first-row/non-first-column transfer case.
        op4=24; tick4(12,0); if(tx4 !== 1) $fatal(1,"Mode4 transfer completion missing");
        op4=63; h4=1; tick4(13,1); h4=0;
        op4=23; tick4(1,1); if(end4 !== 1) $fatal(1,"Mode4 END missing");
        $display("CONTROLLER_MODE_RESULT models=ONE_ONE,TWO_TWO checks=%0d errors=0",checks);
        $display("TEST_PASS: rising-edge mode FSMs, reset, start pulse, stale-done rejection, vertical/horizontal waits and END");
        $finish;
    end
    initial begin #10000; $fatal(1,"Mode test timeout"); end
endmodule
