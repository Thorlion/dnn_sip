module MemAcsCmdGen #(
    parameter DATA_W = 32
)(
    input  logic [DATA_W-1:0] base_addr_src,
    input  logic [DATA_W-1:0] base_addr_dst,
    input  logic [DATA_W-1:0] offset_addr_src,
    input  logic [DATA_W-1:0] offset_addr_dst,
    input  logic [3:0] type_access,

    output logic [67:0] cmd
);
    logic [DATA_W-1:0] addr_src;
    logic [DATA_W-1:0] addr_dst;

    always_comb begin
        addr_src = base_addr_src + offset_addr_src;
        addr_dst = base_addr_dst + offset_addr_dst;
        cmd = {type_access, addr_src, addr_dst};    //access type (load/store), select DNN mem, addr OM, addr DNN
    end
endmodule