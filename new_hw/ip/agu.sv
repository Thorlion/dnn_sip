module agu # (
    parameter ADDRESS_WIDTH = 10,
    parameter REG_WIDTH = 16
)(
    input logic [ADDRESS_WIDTH:0] i_ib_addr,
    input logic [ADDRESS_WIDTH:0] i_ksp_addr,
    input logic [ADDRESS_WIDTH:0] i_osp_addr,
    input logic [ADDRESS_WIDTH:0] i_bsp_addr,

    input logic [REG_WIDTH-1:0] i_input_size,
    input logic [REG_WIDTH-1:0] i_stride,
    input logic [REG_WIDTH-1:0] i_weight_size,

    input logic       i_ib_sign,
    input logic [4:0] i_ib_offset,

    output logic [ADDRESS_WIDTH:0] o_ib_addr,
    output logic [ADDRESS_WIDTH:0] o_ksp_addr,
    output logic [ADDRESS_WIDTH:0] o_osp_addr,
    output logic [ADDRESS_WIDTH:0] o_bsp_addr
);


always_comb begin
    o_ib_addr = i_ib_sign ? i_ib_addr - i_ib_offset : i_ib_addr + i_ib_offset;
    o_ksp_addr = i_ksp_addr < (i_weight_size * i_weight_size) ? i_ksp_addr + 1 : 0;
end
endmodule
