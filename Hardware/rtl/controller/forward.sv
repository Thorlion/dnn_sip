module Ctrl_forw #(
    parameter DATA_W = 32
)(
    input  logic [5:0] opcode,
    input  logic [4:0] rd_before,
    input  logic [4:0] ra,
    input  logic [4:0] rb,

    output logic sel_ra_forw,
    output logic sel_rb_forw
);
    always_comb begin
        if (opcode >=6'b000000 && opcode <= 6'b000100) begin    // OPCODE = 6'd0 - 6'd4
            if (rd_before == ra && rd_before != 0) begin
                sel_ra_forw = 1'b1; 
            end else begin
                sel_ra_forw = '0;
            end

            if (rd_before == rb && rd_before != 0) begin
                sel_rb_forw = 1'b1; 
            end else begin
                sel_rb_forw = '0;
            end
        end

        else if (opcode >=6'b000101 && opcode <=6'b001111) begin    // OPCODE = 6'd5 - 6'd15
            if (rd_before == ra && rd_before != 0) begin
                sel_ra_forw = 1'b1; 
            end else begin
                sel_ra_forw = '0;
            end

            sel_rb_forw = '0;
        end

        else begin
            sel_ra_forw = '0;
            sel_rb_forw = '0;
        end
    end
endmodule