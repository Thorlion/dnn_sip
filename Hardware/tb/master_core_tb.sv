`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/10/2025 11:01:18 PM
// Design Name: 
// Module Name: master_core_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module master_core_tb;
parameter INSTRUCTION_WIDTH = 32;
parameter MCMEM_SIZE = 1024;
parameter DATA_WIDTH = 32;
parameter ADDR_WIDTH = 32;

bit clk;                         // clock   
bit rst;                         // reset
bit start;                       // tin hieu kich hoat cac ASIP hoat dong
                     

bit DNN_done;                    // tin hieu hoan thanh cong viec tu DNN core
wire start_DNN_core;              // tin hieu kich hoat DNN core hoat dong
wire ASIP_done;                    // tin hieu cho biet ASIP da hoan tat cong viec
//wire [65:0] command;                    // lenh truy cap bo nho
bit wen_MCMem;
bit [$clog2(MCMEM_SIZE)-1:0] addr_w_MCMem;
bit [DATA_WIDTH-1:0] data_w_MCMem;

wire [ADDR_WIDTH-1:0] addr_r_OM_out;     // dia chi doc OM
wire [ADDR_WIDTH-1:0] addr_w_OM_out;     // dia chi ghi OM
wire wen_OM_out;                         // tin hieu cho phep ghi vao OM
wire ren_OM_out;                         // tin hieu cho phep doc tu OM

wire wen_DNN_mem_inst_out;               // tin hieu cho phep ghi vao DNN instruction mem
wire [127:0] wen_IB_out;                 // tin hieu cho phep ghi vao IB
wire [127:0] wen_KSP_out;                // tin hieu cho phep ghi vao KSP
wire wen_BSP_out;                        // tin hieu cho phep ghi vao BSP
wire ren_OB_out;                         // tin hieu cho phep doc tu OB
wire [8:0] addr_r_DNN_out;               // dia chi doc DNN
wire [8:0] addr_w_DNN_out;                // dia chi ghi DNN



bit [15:0] dinmemtest;
wire [15:0] doutmemtest;

bit vsync_in;  
bit hsync_in;                       
bit all_DNN_done_signal;                   // = all DNN_done_signal
wire vsync_out;                         // tin hieu vsync de dong bo cac DSIP subsequence
wire start_DNN_core;
wire end_flag;

always #5 clk = ~clk;

initial begin
    rst = 1;
    #400
    rst = 0;
    wen_MCMem = 1;
    addr_w_MCMem = 0;
    data_w_MCMem = 32'b001110_00001_00000_0000000000000011;     //MOV R1, 3
    #10
    addr_w_MCMem = 1;
    data_w_MCMem = 32'b001110_00010_00000_0000000000001000;     //MOV R2, 8            
    #10
    addr_w_MCMem = 2;
    data_w_MCMem = 32'b000101_00001_00001_00000_00000_000000;   // INC R1, R1       -> R1 = 4
    #10
    addr_w_MCMem = 3;
    data_w_MCMem = 32'b000000_00011_00001_00010_00000_000000;   //ADD R3, R1, R2    -> R3 = 12
    #10
    addr_w_MCMem = 4;
    data_w_MCMem = 32'b001111_00100_00100_0000000000000011;   //R4 = R4 | (1<<16)   -> R4 = 0x00010000
    #10
    addr_w_MCMem = 5;
    data_w_MCMem = 32'b001110_00101_00000_0000000000001000;   //R5 = 8 
    #10
    addr_w_MCMem = 6;
    data_w_MCMem = 32'h00000000;   //nop 
    #10
    addr_w_MCMem = 7;
    data_w_MCMem = 32'b010001_00101_00000_00100_00000_000000;   //OFML R5, R0, R4, R0
    
    #10
    addr_w_MCMem = 8;
    data_w_MCMem = 32'b010110_00000000000000000000000000;       // VSYNC 
    
    #10
    addr_w_MCMem = 9;
    data_w_MCMem = 32'b010101_00000000000000000000000000;       // START_DNN_CORE 
    
    #10
    wen_MCMem = 0;
    #10
    start = 1;
    #200
    vsync_in = 1;
    #10
    start = 0;
end


reg [31:0] OM_simulation_mem [0:1023];
initial begin
    OM_simulation_mem[8] = 100;
end
always @(posedge clk) begin
    if(ren_OM_out) dinmemtest <= OM_simulation_mem[addr_r_OM_out];
end

master_core#(.INSTRUCTION_WIDTH(INSTRUCTION_WIDTH),
             .MCMEM_SIZE(MCMEM_SIZE),
             .DATA_WIDTH(DATA_WIDTH),
             .ADDR_WIDTH(ADDR_WIDTH)) mc(.clk(clk),
                                         .rst(rst),
                                         .start(start),
//                                         .hsync(hsync),
//                                         .vsync(vsync),
//                                         .DNN_done(DNN_done),
//                                         .start_DNN_core(start_DNN_core),
                                         .ASIP_done(ASIP_done),
                                         .wen_MCMem(wen_MCMem),
                                         .addr_w_MCMem(addr_w_MCMem),
                                         .data_w_MCMem(data_w_MCMem),
    
                                        .addr_r_OM_out(addr_r_OM_out),     // dia chi doc OM
                                        .addr_w_OM_out(addr_w_OM_out),     // dia chi ghi OM
                                        .wen_OM_out(wen_OM_out),                         // tin hieu cho phep ghi vao OM
                                        .ren_OM_out(ren_OM_out),                         // tin hieu cho phep doc tu OM
                                        
                                        .wen_DNN_mem_inst_out(wen_DNN_mem_inst_out),               // tin hieu cho phep ghi vao DNN instruction mem
                                        .wen_IB_out(wen_IB_out),                 // tin hieu cho phep ghi vao IB
                                        .wen_KSP_out(wen_KSP_out),                // tin hieu cho phep ghi vao KSP
                                        .wen_BSP_out(wen_BSP_out),                        // tin hieu cho phep ghi vao BSP
                                        .ren_OB_out(ren_OB_out),                        // tin hieu cho phep doc tu OB
                                        .addr_r_DNN_out(addr_r_DNN_out),               // dia chi doc DNN
                                        .addr_w_DNN_out(addr_w_DNN_out),                // dia chi ghi DNN
                                        
                                        
                                        .dinmemtest(dinmemtest),
                                        .doutmemtest(doutmemtest),
                                        
                                        .vsync_in(vsync_in),
                                        .hsync_in(hsync_in),
                                        .all_DNN_done_signal(all_DNN_done_signal),
                                        .vsync_out(vsync_out),
                                        .start_DNN_core(start_DNN_core),
                                        .end_flag(end_flag)
);                                        

endmodule
