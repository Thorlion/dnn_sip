`timescale 1ns/1ps

// Exercise the packed instruction's SET and LOOP fields through IF and AGU.
module agu_loop_tb;
    logic r_clk = 1'b0;
    logic r_rst_n = 1'b0;
    logic r_issue = 1'b0;
    logic [63:0] r_instruction = '0;
    logic [8:0] r_pc = '0;
    logic [5:0] w_count;
    logic [2:0] w_set_context, w_loop_context;
    logic w_pc_load;
    logic [8:0] w_pc_target;
    integer r_log;

    always #5 r_clk = ~r_clk;

    dec_if u_decode (
        .i_instruction(r_instruction),
        .o_set_iteration(w_count),
        .o_set_breakpoint(w_set_context), .o_conditional_loop(w_loop_context),
        .o_ob_switch(), .o_osp_mux_sel(), .o_done(), .o_row_done(),
        .o_ib_switch(), .o_ib_clear(), .o_ib_sign(), .o_ib_offset(),
        .o_ksp_switch(), .o_ksp_sign(), .o_ksp_offset(),
        .o_osp_clear(), .o_osp_sign(), .o_osp_offset(),
        .o_bsp_clear(), .o_bsp_sign(), .o_bsp_offset(),
        .o_load_ib(), .o_load_ksp(), .o_load_osp(), .o_load_bsp()
    );

    agu u_agu (
        .i_clk(r_clk), .i_rst_n(r_rst_n), .i_addr_en(r_issue), .i_store_ob(1'b0),
        .i_set_iteration(w_count), .i_set_breakpoint(w_set_context),
        .i_conditional_loop(w_loop_context), .i_pc(r_pc),
        .i_ib_clear(1'b0), .i_ib_sign(1'b0), .i_ib_offset(3'd0),
        .i_ksp_sign(1'b0), .i_ksp_offset(7'd0),
        .i_osp_clear(1'b0), .i_osp_sign(1'b0), .i_osp_offset(9'd0),
        .i_bsp_clear(1'b0), .i_bsp_sign(1'b0), .i_bsp_offset(3'd0),
        .o_ib_addr(), .o_ksp_addr(), .o_osp_addr(), .o_bsp_addr(), .o_ob_addr(),
        .o_pc_load(w_pc_load), .o_pc_target(w_pc_target)
    );

    task automatic apply_loop(
        input logic [2:0] i_set_context, i_loop_context,
        input logic [5:0] i_count,
        input logic [8:0] i_pc,
        input logic i_issue, i_expected_load,
        input logic [8:0] i_expected_target
    );
        @(negedge r_clk);
        r_instruction = '0;
        r_instruction[56:51] = i_count;
        r_instruction[43:41] = i_set_context;
        r_instruction[40:38] = i_loop_context;
        r_pc = i_pc;
        r_issue = i_issue;
        #1;
        if (w_pc_load !== i_expected_load || w_pc_target !== i_expected_target)
            $fatal(1, "SET=%0d LOOP=%0d expected load=%0b target=%0d got load=%0b target=%0d",
                   i_set_context, i_loop_context, i_expected_load, i_expected_target,
                   w_pc_load, w_pc_target);
    endtask

`ifdef ENABLE_WAVES
    initial begin
        $dumpfile("agu_loop.vcd");
        $dumpvars(0, agu_loop_tb);
    end
`endif

    initial begin
        repeat (2) @(negedge r_clk);
        r_rst_n = 1'b1;
        apply_loop(3'd0, 3'd7, 6'd0, 9'd0, 1'b1, 1'b0, 9'd0);

        // Each context keeps its own target and count.
        for (int w_index = 1; w_index <= 7; w_index++)
            apply_loop(3'(w_index), 3'd0, 6'd1, 9'(16*w_index), 1'b1, 1'b0, 9'd0);
        for (int w_index = 1; w_index <= 7; w_index++) begin
            apply_loop(3'd0, 3'(w_index), 6'd0, 9'd0, 1'b1, 1'b1, 9'(16*w_index+1));
            apply_loop(3'd0, 3'(w_index), 6'd0, 9'd0, 1'b1, 1'b0, 9'(16*w_index+1));
        end

        // SET context 5 and decrement context 6 on the same edge.
        apply_loop(3'd6, 3'd0, 6'd1, 9'h100, 1'b1, 1'b0, 9'd0);
        apply_loop(3'd5, 3'd6, 6'd2, 9'h120, 1'b1, 1'b1, 9'h101);
        apply_loop(3'd0, 3'd6, 6'd0, 9'd0, 1'b1, 1'b0, 9'h101);
        apply_loop(3'd0, 3'd5, 6'd0, 9'd0, 1'b1, 1'b1, 9'h121);
        apply_loop(3'd0, 3'd5, 6'd0, 9'd0, 1'b1, 1'b1, 9'h121);
        apply_loop(3'd0, 3'd5, 6'd0, 9'd0, 1'b1, 1'b0, 9'h121);

        // The old target drives a simultaneous branch. SET wins the update.
        apply_loop(3'd7, 3'd0, 6'd1, 9'h1ff, 1'b1, 1'b0, 9'd0);
        apply_loop(3'd7, 3'd7, 6'd2, 9'h135, 1'b1, 1'b1, 9'd0);
        apply_loop(3'd7, 3'd7, 6'd0, 9'd0, 1'b0, 1'b0, 9'h136);
        apply_loop(3'd0, 3'd7, 6'd0, 9'd0, 1'b1, 1'b1, 9'h136);
        apply_loop(3'd0, 3'd7, 6'd0, 9'd0, 1'b1, 1'b1, 9'h136);
        apply_loop(3'd0, 3'd7, 6'd0, 9'd0, 1'b1, 1'b0, 9'h136);

        r_log = $fopen("agu_loop_result.log", "w");
        if (r_log == 0) $fatal(1, "Cannot open agu_loop_result.log");
        $fdisplay(r_log, "AGU_LOOP_TB_PASS");
        $fclose(r_log);
        $display("AGU_LOOP_TB_PASS");
        $finish;
    end
endmodule
