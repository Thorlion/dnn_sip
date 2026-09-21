`timescale 1ns / 1ps

`define SINGLE 1
`define ONE_ONE 2
`define TWO_TWO 3

module ASIP #(
    // Controller parameters
    parameter MODEL         = `SINGLE,
    parameter IS_FIRST_ROW  = 1,
    parameter IS_FIRST_COL  = 1, 
    parameter INSTR_W       = 32,               
    parameter MCMEM_W       = 4096,
    parameter DATA_W_MC     = 32,
    parameter ADDR_W        = 32,
    parameter BASE_DATA_OM  = 32'h00010000,
    
    // DNN core parameters
    parameter DATA_W_DNN    = 16,
    parameter DECIMAL_BIT   = 8,
    parameter INSTR_W_DNN   = 212,
    parameter BUFFER_SIZE   = 512,
    parameter SCRATCHPAD_W  = 512,
    parameter BLOCKS_PER_ROW= 64
)(
    input  logic                        clk,
    input  logic                        rst,
    input  logic                        start,

    input  logic                        mcmem_wen,
    input  logic [$clog2(MCMEM_W)-1:0]  mcmem_wr_addr,
    input  logic [INSTR_W-1:0]          mcmem_wr_data,

    // MODE controller
    input  logic                        vsync_in,
    input  logic                        hsync_in,

    output logic                        vsync_out,
    output logic                        hsync_out,
    output logic                        start_DNN,
    output logic                        end_flag,
    
    //PORT0 ==============
    input  logic [67:0]                 command_P0_in,
    input  logic [15:0]                 data_P0_in,
    output logic [67:0]                 command_P0_out,
    output logic [15:0]                 data_P0_out,
    
    //PORT1 ==============
    input  logic [67:0]                 command_P1_in,
    input  logic [15:0]                 data_P1_in,
    input  logic [211:0]                inst_P1_in,
    output logic [67:0]                 command_P1_out,
    output logic [15:0]                 data_P1_out,
    output logic [211:0]                inst_P1_out,
    
    //PORT OM ==============
    output logic [31:0]                 OM_addr,
    output logic                        OM_wen,
    output logic                        OM_ren,
    input  logic [15:0]                 OM_rd_data,
    output logic [15:0]                 OM_wr_data,
    output logic                        OM_inst_ren,
    input  logic [211:0]                OM_inst_rd, 
    
    //PORT DNN core ==============
    output logic [8:0]                  DNN_addr,
    output logic                        mem_inst_wen,
    output logic [63:0]                 IB_wen,
    output logic [63:0]                 KSP_wen,
    output logic                        BSP_wen,
    output logic                        OB_ren,
    output logic [15:0]                 DNN_wr_data,
    output logic [211:0]                DNN_inst_wr,

    input  logic                        done_transfer_prev,
    output logic                        done_transfer,
    input  logic                        done_vtransfer_prev,
    output logic                        done_vtransfer,

    output logic [DATA_W_DNN-1:0]       OB_data_read,
    output logic [DATA_W_DNN-1:0]       MEM_data_read,

    output logic                        dnn_done,
    output logic [$clog2(SCRATCHPAD_W)-1:0] dnn_addr_write_OSP_ML_out,
    output logic [$clog2(SCRATCHPAD_W)-1:0] dnn_addr_write_OSP_CONV_out,
    output logic [$clog2(SCRATCHPAD_W)-1:0] dnn_addr_write_FCSP_ML_out,
    output logic [$clog2(SCRATCHPAD_W)-1:0] dnn_addr_write_FCSP_CONV_out,
    output logic [$clog2(SCRATCHPAD_W)-1:0] dnn_addr_write_OB_ML_out,
    output logic [$clog2(SCRATCHPAD_W)-1:0] dnn_addr_write_OB_CONV_out,
    output logic [$clog2(SCRATCHPAD_W)-1:0] dnn_addr_read_OB_ML_out
);

    logic [15:0] DNN_rd_data;

    Controller #(
        .INSTR_W        (INSTR_W),
        .DATA_W         (DATA_W_MC),
        .MCMEM_W        (MCMEM_W),
        .ADDR_W         (ADDR_W),
        .BASE_DATA_OM   (BASE_DATA_OM),
        .MODEL          (MODEL),
        .IS_FIRST_ROW   (IS_FIRST_ROW),
        .IS_FIRST_COL   (IS_FIRST_COL)
    ) controller (
        .clk                (clk),                         
        .rst                (rst),                         
        .start              (start),                       
        .mcmem_wen          (mcmem_wen),
        .mcmem_wr_addr      (mcmem_wr_addr),
        .mcmem_wr_data      (mcmem_wr_data),
        
        // MODE controller
        .vsync_in           (vsync_in),                            
        .hsync_in           (hsync_in),                            
        .dnn_done           (dnn_done),                   
        .vsync_out          (vsync_out),                          
        .hsync_out          (hsync_out),
        .start_DNN          (start_DNN),
        .end_flag           (end_flag),
        
        //PORT0 ==============
        .command_P0_in      (command_P0_in),
        .data_P0_in         (data_P0_in),
        .command_P0_out     (command_P0_out),
        .data_P0_out        (data_P0_out),
        
        //PORT1
        .command_P1_in      (command_P1_in),
        .data_P1_in         (data_P1_in),
        .inst_P1_in         (inst_P1_in),
        .command_P1_out     (command_P1_out),
        .data_P1_out        (data_P1_out),
        .inst_P1_out        (inst_P1_out),
        
        //PORT OM
        .OM_addr            (OM_addr),
        .OM_wen             (OM_wen),
        .OM_ren             (OM_ren),
        .OM_rd_data         (OM_rd_data),
        .OM_wr_data         (OM_wr_data),
        .OM_inst_ren        (OM_inst_ren),
        .OM_inst_rd         (OM_inst_rd), 
        
        //PORT DNN core
        .DNN_addr           (DNN_addr),
        .mem_inst_wen       (mem_inst_wen),
        .IB_wen             (IB_wen),
        .KSP_wen            (KSP_wen),
        .BSP_wen            (BSP_wen),
        .OB_ren             (OB_ren),
        .DNN_wr_data        (DNN_wr_data),
        .DNN_rd_data        (DNN_rd_data),
        .DNN_inst_wr        (DNN_inst_wr),
        
        .done_transfer_prev (done_transfer_prev),
        .done_transfer      (done_transfer),
        .done_vtransfer_prev(done_vtransfer_prev),
        .done_vtransfer     (done_vtransfer)
    );

    DNN_Core #(
        .DATA_W         (DATA_W_DNN),
        .DECIMAL_BIT    (DECIMAL_BIT),                       
        .INSTR_W        (INSTR_W_DNN),
        .BUFFER_SIZE    (BUFFER_SIZE),
        .SCRATCHPAD_W   (SCRATCHPAD_W),
        .BLOCKS_PER_ROW (BLOCKS_PER_ROW)
    ) dnn_core (
        .clk            (clk),
        .rst            (rst),
        .start          (start_DNN),   
        .DC_write_en    (mem_inst_wen),
        .DC_addr_w      (DNN_addr),
        .DC_inst_w      (DNN_inst_wr),
        .en_write_IB    (IB_wen),
        .IB_wr_addr     (DNN_addr),  

        .en_write_KSP   (KSP_wen),
        .KSP_wr_addr    (DNN_addr),   
        .en_write_BSP   (BSP_wen),
        .BSP_wr_addr    (DNN_addr),
        .data_write     (DNN_wr_data),

        .OB_data_read   (OB_data_read),
        .MEM_data_read  (MEM_data_read),
        .dnn_done       (dnn_done),
        .en_C_read_OB   (OB_ren),
        .OB_MC_rd_addr  (DNN_addr),
        .OB_MC_read     (DNN_rd_data),
        .addr_write_OSP_ML_out    (dnn_addr_write_OSP_ML_out),
        .addr_write_OSP_CONV_out  (dnn_addr_write_OSP_CONV_out),
        .addr_write_FCSP_ML_out   (dnn_addr_write_FCSP_ML_out),
        .addr_write_FCSP_CONV_out (dnn_addr_write_FCSP_CONV_out),
        .addr_write_OB_ML_out     (dnn_addr_write_OB_ML_out),
        .addr_write_OB_CONV_out   (dnn_addr_write_OB_CONV_out),
        .addr_read_OB_ML_out      (dnn_addr_read_OB_ML_out)
    );


endmodule