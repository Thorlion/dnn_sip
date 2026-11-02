// Independent sign-and-magnitude offsets for IB, KSP, OSP and BSP.
// Sign 0 adds the magnitude; sign 1 subtracts it. Offset 0 holds.
// Magnitude widths: IB 10 bits, KSP/OSP 9 bits, BSP 6 bits.
// Arithmetic wraps at the address-port width. Kernel-loop wrap is external.
// Flow-control state is held here; the program counter remains external.
// A nonzero iteration field loads the 5-bit counter and takes priority over CLP.
// SBP independently saves PC+1. CLP uses the previously stored breakpoint/count.
// Count N permits N taken loop-back jumps; zero disables a loop-back jump.
// Drive flow-control fields to zero on cycles without an issued instruction.
module agu # (
    parameter ADDRESS_WIDTH = 10,
    parameter int unsigned PC_W = 9
)(
    input logic i_clk,
    input logic i_rst_n,
    input logic [4:0] i_set_iteration,
    input logic i_set_breakpoint,
    input logic i_conditional_loop,
    input logic [PC_W-1:0] i_pc,

    input logic [ADDRESS_WIDTH:0] i_ib_addr,
    input logic [ADDRESS_WIDTH:0] i_ksp_addr,
    input logic [ADDRESS_WIDTH:0] i_osp_addr,
    input logic [ADDRESS_WIDTH:0] i_bsp_addr,

    input logic       i_ib_sign,
    input logic [9:0] i_ib_offset,
    input logic       i_ksp_sign,
    input logic [8:0] i_ksp_offset,
    input logic       i_osp_sign,
    input logic [8:0] i_osp_offset,
    input logic       i_bsp_sign,
    input logic [5:0] i_bsp_offset,

    output logic [ADDRESS_WIDTH:0] o_ib_addr,
    output logic [ADDRESS_WIDTH:0] o_ksp_addr,
    output logic [ADDRESS_WIDTH:0] o_osp_addr,
    output logic [ADDRESS_WIDTH:0] o_bsp_addr,
    output logic o_pc_load,
    output logic [PC_W-1:0] o_pc_target
);
    logic [4:0] r_iteration_count;
    logic [PC_W-1:0] r_breakpoint;

    // Use the pre-edge counter for both the branch request and decrement.
    assign o_pc_load = i_conditional_loop && (r_iteration_count != 5'd0);
    assign o_pc_target = r_breakpoint;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_iteration_count <= 5'd0;
            r_breakpoint <= '0;
        end else begin
            if (i_set_iteration != 5'd0)
                r_iteration_count <= i_set_iteration;
            else if (o_pc_load)
                r_iteration_count <= r_iteration_count - 5'd1;

            if (i_set_breakpoint)
                r_breakpoint <= i_pc + 1'b1;
        end
    end

always_comb begin
    o_ib_addr = i_ib_sign ? i_ib_addr - i_ib_offset : i_ib_addr + i_ib_offset;
    o_ksp_addr = i_ksp_sign ? i_ksp_addr - i_ksp_offset : i_ksp_addr + i_ksp_offset;
    o_osp_addr = i_osp_sign ? i_osp_addr - i_osp_offset : i_osp_addr + i_osp_offset;
    o_bsp_addr = i_bsp_sign ? i_bsp_addr - i_bsp_offset : i_bsp_addr + i_bsp_offset;
end
endmodule
