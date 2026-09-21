module regs #(
    parameter DATA_W = 16
)(
    input  logic                clk,
    input  logic                rst,
    input  logic                wen,
    input  logic [DATA_W-1:0]   din,

    output logic [DATA_W-1:0]   dout
);

    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            dout <= '0;
        end else begin
            if (wen) begin
                dout <= din;
            end 
        end
    end
endmodule