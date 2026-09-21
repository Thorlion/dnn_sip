module mem #(
    parameter DATA_W    = 16,
    parameter DEPTH     = 512,
    parameter EN_OUT_FF = 0
)(
    input  logic                        clk,            
    input  logic                        wen, ren,           // Write/Read Enable
    input  logic [$clog2(DEPTH)-1:0]    addr_w, addr_r,      // Address
    input  logic [DATA_W-1:0]           wdata,          
    output logic [DATA_W-1:0]           rdata
);
    logic [DATA_W-1:0] memory [0:DEPTH-1];       // Mem packed array with 512 elements

    //Write
    always_ff @(posedge clk) begin
        if (wen) begin
            memory[addr_w] <= wdata;
        end
    end
    
    //Read
    generate
        if(EN_OUT_FF) begin
            always_ff @(posedge clk) begin
                if(ren) begin
                    rdata <= memory[addr_r];
                end
            end
        end else begin
            always_comb begin 
                    rdata = memory[addr_r];
            end
        end
    endgenerate
endmodule