module LUTable1 #(
    parameter DATA_W = 16
)(
    input  logic clk,
    input  logic rst,
    input  logic [DATA_W-1:0] din,

    output logic [DATA_W*2-1:0] coordinated_0,  //[31:16]x1 [15:0]y1
    output logic [DATA_W*2-1:0] coordinated_1,  //[31:16]x2 [15:0]y2
    output logic [DATA_W-1:0] dout              // Latch din
);
    localparam DATA0 = 32'hFFFF0000;    // x = -1,      y = 0
    localparam DATA1 = 32'h80000000;    // x = -32768,  y = 0
    localparam DATA2 = 32'h0000EFFF;    // x = 0,       y = 96
    localparam DATA3 = 32'h20000060;    // x = 8192,    y = 0
    localparam DATA4 = 32'h40000100;    // x = 16384,   y = 256
    localparam DATA5 = 32'h50000000;    // x = 20480,   y = 0
    localparam DATA6 = 32'h6000F000;    // x = 24576,   y = -4096
    localparam DATA7 = 32'h70000000;    // x = 28672,   y = 0
    localparam DATA8 = 32'h7FFF0FFF;    // x = 32767,   y = 4095

    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            coordinated_0 <= '0;
            coordinated_1 <= '0;
            dout          <= '0;
        end else begin
            if (($signed(DATA0[31:16]) <= $signed(din))     &&      ($signed(din) <= $signed(DATA1[31:16]))) begin
                coordinated_0 <= DATA0;
                coordinated_1 <= DATA1;
                dout          <= din;
            end else if (($signed(DATA1[31:16]) <= $signed(din))     &&      ($signed(din) <= $signed(DATA2[31:16]))) begin
                coordinated_0 <= DATA1;
                coordinated_1 <= DATA2;
                dout          <= din;
            end else if (($signed(DATA2[31:16]) <= $signed(din))     &&      ($signed(din) <= $signed(DATA3[31:16]))) begin
                coordinated_0 <= DATA2;   
                coordinated_1 <= DATA3;
                dout          <= din;
            end else if (($signed(DATA3[31:16]) <= $signed(din))     &&      ($signed(din) <= $signed(DATA4[31:16]))) begin
                coordinated_0 <= DATA3;   
                coordinated_1 <= DATA4;
                dout          <= din;
            end else if (($signed(DATA4[31:16]) <= $signed(din))     &&      ($signed(din) <= $signed(DATA5[31:16]))) begin
                coordinated_0 <= DATA4;   
                coordinated_1 <= DATA5;
                dout          <= din;
            end else if (($signed(DATA5[31:16]) <= $signed(din))     &&      ($signed(din) <= $signed(DATA6[31:16]))) begin
                coordinated_0 <= DATA5;   
                coordinated_1 <= DATA6;
                dout          <= din;
            end else if (($signed(DATA6[31:16]) <= $signed(din))     &&      ($signed(din) <= $signed(DATA7[31:16]))) begin
                coordinated_0 <= DATA6;   
                coordinated_1 <= DATA7;
                dout          <= din;
            end else if (($signed(DATA7[31:16]) <= $signed(din))     &&      ($signed(din) <= $signed(DATA8[31:16]))) begin
                coordinated_0 <= DATA7;   
                coordinated_1 <= DATA8;
                dout          <= din;
            end else begin
                coordinated_0 <= '0;
                coordinated_1 <= '0;
                dout          <= '0;
            end    
        end
    end
endmodule