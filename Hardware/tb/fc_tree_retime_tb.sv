`timescale 1ns/1ps
// Test-only upstream boundary forces exercise the production FC reduction and
// POFC feedback with an independent modulo-16-bit arithmetic scoreboard.
module fc_tree_retime_tb;
    reg clk=0, rst=1;
    always #5 clk=~clk;
    reg [1023:0] lane_bits=0;
    reg [5:0] valid_stim=0;
    reg accumulate_stim=0;
    DNN_Core dut(.clk(clk), .rst(rst), .start(1'b0), .DC_write_en(1'b0),
        .DC_addr_w(9'b0), .DC_inst_w(212'b0), .en_write_IB(64'b0),
        .en_write_KSP(64'b0), .en_write_BSP(1'b0), .IB_wr_addr(9'b0),
        .KSP_wr_addr(9'b0), .BSP_wr_addr(9'b0), .data_write(16'b0),
        .en_C_read_OB(1'b0), .OB_MC_rd_addr(9'b0),
        .OB_data_read(), .MEM_data_read(), .dnn_done(), .OB_MC_read(),
        .addr_write_OSP_ML_out(), .addr_write_OSP_CONV_out(),
        .addr_write_FCSP_ML_out(), .addr_write_FCSP_CONV_out(),
        .addr_write_OB_ML_out(), .addr_write_OB_CONV_out(),
        .addr_read_OB_ML_out());
    genvar lane;
    generate for(lane=0;lane<64;lane=lane+1) begin : forced_lanes
        initial begin
            force dut.EOA_array[lane].EOA.dout=lane_bits[lane*16 +:16];
        end
    end endgenerate
    initial begin
        force dut.pipe_valid=valid_stim;
        force dut.sel_adder=accumulate_stim;
    end

    reg [15:0] expected_nfc=0, expected_pofc=0;
    reg [15:0] expected_partial[0:3];
    integer checks=0, accumulates=0, nfc_holds=0, pofc_holds=0, resets=0;
    integer s,g;
    reg [15:0] next_nfc;
    initial for(integer j=0;j<4;j=j+1) expected_partial[j]=0;
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            expected_nfc=0;
            expected_pofc=0;
            for(g=0;g<4;g=g+1) expected_partial[g]=0;
            resets=resets+1;
        end else begin
            // POFC captures the preceding NFC value, not this edge's new group sums.
            if(valid_stim[4]) begin
                if(accumulate_stim) begin
                    expected_pofc=expected_nfc+expected_pofc;
                    accumulates=accumulates+1;
                end else expected_pofc=expected_nfc;
            end else pofc_holds=pofc_holds+1;
            if(valid_stim[3]) begin
                next_nfc=0;
                for(g=0;g<4;g=g+1) expected_partial[g]=0;
                for(s=0;s<64;s=s+1) begin
                    next_nfc=next_nfc+lane_bits[s*16 +:16];
                    expected_partial[s/16]=expected_partial[s/16]+lane_bits[s*16 +:16];
                end
                expected_nfc=next_nfc;
            end else nfc_holds=nfc_holds+1;
        end
        #1;
        if(dut.NFC_data_rd !== expected_nfc)
            $fatal(1,"NFC mismatch check=%0d expected=%h actual=%h",
                checks,expected_nfc,dut.NFC_data_rd);
        if(dut.POFC_rd_data !== expected_pofc)
            $fatal(1,"POFC mismatch check=%0d expected=%h actual=%h",
                checks,expected_pofc,dut.POFC_rd_data);
        for(g=0;g<4;g=g+1)
            if(dut.NFC_partial_read[g] !== expected_partial[g])
                $fatal(1,"Group sum mismatch group=%0d check=%0d",g,checks);
        checks=checks+1;
    end

    reg [15:0] falling_nfc,falling_pofc;
    always @(negedge clk) begin
        falling_nfc=dut.NFC_data_rd;
        falling_pofc=dut.POFC_rd_data;
        #3;
        if(!rst && (dut.NFC_data_rd !== falling_nfc ||
                   dut.POFC_rd_data !== falling_pofc))
            $fatal(1,"Outputs changed without a rising edge");
    end

    reg [31:0] random_state=32'h1a2b3c4d;
    function [31:0] next_random(input [31:0] state);
        reg [31:0] v;
        begin
            v=state^(state<<13); v=v^(v>>17); next_random=v^(v<<5);
        end
    endfunction
    task drive(input integer mode,input [1:0] enables,input bit acc);
        integer n;
        begin
            @(negedge clk); #1;
            valid_stim={1'b0,enables[1],enables[0],3'b0};
            accumulate_stim=acc;
            for(n=0;n<64;n=n+1) begin
                case(mode)
                    0: lane_bits[n*16 +:16]=16'h0000;
                    1: lane_bits[n*16 +:16]=16'hffff;
                    2: lane_bits[n*16 +:16]=16'h7fff;
                    3: lane_bits[n*16 +:16]=16'h8000;
                    4: lane_bits[n*16 +:16]=(n%2) ? 16'h8000 : 16'h7fff;
                    5: lane_bits[n*16 +:16]=(n%16==0) ? 16'hffff : 16'h0001;
                    default: begin
                        if(mode>=100 && mode<164)
                            lane_bits[n*16 +:16]=(n==mode-100) ? 16'h8001 : 16'b0;
                        else begin
                            random_state=next_random(random_state);
                            lane_bits[n*16 +:16]=random_state[15:0];
                        end
                    end
                endcase
            end
            @(posedge clk); #2;
        end
    endtask
    initial begin
        #2; rst=0;
        for(integer mode=0;mode<6;mode=mode+1) begin
            drive(mode,2'b11,0);
            drive(mode,2'b11,1);
            drive(mode,2'b11,1);
            drive(mode,2'b01,0);
            drive(mode,2'b10,1);
            drive(mode,2'b00,0);
        end
        for(integer lane_id=0;lane_id<64;lane_id=lane_id+1) begin
            drive(100+lane_id,2'b11,0);
            drive(0,2'b10,1);
        end
        for(integer trial=0;trial<8192;trial=trial+1) begin
            random_state=next_random(random_state);
            drive(-1,random_state[1:0],random_state[2]);
            if(trial==4095) begin
                #1; rst=1; #1; rst=0;
            end
        end
        drive(1,2'b11,1);
        drive(0,2'b10,1);
        #1; rst=1; #1; rst=0;
        drive(3,2'b11,0);
        drive(5,2'b11,1);
        drive(0,2'b10,1);
        $display("FC_TREE_RETIME TEST_PASS checks=%0d accumulates=%0d nfc_holds=%0d pofc_holds=%0d reset_events=%0d",
            checks,accumulates,nfc_holds,pofc_holds,resets);
        $finish;
    end
    initial begin #100000; $fatal(1,"Equivalence timeout"); end
endmodule
