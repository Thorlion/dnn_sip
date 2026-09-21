`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/10/2025 09:36:31 PM
// Design Name: 
// Module Name: ASIP_two_two_tb
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
`define SINGLE 1
`define ONE_ONE 2
`define TWO_TWO 3

module ASIP_two_two_tb;
// Parameters
parameter INSTRUCTION_WIDTH = 32;
parameter MCMEM_SIZE = 4096;
parameter DATA_WIDTH_MC = 32;
parameter ADDR_WIDTH = 32;
parameter DATA_WIDTH_DNN_CORE = 16;
parameter DECIMAL_BIT = 8;
parameter INSTRUCTION_WIDTH_DNN_CORE = 212;
parameter BUFFER_SIZE = 512;
parameter SCRATCHPAD_SIZE = 512;
parameter BLOCKS_PER_ROW = 64;
parameter MODEL = `TWO_TWO;
parameter IS_FIRST_ROW = 1;
parameter IS_FIRST_COL = 1;
parameter BASE_DATA_OM = 32'h00010000;      // phân vùng giữa OM chứa instruction và OM chứa data (data bắt đầu từ 0x00010000)



// Inputs
bit clk;
bit rst;
bit start;

// Memory write ports
bit wen_MCMem_00, wen_MCMem_01, wen_MCMem_10, wen_MCMem_11;
bit [$clog2(MCMEM_SIZE)-1:0] addr_w_MCMem_00, addr_w_MCMem_01, addr_w_MCMem_10, addr_w_MCMem_11;
bit [INSTRUCTION_WIDTH-1:0] data_w_MCMem_00, data_w_MCMem_01, data_w_MCMem_10, data_w_MCMem_11;

// Sync signals
bit vsync_in_00, vsync_in_01, vsync_in_10, vsync_in_11;
bit hsync_in_00, hsync_in_01, hsync_in_10, hsync_in_11;
wire vsync_out_00, vsync_out_01, vsync_out_10, vsync_out_11;
wire hsync_out_00, hsync_out_01, hsync_out_10, hsync_out_11;
wire start_DNN_core_00, start_DNN_core_01, start_DNN_core_10, start_DNN_core_11;
wire end_flag_00, end_flag_01, end_flag_10, end_flag_11;

// PORT0
bit [67:0] command_P0_in_00, command_P0_in_01, command_P0_in_10, command_P0_in_11;
bit [15:0] data_P0_in_00, data_P0_in_01, data_P0_in_10, data_P0_in_11;
wire [67:0] command_P0_out_00, command_P0_out_01, command_P0_out_10, command_P0_out_11;
wire [15:0] data_P0_out_00, data_P0_out_01, data_P0_out_10, data_P0_out_11;

// PORT1
bit [67:0] command_P1_in_00, command_P1_in_01, command_P1_in_10, command_P1_in_11;
bit [15:0] data_P1_in_00, data_P1_in_01, data_P1_in_10, data_P1_in_11;
bit [211:0] inst_P1_in_00, inst_P1_in_01, inst_P1_in_10, inst_P1_in_11;
wire [67:0] command_P1_out_00, command_P1_out_01, command_P1_out_10, command_P1_out_11;
wire [15:0] data_P1_out_00, data_P1_out_01, data_P1_out_10, data_P1_out_11;
wire [211:0] inst_P1_out_00, inst_P1_out_01, inst_P1_out_10, inst_P1_out_11;

// OM port
wire [31:0] addr_OM_00, addr_OM_01, addr_OM_10, addr_OM_11;
wire wen_OM_00, wen_OM_01, wen_OM_10, wen_OM_11;
wire ren_OM_00, ren_OM_01, ren_OM_10, ren_OM_11;
bit [15:0] data_r_OM_00, data_r_OM_01, data_r_OM_10, data_r_OM_11;
wire [15:0] data_w_OM_00, data_w_OM_01, data_w_OM_10, data_w_OM_11;
wire ren_OM_inst_00, ren_OM_inst_01, ren_OM_inst_10, ren_OM_inst_11;
bit [211:0] inst_r_OM_00, inst_r_OM_01, inst_r_OM_10, inst_r_OM_11;

// DNN Core
wire [8:0] addr_DNN_00, addr_DNN_01, addr_DNN_10, addr_DNN_11;
wire wen_inst_mem_00, wen_inst_mem_01, wen_inst_mem_10, wen_inst_mem_11;
wire [63:0] wen_IB_00, wen_IB_01, wen_IB_10, wen_IB_11;
wire [63:0] wen_KSP_00, wen_KSP_01, wen_KSP_10, wen_KSP_11;
wire wen_BSP_00, wen_BSP_01, wen_BSP_10, wen_BSP_11;
wire ren_OB_00, ren_OB_01, ren_OB_10, ren_OB_11;
wire [31:0] data_w_DNN_00, data_w_DNN_01, data_w_DNN_10, data_w_DNN_11;
wire [211:0] inst_w_DNN_00, inst_w_DNN_01, inst_w_DNN_10, inst_w_DNN_11;
bit done_transfer_prev_00, done_transfer_prev_01, done_transfer_prev_10, done_transfer_prev_11;
wire done_transfer_00, done_transfer_01, done_transfer_10, done_transfer_11;
wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_write_OB_00, addr_write_OB_01, addr_write_OB_10, addr_write_OB_11;
wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_read_OB_00, addr_read_OB_01, addr_read_OB_10, addr_read_OB_11;
bit [7:0] select_00, select_01, select_10, select_11;   //DEBUG
wire [DATA_WIDTH_DNN_CORE - 1 : 0] NEOA_read_out_00, NEOA_read_out_01, NEOA_read_out_10, NEOA_read_out_11;
wire sel_lut_00, sel_lut_01, sel_lut_10, sel_lut_11;
wire [DATA_WIDTH_DNN_CORE - 1 : 0] li_data_out_00, li_data_out_01, li_data_out_10, li_data_out_11;
wire [DATA_WIDTH_DNN_CORE - 1 : 0] POA_read_out_00, POA_read_out_01, POA_read_out_10, POA_read_out_11;
wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_write_OSP_ML_out_00, addr_write_OSP_ML_out_01, addr_write_OSP_ML_out_10, addr_write_OSP_ML_out_11;
wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_write_OSP_CONV_out_00, addr_write_OSP_CONV_out_01, addr_write_OSP_CONV_out_10, addr_write_OSP_CONV_out_11;
wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_write_FCSP_ML_out_00, addr_write_FCSP_ML_out_01, addr_write_FCSP_ML_out_10, addr_write_FCSP_ML_out_11;
wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_write_OB_ML_out_00, addr_write_OB_ML_out_01, addr_write_OB_ML_out_10, addr_write_OB_ML_out_11;
wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_read_OB_ML_out_00, addr_read_OB_ML_out_01, addr_read_OB_ML_out_10, addr_read_OB_ML_out_11;
wire [DATA_WIDTH_DNN_CORE - 1 : 0] OB_read_out_00, OB_read_out_01, OB_read_out_10, OB_read_out_11;
wire [DATA_WIDTH_DNN_CORE - 1 : 0] MEM_read_out_00, MEM_read_out_01, MEM_read_out_10, MEM_read_out_11;
wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_read_IB_00, addr_read_IB_01, addr_read_IB_10, addr_read_IB_11;
wire done_DNN_00, done_DNN_01, done_DNN_10, done_DNN_11;
wire DSIP_done_00, DSIP_done_01, DSIP_done_10, DSIP_done_11;

wire done_vtransfer_prev_00, done_vtransfer_prev_01, done_vtransfer_prev_10, done_vtransfer_prev_11;
wire done_vtransfer_00, done_vtransfer_01, done_vtransfer_10, done_vtransfer_11;

// hsync_in
wire hsync_in_all = hsync_out_00 & hsync_out_10 & hsync_out_01 & hsync_out_11;
wire vsyn_in_all_0 = vsync_out_00 & vsync_out_01;
wire vsyn_in_all_1 = vsync_out_10 & vsync_out_11;

ASIP #(
    .INSTRUCTION_WIDTH(INSTRUCTION_WIDTH),
    .MCMEM_SIZE(MCMEM_SIZE),
    .DATA_WIDTH_MC(DATA_WIDTH_MC),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH_DNN_CORE(DATA_WIDTH_DNN_CORE),
    .DECIMAL_BIT(DECIMAL_BIT),
    .INSTRUCTION_WIDTH_DNN_CORE(INSTRUCTION_WIDTH_DNN_CORE),
    .BUFFER_SIZE(BUFFER_SIZE),
    .SCRATCHPAD_SIZE(SCRATCHPAD_SIZE),
    .BLOCKS_PER_ROW(BLOCKS_PER_ROW),
    .BASE_DATA_OM(BASE_DATA_OM),
    .MODEL(MODEL),
    .IS_FIRST_ROW(1),
    .IS_FIRST_COL(1)
) dsip00 (
    .clk(clk),
    .rst(rst),
    .start(start),
    .wen_MCMem(wen_MCMem_00),
    .addr_w_MCMem(addr_w_MCMem_00),
    .data_w_MCMem(data_w_MCMem_00),
    
    .vsync_in(vsyn_in_all_0),             
    .hsync_in(hsync_in_all),
    .vsync_out(vsync_out_00),
    .hsync_out(hsync_out_00),
    .start_DNN_core(start_DNN_core_00),
    .end_flag(end_flag_00),
//PORT0 ==============
    .command_P0_in(command_P0_in_00),
    .data_P0_in(data_P0_in_00),
    .command_P0_out(command_P0_out_00),
    .data_P0_out(data_P0_out_00),
//PORT1
    .command_P1_in(command_P1_out_01),
    .data_P1_in(data_P1_out_01),
    .inst_P1_in(inst_P1_in_00),
    .command_P1_out(command_P1_out_00),
    .data_P1_out(data_P1_out_00),
    .inst_P1_out(inst_P1_out_00),
    
//PORT OM
    .addr_OM(addr_OM_00),
    .wen_OM(wen_OM_00),
    .ren_OM(ren_OM_00),
    .data_r_OM(data_r_OM_00),
    .data_w_OM(data_w_OM_00),
    .ren_OM_inst(ren_OM_inst_00),
    .inst_r_OM(inst_r_OM_00),
//PORT DNN core
    .addr_DNN(addr_DNN_00),
    .wen_inst_mem(wen_inst_mem_00),
    .wen_IB(wen_IB_00),
    .wen_KSP(wen_KSP_00),
    .wen_BSP(wen_BSP_00),
    .ren_OB(ren_OB_00),
    .data_w_DNN(data_w_DNN_00),
    .inst_w_DNN(inst_w_DNN_00),
    .done_transfer_prev(done_transfer_prev_00),         // Đồng bộ ngang của DSIP trước     (Không cần dùng)
    .done_transfer(done_transfer_00),                   // Đồng bộ ngang DSIP tiếp theo     (không cần dùng)     
    .done_vtransfer_prev(done_vtransfer_prev_00),       // Đồng bộ dọc của DSIP trước trong cùng hàng
    .done_vtransfer(done_vtransfer_00),                 // Đồng bộ dọc DSIP tiếp theo trong cùng hàng

    .done_DNN(done_DNN_00),     // Tín hiệu báo DNN core của DSIP00 đã hoàn thành
    .DSIP_done(DSIP_done_00),    // Không dùng
    .select(select_00)  //DEBUG
);

ASIP #(
    .INSTRUCTION_WIDTH(INSTRUCTION_WIDTH),
    .MCMEM_SIZE(MCMEM_SIZE),
    .DATA_WIDTH_MC(DATA_WIDTH_MC),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH_DNN_CORE(DATA_WIDTH_DNN_CORE),
    .DECIMAL_BIT(DECIMAL_BIT),
    .INSTRUCTION_WIDTH_DNN_CORE(INSTRUCTION_WIDTH_DNN_CORE),
    .BUFFER_SIZE(BUFFER_SIZE),
    .SCRATCHPAD_SIZE(SCRATCHPAD_SIZE),
    .BLOCKS_PER_ROW(BLOCKS_PER_ROW),
    .BASE_DATA_OM(BASE_DATA_OM),
    .MODEL(MODEL),
    .IS_FIRST_ROW(1),
    .IS_FIRST_COL(0)
) dsip01 (
    .clk(clk),
    .rst(rst),
    .start(start),
    .wen_MCMem(wen_MCMem_01),
    .addr_w_MCMem(addr_w_MCMem_01),
    .data_w_MCMem(data_w_MCMem_01),
    
    .vsync_in(vsyn_in_all_0),             
    .hsync_in(hsync_in_all),
    .vsync_out(vsync_out_01),
    .hsync_out(hsync_out_01),
    .start_DNN_core(start_DNN_core_01),
    .end_flag(end_flag_01),
//PORT0 ==============
    .command_P0_in(command_P0_in_01),
    .data_P0_in(data_P0_in_01),
    .command_P0_out(command_P0_out_01),
    .data_P0_out(data_P0_out_01),
//PORT1
    .command_P1_in(command_P1_out_00),
    .data_P1_in(data_P1_out_00),
    .inst_P1_in(inst_P1_out_00),
    .command_P1_out(command_P1_out_01),
    .data_P1_out(data_P1_out_01),
    .inst_P1_out(inst_P1_out_01),
//PORT OM
    .addr_OM(addr_OM_01),
    .wen_OM(wen_OM_01),
    .ren_OM(ren_OM_01),
    .data_r_OM(data_r_OM_01),
    .data_w_OM(data_w_OM_01),
    .ren_OM_inst(ren_OM_inst_01),
    .inst_r_OM(inst_r_OM_01),
//PORT DNN core
    .addr_DNN(addr_DNN_01),
    .wen_inst_mem(wen_inst_mem_01),
    .wen_IB(wen_IB_01),
    .wen_KSP(wen_KSP_01),
    .wen_BSP(wen_BSP_01),
    .ren_OB(ren_OB_01),
    .data_w_DNN(data_w_DNN_01),
    .inst_w_DNN(inst_w_DNN_01),
    .done_transfer_prev(done_transfer_prev_01),         // Đồng bộ ngang của DSIP trước     (Không cần dùng)
    .done_transfer(done_transfer_01),                   // Đồng bộ ngang DSIP tiếp theo     (không cần dùng)     
    .done_vtransfer_prev(done_vtransfer_00),            // Đồng bộ dọc của DSIP trước trong cùng hàng
    .done_vtransfer(done_vtransfer_01),                 // Đồng bộ dọc DSIP tiếp theo trong cùng hàng

    .done_DNN(done_DNN_01),     // Tín hiệu báo DNN core của DSIP01 đã hoàn thành
    .DSIP_done(DSIP_done_01),    // không dùng
    .select(select_01)  //DEBUG
);


ASIP #(
    .INSTRUCTION_WIDTH(INSTRUCTION_WIDTH),
    .MCMEM_SIZE(MCMEM_SIZE),
    .DATA_WIDTH_MC(DATA_WIDTH_MC),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH_DNN_CORE(DATA_WIDTH_DNN_CORE),
    .DECIMAL_BIT(DECIMAL_BIT),
    .INSTRUCTION_WIDTH_DNN_CORE(INSTRUCTION_WIDTH_DNN_CORE),
    .BUFFER_SIZE(BUFFER_SIZE),
    .SCRATCHPAD_SIZE(SCRATCHPAD_SIZE),
    .BLOCKS_PER_ROW(BLOCKS_PER_ROW),
    .BASE_DATA_OM(BASE_DATA_OM),
    .MODEL(MODEL),
    .IS_FIRST_ROW(0),
    .IS_FIRST_COL(1)
) dsip10 (
    .clk(clk),
    .rst(rst),
    .start(start),
    .wen_MCMem(wen_MCMem_10),
    .addr_w_MCMem(addr_w_MCMem_10),
    .data_w_MCMem(data_w_MCMem_10),
    
    .vsync_in(vsyn_in_all_1),             
    .hsync_in(hsync_in_all),
    .vsync_out(vsync_out_10),
    .hsync_out(hsync_out_10),
    .start_DNN_core(start_DNN_core_10),
    .end_flag(end_flag_10),
//PORT0 ==============
    .command_P0_in(command_P0_out_00),
    .data_P0_in(data_P0_out_00),
    .command_P0_out(command_P0_out_10),
    .data_P0_out(data_P0_out_10),
//PORT1
    .command_P1_in(command_P1_out_11),
    .data_P1_in(data_P1_out_11),
    .inst_P1_in(inst_P1_in_10),             // k dùng cho chỉ nhận về data
    .command_P1_out(command_P1_out_10),
    .data_P1_out(data_P1_out_10),
    .inst_P1_out(inst_P1_out_10),
    
//PORT OM
    .addr_OM(addr_OM_10),
    .wen_OM(wen_OM_10),
    .ren_OM(ren_OM_10),
    .data_r_OM(data_r_OM_10),
    .data_w_OM(data_w_OM_10),
    .ren_OM_inst(ren_OM_inst_10),
    .inst_r_OM(inst_r_OM_10),
//PORT DNN core
    .addr_DNN(addr_DNN_10),
    .wen_inst_mem(wen_inst_mem_10),
    .wen_IB(wen_IB_10),
    .wen_KSP(wen_KSP_10),
    .wen_BSP(wen_BSP_10),
    .ren_OB(ren_OB_10),
    .data_w_DNN(data_w_DNN_10),
    .inst_w_DNN(inst_w_DNN_10),
    .done_transfer_prev(done_transfer_00),         // Đồng bộ ngang của DSIP trước     (Không cần dùng)
    .done_transfer(done_transfer_10),                   // Đồng bộ ngang DSIP tiếp theo     (không cần dùng)     
    .done_vtransfer_prev(done_vtransfer_prev_10),       // Đồng bộ dọc của DSIP trước trong cùng hàng
    .done_vtransfer(done_vtransfer_10),                 // Đồng bộ dọc DSIP tiếp theo trong cùng hàng

    .done_DNN(done_DNN_10),     // Tín hiệu báo DNN core của DSIP10 đã hoàn thành
    .DSIP_done(DSIP_done_10),    // Không dùng
    .select(select_10)  //DEBUG
);


ASIP #(
    .INSTRUCTION_WIDTH(INSTRUCTION_WIDTH),
    .MCMEM_SIZE(MCMEM_SIZE),
    .DATA_WIDTH_MC(DATA_WIDTH_MC),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH_DNN_CORE(DATA_WIDTH_DNN_CORE),
    .DECIMAL_BIT(DECIMAL_BIT),
    .INSTRUCTION_WIDTH_DNN_CORE(INSTRUCTION_WIDTH_DNN_CORE),
    .BUFFER_SIZE(BUFFER_SIZE),
    .SCRATCHPAD_SIZE(SCRATCHPAD_SIZE),
    .BLOCKS_PER_ROW(BLOCKS_PER_ROW),
    .BASE_DATA_OM(BASE_DATA_OM),
    .MODEL(MODEL),
    .IS_FIRST_ROW(0),
    .IS_FIRST_COL(0)
) dsip11 (
    .clk(clk),
    .rst(rst),
    .start(start),
    .wen_MCMem(wen_MCMem_11),
    .addr_w_MCMem(addr_w_MCMem_11),
    .data_w_MCMem(data_w_MCMem_11),
    
    .vsync_in(vsyn_in_all_1),             
    .hsync_in(hsync_in_all),
    .vsync_out(vsync_out_11),
    .hsync_out(hsync_out_11),
    .start_DNN_core(start_DNN_core_11),
    .end_flag(end_flag_11),
//PORT0 ==============
    .command_P0_in(command_P0_in_11),
    .data_P0_in(data_P0_in_11),
    .command_P0_out(command_P0_out_11),
    .data_P0_out(data_P0_out_11),
//PORT1
    .command_P1_in(command_P1_out_10),      // nhận command từ DSIP10
    .data_P1_in(data_P1_out_10),            // nhận data từ DSIP10
    .inst_P1_in(inst_P1_out_10),            // nhận inst từ DSIP10
    .command_P1_out(command_P1_out_11),
    .data_P1_out(data_P1_out_11),
    .inst_P1_out(inst_P1_out_11),       // k dùng do k cần truyền đi
//PORT OM
    .addr_OM(addr_OM_11),
    .wen_OM(wen_OM_11),
    .ren_OM(ren_OM_11),
    .data_r_OM(data_r_OM_11),
    .data_w_OM(data_w_OM_11),
    .ren_OM_inst(ren_OM_inst_11),
    .inst_r_OM(inst_r_OM_11),
//PORT DNN core
    .addr_DNN(addr_DNN_11),
    .wen_inst_mem(wen_inst_mem_11),
    .wen_IB(wen_IB_11),
    .wen_KSP(wen_KSP_11),
    .wen_BSP(wen_BSP_11),
    .ren_OB(ren_OB_11),
    .data_w_DNN(data_w_DNN_11),
    .inst_w_DNN(inst_w_DNN_11),
    .done_transfer_prev(done_transfer_prev_11),         // Đồng bộ ngang của DSIP trước     (Không cần dùng)
    .done_transfer(done_transfer_11),                   // Đồng bộ ngang DSIP tiếp theo     (không cần dùng)     
    .done_vtransfer_prev(done_vtransfer_10),            // Đồng bộ dọc của DSIP trước trong cùng hàng
    .done_vtransfer(done_vtransfer_11),                 // Đồng bộ dọc DSIP tiếp theo trong cùng hàng

    .done_DNN(done_DNN_11),     // Tín hiệu báo DNN core của DSIP11 đã hoàn thành
    .DSIP_done(DSIP_done_11),    // không dùng
    .select(select_11)  //DEBUG
);



// Clock generation
initial begin
    clk = 0;
    forever #5 clk = ~clk; // 100 MHz clock
end


// CODE MO PHONG OM1 ========================================================
reg [DATA_WIDTH_DNN_CORE - 1:0] OM_mem_1[0:1879048192];
reg [DATA_WIDTH_DNN_CORE - 1:0] data_read_from_OM_1;
always @(posedge clk) begin
    if(wen_OM_00) OM_mem_1[addr_OM_00] <= data_w_OM_00;
    else if(ren_OM_00) data_read_from_OM_1 <= OM_mem_1[addr_OM_00];
end
assign data_r_OM_00 = data_read_from_OM_1;

reg [INSTRUCTION_WIDTH_DNN_CORE-1:0] OM_mem_1_inst[0:3000];
reg [INSTRUCTION_WIDTH_DNN_CORE-1:0] inst_read_from_OM_1;
always @(posedge clk) begin
    if(ren_OM_inst_00) inst_read_from_OM_1 <= OM_mem_1_inst[addr_OM_00];
end
assign inst_r_OM_00 = inst_read_from_OM_1;
//==========================================================================

// CODE MO PHONG OM2 ========================================================
reg [DATA_WIDTH_DNN_CORE - 1:0] OM_mem_2[0:1879048192];
reg [DATA_WIDTH_DNN_CORE - 1:0] data_read_from_OM_2;
always @(posedge clk) begin
    if(wen_OM_10) OM_mem_2[addr_OM_10] <= data_w_OM_10;
    else if(ren_OM_10) data_read_from_OM_2 <= OM_mem_2[addr_OM_10];
end
assign data_r_OM_10 = data_read_from_OM_2;

reg [INSTRUCTION_WIDTH_DNN_CORE-1:0] OM_mem_2_inst[0:3000];
reg [INSTRUCTION_WIDTH_DNN_CORE-1:0] inst_read_from_OM_2;
always @(posedge clk) begin
    if(ren_OM_inst_10) inst_read_from_OM_2 <= OM_mem_2_inst[addr_OM_10];
end
assign inst_r_OM_10 = inst_read_from_OM_2;
//==========================================================================


// LƯU CÁC PARAMETER CỦA MẠNG VÀO BỘ NHỚ
//==========================================================================
//doc input features
module read_input_features;
  // Định nghĩa các tham số và mảng
  parameter DATA_WIDTH = 16;  // Độ rộng dữ liệu (16 bit)
  parameter ARRAY_SIZE = 1879048192; // Kích thước mảng
  parameter OFFSET = 32'h00010000; // Offset để gán dữ liệu bắt đầu từ vị trí 100
//  reg [DATA_WIDTH-1:0] data_array [0:ARRAY_SIZE-1]; // Mảng lưu dữ liệu
  integer file, r, line_number; // Biến tạm cho file và dòng dữ liệu
  reg [255:0] line; // Chuỗi tạm để đọc từng dòng
  reg [DATA_WIDTH-1:0] temp_data; // Biến tạm để lưu dữ liệu từ dòng
  initial begin
    // Gán giá trị mặc định cho mảng
    integer i;
    // Mở file txt
//    file = $fopen("C:/Users/acer/Downloads/150425/150425/model_tiny_test_14042025/model_tiny_test/4983/4983_hex.txt", "r");
    file = $fopen("C:/Users/acer/Downloads/150425/150425/model_tiny_test_14042025/model_tiny_test/0976/0976_hex.txt", "r");

    if (file == 0) begin
      $display("Không thể mở file!");
      $finish;
    end
    line_number = 0;
    // Đọc từng dòng trong file
    while (!$feof(file)) begin
      r = $fgets(line, file); // Đọc dòng từ file
      if (r) begin
        // Parse dữ liệu hexa từ dòng
        r = $sscanf(line, "%h", temp_data); // Đọc dữ liệu hexa
        if (r == 1) begin
          // Gán dữ liệu vào mảng với OFFSET
          if (line_number + OFFSET < ARRAY_SIZE) begin
            OM_mem_1[line_number + OFFSET] = temp_data; // Gán từ vị trí OFFSET
          end else begin
            $display("Dữ liệu vượt kích thước mảng, dòng %0d sẽ bị bỏ qua.", line_number);
          end
          line_number = line_number + 1;
        end else begin
          $display("Dòng %0d không hợp lệ: %s", line_number, line);
        end
      end
    end
    $fclose(file);
    $display("Input feature 0: %h", OM_mem_1[OFFSET]); // Debug lưu Input Feature
  end
endmodule


//doc conv0 weights
module read_weights_conv0;
  // Định nghĩa các tham số và mảng
  parameter DATA_WIDTH = 16;  // Độ rộng dữ liệu (16 bit)
  parameter ARRAY_SIZE = 1879048192; // Kích thước mảng
  parameter OFFSET = 32'h00010C00; // Offset để gán dữ liệu bắt đầu từ vị trí 100
//  reg [DATA_WIDTH-1:0] data_array [0:ARRAY_SIZE-1]; // Mảng lưu dữ liệu
  integer file, r, line_number; // Biến tạm cho file và dòng dữ liệu
  reg [255:0] line; // Chuỗi tạm để đọc từng dòng
  reg [DATA_WIDTH-1:0] temp_data; // Biến tạm để lưu dữ liệu từ dòng
  initial begin
    // Gán giá trị mặc định cho mảng
    integer i;
    // Mở file txt
//    file = $fopen("D:/tailieu/Nghien_cuu_khoa_hoc/codeDSIP/venv/testfile/model30k/param_hex/weights_conv0_hex.txt", "r");
    file = $fopen("C:/Users/acer/Downloads/Weight_bias_hex/Weight_bias_hex/weights_conv0_hex.txt", "r");

    if (file == 0) begin
      $display("Không thể mở file!");
      $finish;
    end
    line_number = 0;
    // Đọc từng dòng trong file
    while (!$feof(file)) begin
      r = $fgets(line, file); // Đọc dòng từ file
      if (r) begin
        // Parse dữ liệu hexa từ dòng
        r = $sscanf(line, "%h", temp_data); // Đọc dữ liệu hexa
        if (r == 1) begin
          // Gán dữ liệu vào mảng với OFFSET
          if (line_number + OFFSET < ARRAY_SIZE) begin
            OM_mem_1[line_number + OFFSET] = temp_data; // Gán từ vị trí OFFSET
          end else begin
            $display("Dữ liệu vượt kích thước mảng, dòng %0d sẽ bị bỏ qua.", line_number);
          end
          line_number = line_number + 1;
        end else begin
          $display("Dòng %0d không hợp lệ: %s", line_number, line);
        end
      end
    end
    $fclose(file);
    $display("Weight 0: %h", OM_mem_1[OFFSET]); // Debug lưu weight conv0
  end
endmodule


//doc conv0 biases
module read_biases_conv0;
  // Định nghĩa các tham số và mảng
  parameter DATA_WIDTH = 16;  // Độ rộng dữ liệu (16 bit)
  parameter ARRAY_SIZE = 1879048192; // Kích thước mảng
  parameter OFFSET = 32'h00010F60; // Offset để gán dữ liệu bắt đầu từ vị trí 100
//  reg [DATA_WIDTH-1:0] data_array [0:ARRAY_SIZE-1]; // Mảng lưu dữ liệu
  integer file, r, line_number; // Biến tạm cho file và dòng dữ liệu
  reg [255:0] line; // Chuỗi tạm để đọc từng dòng
  reg [DATA_WIDTH-1:0] temp_data; // Biến tạm để lưu dữ liệu từ dòng
  initial begin
    // Gán giá trị mặc định cho mảng
    integer i;
    // Mở file txt
//    file = $fopen("D:/tailieu/Nghien_cuu_khoa_hoc/codeDSIP/venv/testfile/model30k/param_hex/biases_conv0_hex.txt", "r");
    file = $fopen("C:/Users/acer/Downloads/Weight_bias_hex/Weight_bias_hex/biases_conv0_hex.txt", "r");

    if (file == 0) begin
      $display("Không thể mở file!");
      $finish;
    end
    line_number = 0;
    // Đọc từng dòng trong file
    while (!$feof(file)) begin
      r = $fgets(line, file); // Đọc dòng từ file
      if (r) begin
        // Parse dữ liệu hexa từ dòng
        r = $sscanf(line, "%h", temp_data); // Đọc dữ liệu hexa
        if (r == 1) begin
          // Gán dữ liệu vào mảng với OFFSET
          if (line_number + OFFSET < ARRAY_SIZE) begin
            OM_mem_1[line_number + OFFSET] = temp_data; // Gán từ vị trí OFFSET
          end else begin
            $display("Dữ liệu vượt kích thước mảng, dòng %0d sẽ bị bỏ qua.", line_number);
          end
          line_number = line_number + 1;
        end else begin
          $display("Dòng %0d không hợp lệ: %s", line_number, line);
        end
      end
    end
    $fclose(file);
    $display("bias 0: %h", OM_mem_1[OFFSET]); // Debug lưu bias conv0
  end
endmodule






// doc dense0 weights
module read_weights_dense0;
  // Định nghĩa các tham số và mảng
  parameter DATA_WIDTH = 16;  // Độ rộng dữ liệu (16 bit)
  parameter ARRAY_SIZE = 1879048192; // Kích thước mảng
  parameter OFFSET = 32'h00010C00; // Offset để gán dữ liệu bắt đầu từ vị trí 100
//  reg [DATA_WIDTH-1:0] data_array [0:ARRAY_SIZE-1]; // Mảng lưu dữ liệu
  integer file, r, line_number; // Biến tạm cho file và dòng dữ liệu
  reg [255:0] line; // Chuỗi tạm để đọc từng dòng
  reg [DATA_WIDTH-1:0] temp_data; // Biến tạm để lưu dữ liệu từ dòng
  initial begin
    // Gán giá trị mặc định cho mảng
    integer i;
    // Mở file txt
//    file = $fopen("D:/tailieu/Nghien_cuu_khoa_hoc/codeDSIP/venv/testfile/model30k/param_hex/weights_dense0_hex.txt", "r");
    file = $fopen("C:/Users/acer/Downloads/Weight_bias_hex/Weight_bias_hex/weights_dense_hex.txt", "r");

    if (file == 0) begin
      $display("Không thể mở file!");
      $finish;
    end
    line_number = 0;
    // Đọc từng dòng trong file
    while (!$feof(file)) begin
      r = $fgets(line, file); // Đọc dòng từ file
      if (r) begin
        // Parse dữ liệu hexa từ dòng
        r = $sscanf(line, "%h", temp_data); // Đọc dữ liệu hexa
        if (r == 1) begin
          // Gán dữ liệu vào mảng với OFFSET
          if (line_number + OFFSET < ARRAY_SIZE) begin
            OM_mem_2[line_number + OFFSET] = temp_data; // Gán từ vị trí OFFSET
          end else begin
            $display("Dữ liệu vượt kích thước mảng, dòng %0d sẽ bị bỏ qua.", line_number);
          end
          line_number = line_number + 1;
        end else begin
          $display("Dòng %0d không hợp lệ: %s", line_number, line);
        end
      end
    end
    $fclose(file);
    $display("Weight dense 0: %h", OM_mem_2[OFFSET]); // Debug lưu weight dense0
  end
endmodule


// doc dense0 biases
module read_biases_dense0;
  // Định nghĩa các tham số và mảng
  parameter DATA_WIDTH = 16;  // Độ rộng dữ liệu (16 bit)
  parameter ARRAY_SIZE = 1879048192; // Kích thước mảng
  parameter OFFSET = 32'h00018400; // Offset để gán dữ liệu bắt đầu từ vị trí 100
//  reg [DATA_WIDTH-1:0] data_array [0:ARRAY_SIZE-1]; // Mảng lưu dữ liệu
  integer file, r, line_number; // Biến tạm cho file và dòng dữ liệu
  reg [255:0] line; // Chuỗi tạm để đọc từng dòng
  reg [DATA_WIDTH-1:0] temp_data; // Biến tạm để lưu dữ liệu từ dòng
  initial begin
    // Gán giá trị mặc định cho mảng
    integer i;
    // Mở file txt
//    file = $fopen("D:/tailieu/Nghien_cuu_khoa_hoc/codeDSIP/venv/testfile/model30k/param_hex/biases_dense0_hex.txt", "r");
    file = $fopen("C:/Users/acer/Downloads/Weight_bias_hex/Weight_bias_hex/biases_dense_hex.txt", "r");

    if (file == 0) begin
      $display("Không thể mở file!");
      $finish;
    end
    line_number = 0;
    // Đọc từng dòng trong file
    while (!$feof(file)) begin
      r = $fgets(line, file); // Đọc dòng từ file
      if (r) begin
        // Parse dữ liệu hexa từ dòng
        r = $sscanf(line, "%h", temp_data); // Đọc dữ liệu hexa
        if (r == 1) begin
          // Gán dữ liệu vào mảng với OFFSET
          if (line_number + OFFSET < ARRAY_SIZE) begin
            OM_mem_2[line_number + OFFSET] = temp_data; // Gán từ vị trí OFFSET
          end else begin
            $display("Dữ liệu vượt kích thước mảng, dòng %0d sẽ bị bỏ qua.", line_number);
          end
          line_number = line_number + 1;
        end else begin
          $display("Dòng %0d không hợp lệ: %s", line_number, line);
        end
      end
    end
    $fclose(file);
    $display("Bias dens0 0: %h", OM_mem_2[OFFSET]); // Debug lưu bias dense0
  end
endmodule
//==========================================================================




//doc controller instruction
reg [31:0] controller_instruction_temp_00[0:5000];       // chứa tạm instructions của DSIP 00
reg [31:0] controller_instruction_temp_01[0:5000];       // chứa tạm instructions của DSIP 01
reg [31:0] controller_instruction_temp_10[0:5000];       // chứa tạm instructions của DSIP 01
reg [31:0] controller_instruction_temp_11[0:5000];       // chứa tạm instructions của DSIP 01

// Stimulus
initial begin   
   // Nạp lệnh cho Controller 00
   $readmemb("D:/tailieu/Nghien_cuu_khoa_hoc/codeDSIP/venv/testfile/model2x2/controller_instruction/model2x2_00.txt",controller_instruction_temp_00);
   // Nạp lệnh cho Controller 01
   $readmemb("D:/tailieu/Nghien_cuu_khoa_hoc/codeDSIP/venv/testfile/model2x2/controller_instruction/model2x2_01.txt",controller_instruction_temp_01);
   // Nạp lệnh cho DNN Core cột 0
   $readmemb("D:/tailieu/Nghien_cuu_khoa_hoc/codeDSIP/venv/testfile/model2x2/DNNinst/instructions_2x2_0.txt",OM_mem_1_inst);
   
    
    
    // Nạp lệnh cho Controller 10
    $readmemb("D:/tailieu/Nghien_cuu_khoa_hoc/codeDSIP/venv/testfile/model2x2/controller_instruction/model2x2_10.txt",controller_instruction_temp_10);
    // Nạp lệnh cho Controller 11
    $readmemb("D:/tailieu/Nghien_cuu_khoa_hoc/codeDSIP/venv/testfile/model2x2/controller_instruction/model2x2_11.txt",controller_instruction_temp_11);
    // Nạp lệnh cho DNN Core cột 1
   $readmemb("D:/tailieu/Nghien_cuu_khoa_hoc/codeDSIP/venv/testfile/model2x2/DNNinst/instructions_2x2_1.txt",OM_mem_2_inst);



   rst = 1;
   #400
   rst = 0;
   // Xử lý nạp lệnh của Controller 00 vào mem
   fork 
   foreach(controller_instruction_temp_00[i]) begin #10
       wen_MCMem_00 = 1;
       addr_w_MCMem_00 = i;
       data_w_MCMem_00 = controller_instruction_temp_00[i];
       if(i == 1024) break;
   end
   // Xử lý nạp lệnh của Controller 01 vào mem
   foreach(controller_instruction_temp_01[i]) begin #10
       wen_MCMem_01 = 1;
       addr_w_MCMem_01 = i;
       data_w_MCMem_01 = controller_instruction_temp_01[i];
       if(i == 1024) break;
   end
   
   // Xử lý nạp lệnh của Controller 10 vào mem
   foreach(controller_instruction_temp_10[i]) begin #10
       wen_MCMem_10 = 1;
       addr_w_MCMem_10 = i;
       data_w_MCMem_10 = controller_instruction_temp_10[i];
       if(i == 1024) break;
   end
   
   // Xử lý nạp lệnh của Controller 11 vào mem
   foreach(controller_instruction_temp_11[i]) begin #10
       wen_MCMem_11 = 1;
       addr_w_MCMem_11 = i;
       data_w_MCMem_11 = controller_instruction_temp_11[i];
       if(i == 1024) break;
   end
   
   join
   #10
   start = 1;
   #10
   start = 0;
end

endmodule
