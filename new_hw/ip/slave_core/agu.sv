// Execution address state and independent sign-and-magnitude offsets.
// Sign 0 adds the magnitude; sign 1 subtracts it. With clear=0, offset 0 holds.
// Pointer widths: IB 10, KSP 8, OSP 9, BSP 6 bits.
// Offset magnitudes: IB 3, KSP 7, OSP 9, BSP 3 bits.
// Outputs are the calculated addresses used by the current IF instruction.
// IB clear immediately overrides its output to zero, ignoring sign/offset;
// an issued instruction captures that zero as its next base.
// OSP/BSP clear loads the unsigned offset magnitude on issue while preserving
// the current counter +/- offset output. Otherwise that output is the next base.
// KSP has no clear input and always captures its calculated address on issue.
// The sign only controls the current combinational counter +/- offset output.
// Arithmetic wraps at each pointer's width.
// OB has a 10-bit sequential store pointer, advanced only by i_store_ob.
// All pointers reset to zero and retain their values across start/buffer changes.
// Kernel-loop wrap is external. The program counter also remains external.
// SBP selects context 1..7 and saves PC+1 plus the 6-bit iteration count.
// SBP=0 stores nothing. A count of zero is explicitly loadable with SBP.
// CLP selects context 1..7. Zero selects no branch. Contexts are independent.
// A branch uses the pre-edge target/count. If SBP and CLP select the same
// context, loading its new target/count takes priority over decrementing it.
// Count N permits N taken loop-back jumps; zero disables a loop-back jump.
// Drive flow-control fields to zero on cycles without an issued instruction.
module agu # (
    parameter int unsigned PC_W = 9
)(
    input logic i_clk,
    input logic i_rst_n,
    input logic i_addr_en,
    input logic i_store_ob,
    input logic [5:0] i_set_iteration,
    input logic [2:0] i_set_breakpoint,
    input logic [2:0] i_conditional_loop,
    input logic [PC_W-1:0] i_pc,

    input logic       i_ib_clear,
    input logic       i_ib_sign,
    input logic [2:0] i_ib_offset,
    input logic       i_ksp_sign,
    input logic [6:0] i_ksp_offset,
    input logic       i_osp_clear,
    input logic       i_osp_sign,
    input logic [8:0] i_osp_offset,
    input logic       i_bsp_clear,
    input logic       i_bsp_sign,
    input logic [2:0] i_bsp_offset,

    output logic [9:0] o_ib_addr,
    output logic [7:0] o_ksp_addr,
    output logic [8:0] o_osp_addr,
    output logic [5:0] o_bsp_addr,
    output logic [9:0] o_ob_addr,
    output logic o_pc_load,
    output logic [PC_W-1:0] o_pc_target
);
    localparam int unsigned LOOP_CONTEXTS = 7;
    logic [5:0] r_iteration_count [1:LOOP_CONTEXTS];
    logic [PC_W-1:0] r_breakpoint [1:LOOP_CONTEXTS];
    logic [9:0] r_ib_addr;
    logic [7:0] r_ksp_addr;
    logic [8:0] r_osp_addr;
    logic [5:0] r_bsp_addr;
    logic [9:0] r_ob_addr;

    // IF address feedback and the later NL Store OB event are independent.
    // OB presents the current store address before incrementing on the edge.
    assign o_ob_addr = r_ob_addr;
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_ib_addr <= '0;
            r_ksp_addr <= '0;
            r_osp_addr <= '0;
            r_bsp_addr <= '0;
            r_ob_addr <= '0;
        end else begin
            if (i_addr_en) begin
                r_ib_addr <= o_ib_addr;
                r_ksp_addr <= o_ksp_addr;
                r_osp_addr <= i_osp_clear ? i_osp_offset : o_osp_addr;
                r_bsp_addr <= i_bsp_clear ? {3'd0, i_bsp_offset} : o_bsp_addr;
            end
            if (i_store_ob)
                r_ob_addr <= r_ob_addr + 1'b1;
        end
    end

    // Use the pre-edge counter for both the branch request and decrement.
    always_comb begin
        o_pc_load = 1'b0;
        o_pc_target = '0;
        if (i_conditional_loop != 3'd0) begin
            o_pc_load = i_addr_en && (r_iteration_count[i_conditional_loop] != 6'd0);
            o_pc_target = r_breakpoint[i_conditional_loop];
        end
    end

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            for (int w_loop = 1; w_loop <= LOOP_CONTEXTS; w_loop++) begin
                r_iteration_count[w_loop] <= 6'd0;
                r_breakpoint[w_loop] <= '0;
            end
        end else if (i_addr_en) begin
            for (int w_loop = 1; w_loop <= LOOP_CONTEXTS; w_loop++) begin
                if (i_set_breakpoint == 3'(w_loop)) begin
                    r_iteration_count[w_loop] <= i_set_iteration;
                    r_breakpoint[w_loop] <= i_pc + 1'b1;
                end else if (o_pc_load && (i_conditional_loop == 3'(w_loop))) begin
                    r_iteration_count[w_loop] <= r_iteration_count[w_loop] - 6'd1;
                end
            end
        end
    end

    always_comb begin
        o_ib_addr = i_ib_clear ? 10'd0 :
                    (i_ib_sign ? r_ib_addr - {7'd0, i_ib_offset} :
                                 r_ib_addr + {7'd0, i_ib_offset});
        o_ksp_addr = i_ksp_sign ? r_ksp_addr - {1'b0, i_ksp_offset} :
                                 r_ksp_addr + {1'b0, i_ksp_offset};
        o_osp_addr = i_osp_sign ? r_osp_addr - i_osp_offset : r_osp_addr + i_osp_offset;
        o_bsp_addr = i_bsp_sign ? r_bsp_addr - {3'd0, i_bsp_offset} :
                                 r_bsp_addr + {3'd0, i_bsp_offset};
    end
endmodule
