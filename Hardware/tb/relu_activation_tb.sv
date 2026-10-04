`timescale 1ns/1ps
// Focused activation-stage test: force upstream data/control boundaries only.
// Real bias addition, input register, ReLU and NOL register are all exercised.
// Public-port X-loop/store/END coverage remains in posedge_flow_tb.
module relu_activation_tb;
    reg clk=0, rst=1;
    DNN_Core dut(.clk(clk),.rst(rst),.start(1'b0),
        .DC_write_en(1'b0),.DC_addr_w(9'b0),.DC_inst_w(212'b0),
        .en_write_IB(64'b0),.en_write_KSP(64'b0),.en_write_BSP(1'b0),
        .IB_wr_addr(9'b0),.KSP_wr_addr(9'b0),.BSP_wr_addr(9'b0),
        .data_write(16'b0),.en_C_read_OB(1'b0),.OB_MC_rd_addr(9'b0));
    DNN_Core_debug debug_dut(.clk(clk),.rst(rst),.start(1'b0),
        .DC_write_en(1'b0),.DC_addr_w(9'b0),.DC_inst_w(212'b0),
        .en_write_IB(64'b0),.en_write_KSP(64'b0),.en_write_BSP(1'b0),
        .IB_wr_addr(9'b0),.KSP_wr_addr(9'b0),.BSP_wr_addr(9'b0),
        .data_write(16'b0),.en_C_read_OB(1'b0),.OB_MC_rd_addr(9'b0));
    always #5 clk=~clk;

    reg [15:0] osp_data=0, fc_data=0, bias=0;
    reg [5:0] conv_control=0, valid=0;
    reg [8:0] nl_control=0;
    reg [15:0] expected_input=0, expected_nol=0;
    integer value, select_mode, lut_bit, checked=0;

    function [15:0] relu(input [15:0] x);
        relu=x[15] ? 16'd0 : x;
    endfunction

    task sample_and_check;
        reg [15:0] next_input, next_nol;
        begin
            // NOL consumes the previous input-register value on this edge.
            next_input=valid[2] ? ((conv_control[0] ? fc_data : osp_data)+bias) : expected_input;
            next_nol=valid[3] ? relu(expected_input) : expected_nol;
            @(posedge clk); #1;
            if(dut.ACT_NL_read !== next_input || debug_dut.ACT_NL_read !== next_input)
                $fatal(1,"Activation input alignment/bias mismatch checked=%0d",checked);
            if(dut.NOL_read !== next_nol || debug_dut.NOL_read !== next_nol)
                $fatal(1,"ReLU/NOL mismatch checked=%0d got=%h expected=%h",checked,dut.NOL_read,next_nol);
            if(dut.relu_data_out !== relu(next_input) || debug_dut.relu_data_out !== relu(next_input))
                $fatal(1,"Combinational signed ReLU mismatch input=%h",next_input);
            expected_input=next_input; expected_nol=next_nol; checked=checked+1;
        end
    endtask

    initial begin
        force dut.MLOM_read=osp_data; force debug_dut.MLOM_read=osp_data;
        force dut.MLFC_read=fc_data; force debug_dut.MLFC_read=fc_data;
        force dut.MLB_read=bias; force debug_dut.MLB_read=bias;
        force dut.CONV_slot4=conv_control; force debug_dut.CONV_slot4=conv_control;
        force dut.NL_slot5=nl_control; force debug_dut.NL_slot5=nl_control;
        force dut.pipe_valid=valid; force debug_dut.pipe_valid=valid;
        repeat(2) @(negedge clk);
        #1; rst=0; valid=6'b001100;
        // Every 16-bit activation input for both bias sources and BOTH former
        // LUT-select values. Varied biases also exercise signed overflow/wrap.
        for(select_mode=0;select_mode<2;select_mode=select_mode+1)
            for(lut_bit=0;lut_bit<2;lut_bit=lut_bit+1)
                for(value=0;value<65536;value=value+1) begin
                    conv_control=select_mode;
                    nl_control={lut_bit[0],8'd0};
                    bias=(value*251+37);
                    if(select_mode==0) begin osp_data=value-bias; fc_data=~osp_data; end
                    else begin fc_data=value-bias; osp_data=~fc_data; end
                    sample_and_check();
                    @(negedge clk); #1;
                end
        // Drain the last activation without replacing its input register.
        valid=6'b001000; sample_and_check(); @(negedge clk); #1;
        valid=0; osp_data=16'h7fff; fc_data=16'h8000; bias=16'hffff;
        repeat(4) begin sample_and_check(); @(negedge clk); #1; end
        // Input-valid alone must not update NOL; output-valid later consumes it.
        valid=6'b000100; conv_control=0; osp_data=16'h7fff; bias=0;
        sample_and_check(); @(negedge clk); #1;
        valid=6'b001000; sample_and_check(); @(negedge clk); #1;
        rst=1; #1;
        if(dut.ACT_NL_read !== 0 || debug_dut.ACT_NL_read !== 0 ||
           dut.NOL_read !== 0 || debug_dut.NOL_read !== 0)
            $fatal(1,"Asynchronous activation reset retained output");
        expected_input=0; expected_nol=0;
        @(negedge clk); #1; rst=0; valid=6'b001100;
        osp_data=16'h8000; bias=16'hffff; // wraps to +32767, then ReLU passes it
        sample_and_check(); @(negedge clk); #1;
        valid=6'b001000; sample_and_check();
        $display("RELU_RESULT encodings=65536 source_modes=2 former_lut_bits=2 cores=2 checks=%0d errors=0",checked);
        $display("TEST_PASS: ReLU, bias wrap, source selection, exact latency, valid holds and reset");
        $finish;
    end
    initial begin #3000000; $fatal(1,"ReLU test timeout"); end
endmodule
