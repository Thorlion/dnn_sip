module BranchDecision #(
    parameter DATA_W= 32
)(
    input  logic [DATA_W-1:0]   ra_rd_data,
    input  logic                    br,
    input  logic                    cbr,

    output logic PC_sel
);
    always_comb begin
        if (br) begin
            PC_sel = 1'b1;
        end else if (ra_rd_data != 0 && cbr) begin
            PC_sel = 1'b1;
        end else begin
            PC_sel = '0;
        end
    end
endmodule