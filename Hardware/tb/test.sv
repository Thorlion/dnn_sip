`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/02/2024 08:55:11 PM
// Design Name: 
// Module Name: test
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


module test_tb;

parameter DATA_WIDTH = 16;
parameter INSTRUCTION_WIDTH = 123;
parameter SCRATCHPAD_SIZE = 64;

// Khai báo mảng động để lưu giá trị từ 2 file ###########################################3
    reg [15:0] input_array_hexa [];
    reg [15:0] conv_array_hexa [];
    integer file_input, file_conv, status;
    reg [31:0] line_data;

    // Task để đọc dữ liệu từ file và lưu vào mảng
    function read_file_to_array_0(input string file_name, output reg [15:0] array []);
        integer file, status;
        reg [15:0] line_data;
        begin
            // Mở file
            file = $fopen(file_name, "r");
            if (file == 0) begin
                $display("Không thể mở file %s!", file_name);
                $finish;
            end

            // Đọc dữ liệu từ file
            while (!$feof(file)) begin
                status = $fscanf(file, "%h\n", line_data);
                if (status == 1) begin
                    // Lưu giá trị hợp lệ vào mảng
                    array = {array, line_data[15:0]};
                end else begin
                    // Xử lý lỗi nếu đọc không đúng định dạng
                    $display("Cảnh báo: Không thể đọc dòng tiếp theo trong file %s.", file_name);
                end
            end

            // Đóng file
            $fclose(file);
        end
    endfunction

    function read_file_to_array_1(input string file_name, output reg [15:0] array []);
        integer file, status;
        reg [15:0] line_data;
        begin
            // Mở file
            file = $fopen(file_name, "r");
            if (file == 0) begin
                $display("Không thể mở file %s!", file_name);
                $finish;
            end

            // Đọc dữ liệu từ file
            while (!$feof(file)) begin
                status = $fscanf(file, "%h\n", line_data);
                if (status == 1) begin
                    // Lưu giá trị hợp lệ vào mảng
                    array = {array, line_data[15:0]};
                end else begin
                    // Xử lý lỗi nếu đọc không đúng định dạng
                    $display("Cảnh báo: Không thể đọc dòng tiếp theo trong file %s.", file_name);
                end
            end

            // Đóng file
            $fclose(file);
        end
    endfunction


    initial begin  
        $display("Đọc dữ liệu từ file features_input.txt...");
        read_file_to_array_0("C:/Users/acer/Desktop/data/features_input.txt", input_array_hexa);
        
        $display("Đọc dữ liệu từ file conv1.txt...");
        read_file_to_array_1("C:/Users/acer/Desktop/data/conv1.txt", conv_array_hexa);

//        // Hiển thị nội dung của mảng input_array_hexa
//        $display("Dữ liệu trong input_array_hexa:");
//        for (int i = 0; i < input_array_hexa.size(); i++) begin
//            $display("input_array_hexa[%0d] = %h", i, input_array_hexa[i]);
//        end

//        // Hiển thị nội dung của mảng conv_array_hexa
//        $display("Dữ liệu trong conv_array_hexa:");
//        for (int i = 0; i < conv_array_hexa.size(); i++) begin
//            $display("conv_array_hexa[%0d] = %h", i, conv_array_hexa[i]);
//        end

//        $finish;
    end
//##################################################################################


// INPUT
    bit clk;
    bit rst;
    bit start;
    bit en_write_SC;
    
    bit [7:0] SC_addr_w;
    bit [INSTRUCTION_WIDTH-1:0] inst_SC_w;
    
    bit [63:0] en_write_IB;
    bit [$clog2(SCRATCHPAD_SIZE)-1:0] addr_write_IB;
    
    bit [63:0] en_write_KSP;
    bit [$clog2(SCRATCHPAD_SIZE)-1:0] addr_write_KSP;
    
    bit en_write_BSP;
    bit [$clog2(SCRATCHPAD_SIZE)-1:0] addr_write_BSP;
    
//    bit en_write_FCSP;
//    bit [$clog2(SCRATCHPAD_SIZE)-1:0] addr_write_FCSP;
    
    bit [63:0] en_write_OSP;
//    bit [$clog2(SCRATCHPAD_SIZE)-1:0] addr_write_OSP;
    
    bit [DATA_WIDTH - 1 : 0] data_write;
    
    
    wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_write_OB;
    wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_read_OB;
    
//    wire [DATA_WIDTH - 1 : 0]MLI_read_out;
//    wire [DATA_WIDTH - 1 : 0]MLK_read_out;
//    wire [DATA_WIDTH - 1 : 0]MLB_read_out;
//    wire [DATA_WIDTH - 1 : 0]MLFC_read_out;
//    wire [DATA_WIDTH - 1 : 0]MLO_read_out;
//    wire [DATA_WIDTH - 1 : 0]MLOM_read_out;

    bit [5:0] select;
//    wire [118:0] instruction_stage_CONV;
    wire [1:0] src_mult_1;
    wire src_mult_2;
    wire [1:0] src_acc;
    wire src_add_bias;
//    wire [DATA_WIDTH*2 - 1 : 0] lut0_coordinate_0;         // Coordinate of point 0
//    wire [DATA_WIDTH*2 - 1 : 0] lut0_coordinate_1;         // Coordinate of point 1
//    wire [DATA_WIDTH - 1 : 0] lut0_data_out;                // = data_in after being latched
    
//    wire [DATA_WIDTH*2 - 1 : 0] lut1_coordinate_0;         // Coordinate of point 0
//    wire [DATA_WIDTH*2 - 1 : 0] lut1_coordinate_1;         // Coordinate of point 1
//    wire [DATA_WIDTH - 1 : 0] lut1_data_out;    
//    wire [DATA_WIDTH - 1 : 0] EOA_read_out;
//    wire [DATA_WIDTH - 1 : 0] NEOA_read_out;
    wire sel_lut;
//    wire [DATA_WIDTH - 1 : 0] NOL_read_out;
//    wire [DATA_WIDTH - 1 : 0] NOA_read_out;
//    wire [DATA_WIDTH - 1 : 0] NFC_read_out;
//    wire [DATA_WIDTH - 1 : 0] li_data_out;
    
//    wire [DATA_WIDTH - 1 : 0] PEOA_read_out;
//    wire [DATA_WIDTH - 1 : 0] POA_read_out;
//    wire [DATA_WIDTH - 1 : 0] POL_read_out;
//    wire [DATA_WIDTH - 1 : 0] POFC_read_out;
    wire [2:0] src_max;
//    wire [DATA_WIDTH - 1 : 0] POM_read_out;
    
    wire en_store_OB;
    wire en_store_OSP;
    wire en_store_FCSP;
    wire [1:0] src_store_OB;
    wire [1:0] src_store_MEM;
    
    wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_write_OSP_ML_out;
    wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_write_OSP_CONV_out;
    wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_write_FCSP_ML_out;
    wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_write_FCSP_CONV_out;
    wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_write_OB_ML_out;
    wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_write_OB_CONV_out;
    wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_read_OB_ML_out;
    wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_read_OB_CONV_out;
    wire [DATA_WIDTH - 1 : 0] OB_read_out;
    wire [DATA_WIDTH - 1 : 0] MEM_read_out;
    
    bit en_MC_read_OB;
    bit [$clog2(SCRATCHPAD_SIZE)-1:0] addr_MC_read_OB;
    wire [DATA_WIDTH - 1 : 0] data_MC_read_OB;
    
always #2.5 clk = !clk;
integer i;
integer j;
initial begin
    rst = 1;
    #400 
    rst = 0;
    
    en_write_KSP = 64'h0000000000000001;
    for(j = 0; j < 9; j = j + 1) begin
        addr_write_KSP = 0;
        data_write = conv_array_hexa[0 + j];
        #5
        addr_write_KSP = 1;
        data_write = conv_array_hexa[9 + j];
        #5
        addr_write_KSP = 2;
        data_write = conv_array_hexa[18 + j];
        #5
        en_write_KSP = en_write_KSP << 1;
    end
    #5
    en_write_KSP = 64'h0000000000000000;
    
    
    for(j = 0; j < 3; j = j + 1) begin 
        for(i = 0; i < 8; i = i + 1) begin #5
            en_write_IB = 64'h0000000000000001;
            addr_write_IB = i +(j*8);
            data_write = input_array_hexa[i + j*64];
        end
    end
    #5
    en_write_IB = 64'h0000000000000000;
    
    SC_addr_w = 0; en_write_SC = 1;
    inst_SC_w = 123'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    #5
    SC_addr_w = 1; en_write_SC = 1;
    inst_SC_w = 123'b000000000001000000000000000000000000000000000000000000000000000000000000000000000000010000000101000000000000000000000000100;
    #5
    SC_addr_w = 2; en_write_SC = 1;
    inst_SC_w = 123'b000000000001000010000000000100000000000000000000000000000000000000000000000000000000010000000101100000000000000000000000100;
    #5
    SC_addr_w = 3; en_write_SC = 1;
    inst_SC_w = 123'b000000000001000100000000001000000000000000000000000000000000000000000000000000000000010000000101100000000000000000000000100;
    
    #5
    SC_addr_w = 4; en_write_SC = 1;
    inst_SC_w = 123'b000000000001000000010000000000000000000000000000000000000000000000000000000000000000010000000101110000000000000000000000100;
    
    #5
    SC_addr_w = 5; en_write_SC = 1;
    inst_SC_w = 123'b000000000001000010010000000100000000000000000000000000000000000000000000000000000000010000000101100000000000000000000000100;
    
    #5
    SC_addr_w = 6; en_write_SC = 1;
    inst_SC_w = 123'b000000000001000100010000001000000000000000000000000000000000000000000000000000000000010000000101100000000000000000000000100;
    
    #5
    SC_addr_w = 7; en_write_SC = 1;
    inst_SC_w = 123'b000000000001000000100000000000000000000000000000000000000000000000000000000000000000010000000101110000000000000000000000100;
    
    #5
    SC_addr_w = 8; en_write_SC = 1;
    inst_SC_w = 123'b000000000001000010100000000100000000000000000000000000000000000000000000000000000000010000000101100000000000000000000000100;
    
    #5
    SC_addr_w = 9; en_write_SC = 1;
    inst_SC_w = 123'b000000000001000100100000001000000000000000000000000100000000000000000000000000000000010000000101100000000000000001001000100;
    
    #5
    SC_addr_w = 10; en_write_SC = 1;
    inst_SC_w = 123'b000000000001000000110000000000000000000000000000000000000000000000000000000000000000010000000101110000000000000000000000100; 
    #5
    SC_addr_w = 11; en_write_SC = 1;
    inst_SC_w = 123'b000000000001000010110000000100000000000000000000000000000000000000000000000000000000010000000101100000000000000000000000100;
    #5
    SC_addr_w = 12; en_write_SC = 1;
    inst_SC_w = 123'b000000000001000100110000001000000000000000000000001000000000000000000000000000000000010000000101100000000000000001001000100;
    
    
    
    
    #5
    en_write_SC = 0;
//    #4
//    en_write_KSP = 64'h0000000000000001;
//    addr_write_KSP = 0;
//    data_write = 5;
//    #4
//    en_write_KSP = 64'h0000000000000002;
//    addr_write_KSP = 0;
//    data_write = 9;
//    #4
//    en_write_KSP = 64'h0000000000000004;
//    addr_write_KSP = 0;
//    data_write = 2;
//    #4
//    en_write_KSP = 64'h0000000000000008;
//    addr_write_KSP = 0;
//    data_write = 20;
//    #4
//    en_write_KSP = 64'h0000000000000010;
//    addr_write_KSP = 0;
//    data_write = 31;
//    #4
//    en_write_KSP = 64'h0000000000000020;
//    addr_write_KSP = 0;
//    data_write = 7;
    
//    #4
//    en_write_KSP = 64'h0000000000000040;
//    addr_write_KSP = 0;
//    data_write = -16;
    
//    #4
//    en_write_KSP = 64'h0000000000000080;
//    addr_write_KSP = 0;
//    data_write = 20;
    
//    #4
//    en_write_KSP = 64'h0000000000000100;
//    addr_write_KSP = 0;
//    data_write = -81;
    
//    #4
//    en_write_KSP = 64'h0000000000000000;
//    en_write_IB = 64'h0000000000000001;
    
//    addr_write_IB = 0;
//    data_write = 10;
//    #4
//    addr_write_IB = 1;
//    data_write = 6;
    
//    #4
//    addr_write_IB = 2;
//    data_write = 99;
    
//    #4
//    addr_write_IB = 3;
//    data_write = 30;
    
//    #4
//    addr_write_IB = 4;
//    data_write = 44;
    
//    #4
//    addr_write_IB = 5;
//    data_write = 15;
    
//    #4
//    addr_write_IB = 6;
//    data_write = 1;
    
//    #4
//    addr_write_IB = 7;
//    data_write = 7;
    
//    #4
//    addr_write_IB = 8;
//    data_write = 23;
    
//    #4
//    addr_write_IB = 9;
//    data_write = -11;
    
//    #4
//    addr_write_IB = 10;
//    data_write = 32;
    
//    #4
//    addr_write_IB = 11;
//    data_write = 2;
    
//    #4
//    addr_write_IB = 12;
//    data_write = -40;
    
//    #4
//    addr_write_IB = 13;
//    data_write = 24;
    
//    #4
//    addr_write_IB = 14;
//    data_write = 91;
    
//    #4
//    addr_write_IB = 15;
//    data_write = -80;
    
//    #4
//    en_write_IB = 64'h0000000000000000;
////    en_write_BSP = 1;
////    addr_write_BSP = 0;
////    data_write = 1;
//    #4
//    select = 0;
//    #4
//    select = 1;
    #10
    start = 1;
////    #4
////    start = 0;
    #300
    start = 0;
    en_MC_read_OB = 1;
    addr_MC_read_OB = 0;
end

test t(
    clk,
    rst,
    start,
    en_write_SC,
    
    SC_addr_w,
    inst_SC_w,
    
    en_write_IB,
    addr_write_IB,
    
    en_write_KSP,
    addr_write_KSP,
    
    en_write_BSP,
    addr_write_BSP,
    
//    en_write_FCSP,
//    addr_write_FCSP,
    
    en_write_OSP,
//    addr_write_OSP,
    
    data_write,
    
    
    addr_write_OB,
    addr_read_OB,
    
//    MLI_read_out,
//    MLK_read_out,
//    MLB_read_out,
//    MLFC_read_out,
//    MLO_read_out,
//    MLOM_read_out,

    select,
//    instruction_stage_CONV
    src_mult_1,
    src_mult_2,
    src_acc,
    src_add_bias,
    lut0_coordinate_0,         
    lut0_coordinate_1,         
    lut0_data_out,
    lut1_coordinate_0,         
    lut1_coordinate_1,         
    lut1_data_out, 
//    EOA_read_out,
    
//    NEOA_read_out,
    sel_lut,
//    NOL_read_out,
//    NOA_read_out,
//    NFC_read_out,
    li_data_out,  
    
//    PEOA_read_out,
//    POA_read_out,
//    POL_read_out,
//    POFC_read_out,
    src_max,
//    POM_read_out,
    
    en_store_OB,
    en_store_OSP,
    en_store_FCSP,
    src_store_OB,
    src_store_MEM,
    
    addr_write_OSP_ML_out,
    addr_write_OSP_CONV_out,
    addr_write_FCSP_ML_out,
    addr_write_FCSP_CONV_out,
    addr_write_OB_ML_out,
    addr_write_OB_CONV_out,
    addr_read_OB_ML_out,
    addr_read_OB_CONV_out,
    OB_read_out,
    MEM_read_out,
    
    en_MC_read_OB,
    addr_MC_read_OB,   
    data_MC_read_OB
    
);
endmodule




