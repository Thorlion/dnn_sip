`timescale 1ns/1ps
module mem_ctrl_posedge_tb;
    reg clk=0,rst=1;
    reg [67:0] mc=0,p0=0,p1=0;
    reg [15:0] data0=16'h8137,data1=16'h62a4;
    reg [211:0] inst1={20'h13579,{6{32'hdeadbeef}}};
    wire busy,ow,orr,ir,sc,bsp,ob;
    wire [31:0] oa;
    wire [8:0] da;
    wire [15:0] od,dd,p0d,p1d;
    wire [211:0] di,p1i;
    wire [63:0] ib,ks;
    wire [67:0] p0o,p1o;
    Mem_ctrl #(.IS_FIRST_COL(1)) dut(.clk(clk),.rst(rst),.busy(busy),.command_mc(mc),
        .command_P0_in(p0),.data_P0_in(data0),.command_P0_out(p0o),.data_P0_out(p0d),
        .command_P1_in(p1),.data_P1_in(data1),.inst_P1_in(inst1),
        .command_P1_out(p1o),.data_P1_out(p1d),.inst_P1_out(p1i),
        .OM_addr(oa),.OM_wen(ow),.OM_ren(orr),.OM_wr_data(od),.OM_rd_data(16'h1928),
        .OM_inst_ren(ir),.OM_inst_rd(212'd0),.DNN_addr(da),.mem_inst_wen(sc),
        .IB_wen(ib),.KSP_wen(ks),.BSP_wen(bsp),.OB_ren(ob),.DNN_wr_data(dd),
        .DNN_rd_data(16'h7711),.DNN_inst_wr(di));
    always #5 clk=~clk;
    integer checked=0,lane;
    task inactive;
        begin
            if({ow,orr,ir,sc,bsp,ob,ib,ks,p0o,p1o} !== 0)
                $fatal(1,"Stale transfer strobe/packet retained");
        end
    endtask
    task incoming(input bit port1,input integer kind,input integer bank,
                  input integer position,input integer address);
        reg [31:0] destination;
        reg [67:0] packet;
        reg [63:0] expected_ib,expected_ks;
        bit expected_sc,expected_bsp;
        reg [15:0] expected_data;
        begin
            destination=(kind==2 || kind==3 || kind==4) ? 32'h00012000+address :
                        (bank << 16)+(position << 9)+address;
            packet={kind[3:0],32'd0,destination};
            @(negedge clk); #1;
            if(port1) p1=packet; else p0=packet;
            @(posedge clk); #1;
            if(!busy) $fatal(1,"Incoming request not accepted");
            expected_data=port1 ? data1 : data0;
            if(kind==2 || kind==3 || kind==4) begin
                if(!ow || oa !== destination || od !== expected_data || {sc,bsp,ib,ks} !== 0)
                    $fatal(1,"Incoming OM packet mismatch");
            end else begin
                expected_ib=0; expected_ks=0; expected_sc=0; expected_bsp=0;
                case(bank)
                    1: expected_ib=64'b1 << position;
                    2: expected_ks=64'b1 << position;
                    3: expected_bsp=1;
                    5: expected_sc=1;
                endcase
                if({sc,bsp,ib,ks} !== {expected_sc,expected_bsp,expected_ib,expected_ks} ||
                   da !== address[8:0] || dd !== expected_data || ow || orr || ob || ir)
                    $fatal(1,"Incoming DNN packet mismatch bank=%0d lane=%0d",bank,position);
                if(expected_sc && di !== inst1) $fatal(1,"Incoming instruction data mismatch");
            end
            if(p0o!=0 || p1o!=0) $fatal(1,"Incoming transfer leaked outgoing command");
            @(negedge clk); #1; p0=0; p1=0;
            @(posedge clk); #1; inactive();
            @(posedge clk); #1; inactive();
            if(busy) $fatal(1,"Incoming request did not finish");
            checked=checked+1;
        end
    endtask
    initial begin
        repeat(2) @(negedge clk); #1; rst=0;
        incoming(0,2,0,0,4); incoming(1,3,0,0,7); incoming(1,4,0,0,9);
        for(lane=0;lane<64;lane=lane+1) incoming(0,7,1,lane,511-lane);
        incoming(0,7,2,63,2); incoming(0,7,3,0,3);
        incoming(1,8,1,31,4); incoming(1,8,2,0,5); incoming(1,8,3,0,6);
        incoming(1,8,5,0,7);
        incoming(1,6,1,1,8); incoming(1,6,2,32,9);
        incoming(1,6,3,0,10); incoming(1,6,5,0,11);
        // Asynchronous reset must clear pending state and decoded write strobes.
        @(negedge clk); #1; p0={4'd7,32'd0,32'h00010003};
        @(posedge clk); #1; if(ib==0) $fatal(1,"Abort fixture not active");
        rst=1; p0=0; #1; inactive();
        if(busy) $fatal(1,"Reset retained a busy transfer");
        @(negedge clk); #1; rst=0;
        incoming(1,8,5,0,12);
        $display("MEM_CTRL_RESULT incoming_packets=%0d lanes=64 errors=0",checked);
        $display("TEST_PASS: incoming P0/P1, OM/IB/KSP/BSP/SC, broadcast packets, inactive defaults and reset abort");
        $finish;
    end
    initial begin #100000; $fatal(1,"Memory-controller test timeout"); end
endmodule
