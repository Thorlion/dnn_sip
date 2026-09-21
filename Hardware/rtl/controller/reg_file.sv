module reg_file #(
    parameter SIZE = 32,
    parameter DATA_W = 32
)(
    input  logic clk,
    input  logic rst,

    input  logic [4:0] ra,        // addr read RA
    input  logic [4:0] rb,        // addr read RB
    input  logic [4:0] rd_rd,     // addr read RD
    input  logic [4:0] rd_wr,      // addr write RD
    input  logic [4:0] rtemp,
    input  logic wen,
    input  logic [DATA_W-1:0] w_data,
    output logic [DATA_W-1:0] ra_rd_data,
    output logic [DATA_W-1:0] rb_rd_data,
    output logic [DATA_W-1:0] rd_rd_data,
    output logic [DATA_W-1:0] rtemp_rd_data
);
    logic [DATA_W-1:0] mem [0:SIZE-1];
    integer i;
    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            for (i = 0; i < SIZE; i = i + 1) begin
                mem[i] <= '0;
            end
        end else begin
            if (wen) begin
                if (rd_wr != 0) begin
                    mem[rd_wr] <= w_data;
                end else begin
                    mem[rd_wr] <= mem[rd_wr];
                end
            end
        end
    end

    assign ra_rd_data = mem[ra];
    assign rb_rd_data = mem[rb];
    assign rd_rd_data = mem[rd_rd];
    assign rtemp_rd_data = mem[rtemp];
endmodule