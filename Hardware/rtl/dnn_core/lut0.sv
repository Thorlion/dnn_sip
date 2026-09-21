module LUTable0 #(
    parameter DATA_W = 16
)(
    input  logic clk,
    input  logic rst,
    input  logic [DATA_W-1:0] din,

    output logic [DATA_W*2-1:0] coordinated_0,  //[31:16]x1 [15:0]y1
    output logic [DATA_W*2-1:0] coordinated_1,  //[31:16]x2 [15:0]y2
    output logic [DATA_W-1:0] dout              //Latch din
);
    // logic [DATA_W*2-1:0] data0;
    // logic [DATA_W*2-1:0] data1;
    // logic [DATA_W*2-1:0] data2;
    // logic [DATA_W*2-1:0] data3; 
    // logic [DATA_W*2-1:0] data4;

    // initial begin 
    //     data0 = 32'hFFFF0000;       
    //     data1 = 32'h80000000;       
    //     data2 = 32'h00000000;
    //     data3 = 32'h10001000;
    //     data4 = 32'h7FFF7FFF;
    // end
    localparam DATA0 = 32'hFFFF0000;    // x = -1,      y = 0
    localparam DATA1 = 32'h80000000;    // x = -32768,  y = 0
    localparam DATA2 = 32'h00000000;    // x = 0,       y = 0
    localparam DATA3 = 32'h10001000;    // x = 4096,    y = 4096
    localparam DATA4 = 32'h7FFF7FFF;    // x = 32767,   y = 32767

    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            coordinated_0   <= '0;
            coordinated_1   <= '0;
            dout            <= '0;
        end else begin
            if (($signed(DATA0[31:16]) <= $signed(din))     &&      ($signed(din) <= $signed(DATA1[31:16]))) begin
                coordinated_0   <= DATA0;
                coordinated_1   <= DATA1;
                dout            <= din;
            end else if (($signed(DATA1[31:16]) <= $signed(din))     &&      ($signed(din) <= $signed(DATA2[31:16]))) begin
                coordinated_0   <= DATA1;
                coordinated_1   <= DATA2;
                dout            <= din;
            end else if (($signed(DATA2[31:16]) <= $signed(din))     &&      ($signed(din) <= $signed(DATA3[31:16]))) begin
                coordinated_0   <= DATA2;   
                coordinated_1   <= DATA3;
                dout            <= din;
            end else if (($signed(DATA3[31:16]) <= $signed(din))     &&      ($signed(din) <= $signed(DATA4[31:16]))) begin
                coordinated_0   <= DATA3;
                coordinated_1   <= DATA4;
                dout            <= din;
            end else begin
                coordinated_0   <= '0;
                coordinated_1   <= '0;
                dout            <= '0;
            end
        end
    end
endmodule