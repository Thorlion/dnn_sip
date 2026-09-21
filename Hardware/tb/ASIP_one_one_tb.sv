`timescale 1ns / 1ps
`define SINGLE 1
`define ONE_ONE 2
`define TWO_TWO 3


module ASIP_one_one_tb;

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
parameter MODEL = `ONE_ONE;
parameter IS_FIRST_ROW = 1;
parameter IS_FIRST_COL = 1;
parameter BASE_DATA_OM = 32'h00010000;      // phân vùng giữa OM chứa instruction và OM chứa data (data bắt đầu từ 0x00010000)

// Inputs
bit clk;
bit rst;
bit start;
bit wen_MCMem_1, wen_MCMem_2;
bit [$clog2(MCMEM_SIZE)-1:0] addr_w_MCMem_1, addr_w_MCMem_2;
bit [INSTRUCTION_WIDTH-1:0] data_w_MCMem_1, data_w_MCMem_2;
bit vsync_in_1, vsync_in_2;
bit hsync_in_1, hsync_in_2;
//bit all_DNN_done_signal;
wire vsync_out_1, vsync_out_2;
wire hsync_out_1, hsync_out_2;
wire start_DNN_core_1, start_DNN_core_2;
wire end_flag_1, end_flag_2;

//PORT0 ==============
bit [67:0] command_P0_in_1, command_P0_in_2;
bit [15:0] data_P0_in_1, data_P0_in_2;
wire [67:0] command_P0_out_1, command_P0_out_2;
wire [15:0] data_P0_out_1, data_P0_out_2;

//PORT1
bit [67:0] command_P1_in_1, command_P1_in_2;
bit [15:0] data_P1_in_1, data_P1_in_2;
wire [67:0] command_P1_out_1, command_P1_out_2;
wire [15:0] data_P1_out_1, data_P1_out_2;


//PORT OM
wire [31:0] addr_OM_1, addr_OM_2;
wire wen_OM_1, wen_OM_2;
wire ren_OM_1, ren_OM_2;
bit [31:0] data_r_OM_1, data_r_OM_2;
wire [31:0] data_w_OM_1, data_w_OM_2;
wire ren_OM_inst_1, ren_OM_inst_2;
bit [211:0] inst_r_OM_1, inst_r_OM_2;

//PORT DNN core
wire [8:0] addr_DNN_1, addr_DNN_2;
wire wen_inst_mem_1, wen_inst_mem_2;
wire [63:0] wen_IB_1, wen_IB_2;
wire [63:0] wen_KSP_1, wen_KSP_2;
wire wen_BSP_1, wen_BSP_2;
wire ren_OB_1, ren_OB_2;
wire [31:0] data_w_DNN_1, data_w_DNN_2;
wire [211:0] inst_w_DNN_1, inst_w_DNN_2;
bit done_transfer_prev_1, done_transfer_prev_2;
wire done_transfer_1, done_transfer_2;

wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_write_OB_1, addr_write_OB_2;
wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_read_OB_1, addr_read_OB_2;

bit [7:0] select_1, select_2;

wire [DATA_WIDTH_DNN_CORE - 1 : 0] NEOA_read_out_1, NEOA_read_out_2;
wire sel_lut_1, sel_lut_2;

wire [DATA_WIDTH_DNN_CORE - 1 : 0] li_data_out_1, li_data_out_2;

wire [DATA_WIDTH_DNN_CORE - 1 : 0] POA_read_out_1, POA_read_out_2;


wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_write_OSP_ML_out_1, addr_write_OSP_ML_out_2;
wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_write_OSP_CONV_out_1, addr_write_OSP_CONV_out_2;
wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_write_FCSP_ML_out_1, addr_write_FCSP_ML_out_2;
wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_write_OB_ML_out_1, addr_write_OB_ML_out_2;
wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_read_OB_ML_out_1, addr_read_OB_ML_out_2;
wire [DATA_WIDTH_DNN_CORE - 1 : 0] OB_read_out_1, OB_read_out_2;
wire [DATA_WIDTH_DNN_CORE - 1 : 0] MEM_read_out_1, MEM_read_out_2;

wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_read_IB_1, addr_read_IB_2;
wire done_DNN_1, done_DNN_2;

wire DSIP_done_1, DSIP_done_2;

wire done_vtransfer_prev_1, done_vtransfer_prev_2;
wire done_vtransfer_1, done_vtransfer_2;
wire hsync_in_all = hsync_out_1 & hsync_out_2;
// Instantiate the Unit Under Test (UUT)
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
) uut1 (
    .clk(clk),
    .rst(rst),
    .start(start),
    .wen_MCMem(wen_MCMem_1),
    .addr_w_MCMem(addr_w_MCMem_1),
    .data_w_MCMem(data_w_MCMem_1),
    
    .vsync_in(vsync_out_1),             // do chỉ có 1 ASIP trên 1 cột nên vsync_in = vsync_out
    .hsync_in(hsync_in_all),
    .vsync_out(vsync_out_1),
    .hsync_out(hsync_out_1),
    .start_DNN_core(start_DNN_core_1),
    .end_flag(end_flag_1),
//PORT0 ==============
    .command_P0_in(command_P0_in_1),
    .data_P0_in(data_P0_in_1),
    .command_P0_out(command_P0_out_1),
    .data_P0_out(data_P0_out_1),
//PORT1
    .command_P1_in(command_P1_in_1),
    .data_P1_in(data_P1_in_1),
    .command_P1_out(command_P1_out_1),
    .data_P1_out(data_P1_out_1),
//PORT OM
    .addr_OM(addr_OM_1),
    .wen_OM(wen_OM_1),
    .ren_OM(ren_OM_1),
    .data_r_OM(data_r_OM_1),
    .data_w_OM(data_w_OM_1),
    .ren_OM_inst(ren_OM_inst_1),
    .inst_r_OM(inst_r_OM_1),
//PORT DNN core
    .addr_DNN(addr_DNN_1),
    .wen_inst_mem(wen_inst_mem_1),
    .wen_IB(wen_IB_1),
    .wen_KSP(wen_KSP_1),
    .wen_BSP(wen_BSP_1),
    .ren_OB(ren_OB_1),
    .data_w_DNN(data_w_DNN_1),
    .inst_w_DNN(inst_w_DNN_1),
    .done_transfer_prev(done_transfer_prev_1),
    .done_transfer(done_transfer_1),
    .done_vtransfer_prev(done_vtransfer_prev_1),
    .done_vtransfer(done_vtransfer_1),
    
    .done_DNN(done_DNN_1),
    .DSIP_done(DSIP_done_1)

);
/* 
   Tui có thêm một vài dòng code trong file này, chủ yếu là dùng để debug dễ dàng hơn
   Tui có thêm một tí vào cơ chế của phần chuyển state trong master_core ( chỉ ở phần WAIT_VSYNC ) nhằm đáp ứng hiểu biết của tui
   Nhưng vì thêm vội nên có thể chưa được tối ưu, nếu Quân có thể tối ưu được thì làm giúp tui
   Phần thêm vào chỉ phục vụ debug và phần thêm vào cơ chế đều sẽ được note 
   Mục tiêu đã đạt được: Chức năng đồng bộ đã được kiểm chứng
                         Code đã thực hiện được việc điều khiển, tính toán, lưu trữ các dữ liệu vào OM tương ứng và transfer dữ liệu từ OM1 đến OM2
                         Đã kiểm tra 4/4 ảnh, phân bổ kết quả của chương trình mô phỏng đúng với phân bố trong dense_output của từng hình
   Mục tiêu chưa đạt được: Dù có phân bố giống nhau nhưng kết quả dạng hex của chương trình mô phỏng lại khác với kết quả dạng hex convert từ file dense_output
*/

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
) uut2 (
    .clk(clk),
    .rst(rst),
    .start(start),
    .wen_MCMem(wen_MCMem_2),
    .addr_w_MCMem(addr_w_MCMem_2),
    .data_w_MCMem(data_w_MCMem_2),
    
    .vsync_in(vsync_out_2),             // do chỉ có 1 ASIP trên 1 cột nên vsync_in = vsync_out
    .hsync_in(hsync_in_all),
    .vsync_out(vsync_out_2),
    .hsync_out(hsync_out_2),
    .start_DNN_core(start_DNN_core_2),
    .end_flag(end_flag_2),
//PORT0 ==============
    .command_P0_in(command_P0_out_1),       // ASIP 1 PORT0 out -> ASIP 2 PORT0 in
    .data_P0_in(data_P0_out_1),
    .command_P0_out(command_P0_out_2),
    .data_P0_out(data_P0_out_2),
//PORT1
    .command_P1_in(command_P1_in_2),
    .data_P1_in(data_P1_in_2),
    .command_P1_out(command_P1_out_2),
    .data_P1_out(data_P1_out_2),
//PORT OM
    .addr_OM(addr_OM_2),
    .wen_OM(wen_OM_2),
    .ren_OM(ren_OM_2),
    .data_r_OM(data_r_OM_2),
    .data_w_OM(data_w_OM_2),
    .ren_OM_inst(ren_OM_inst_2),
    .inst_r_OM(inst_r_OM_2),
//PORT DNN core
    .addr_DNN(addr_DNN_2),
    .wen_inst_mem(wen_inst_mem_2),
    .wen_IB(wen_IB_2),
    .wen_KSP(wen_KSP_2),
    .wen_BSP(wen_BSP_2),
    .ren_OB(ren_OB_2),
    .data_w_DNN(data_w_DNN_2),
    .inst_w_DNN(inst_w_DNN_2),
    .done_transfer_prev(done_transfer_1),       // = done transfer của ASIP trước
    .done_transfer(done_transfer_2),

    .done_DNN(done_DNN_2),
    .DSIP_done(DSIP_done_2),
    .done_vtransfer_prev(done_vtransfer_prev_2),
    .done_vtransfer(done_vtransfer_2)
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
    if(wen_OM_1) OM_mem_1[addr_OM_1] <= data_w_OM_1;
    else if(ren_OM_1) data_read_from_OM_1 <= OM_mem_1[addr_OM_1];
end
assign data_r_OM_1 = data_read_from_OM_1;

reg [INSTRUCTION_WIDTH_DNN_CORE-1:0] OM_mem_1_inst[0:65535];
reg [INSTRUCTION_WIDTH_DNN_CORE-1:0] inst_read_from_OM_1;
always @(posedge clk) begin
    if(ren_OM_inst_1) inst_read_from_OM_1 <= OM_mem_1_inst[addr_OM_1];
end
assign inst_r_OM_1 = inst_read_from_OM_1;
//==========================================================================

// CODE MO PHONG OM2 ========================================================
reg [DATA_WIDTH_DNN_CORE - 1:0] OM_mem_2[0:1879048192];
reg [DATA_WIDTH_DNN_CORE - 1:0] data_read_from_OM_2;
always @(posedge clk) begin
    if(wen_OM_2) OM_mem_2[addr_OM_2] <= data_w_OM_2;
    else if(ren_OM_2) data_read_from_OM_2 <= OM_mem_2[addr_OM_2];
end
assign data_r_OM_2 = data_read_from_OM_2;

reg [INSTRUCTION_WIDTH_DNN_CORE-1:0] OM_mem_2_inst[0:65535];
reg [INSTRUCTION_WIDTH_DNN_CORE-1:0] inst_read_from_OM_2;
always @(posedge clk) begin
    if(ren_OM_inst_2) inst_read_from_OM_2 <= OM_mem_2_inst[addr_OM_2];
end
assign inst_r_OM_2 = inst_read_from_OM_2;
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
    file = $fopen("C:/Users/nguye/Desktop/KTMT/DSIP/old_design/Hardware Design/VivadoProject/Hardware_ASIP_SV_IPandOpt/4983_hex.txt", "r");
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
    file = $fopen("C:/Users/nguye/Desktop/KTMT/DSIP/KV260/Binary_Instruction_Parameters/binary_parameter/test_model_1_1/weights_conv0_hex.txt", "r");
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
    file = $fopen("C:/Users/nguye/Desktop/KTMT/DSIP/KV260/Binary_Instruction_Parameters/binary_parameter/test_model_1_1/biases_conv0_hex.txt", "r");
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
  parameter OFFSET = 32'h00010640; // Offset để gán dữ liệu bắt đầu từ vị trí 100
//  reg [DATA_WIDTH-1:0] data_array [0:ARRAY_SIZE-1]; // Mảng lưu dữ liệu
  integer file, r, line_number; // Biến tạm cho file và dòng dữ liệu
  reg [255:0] line; // Chuỗi tạm để đọc từng dòng
  reg [DATA_WIDTH-1:0] temp_data; // Biến tạm để lưu dữ liệu từ dòng
  initial begin
    // Gán giá trị mặc định cho mảng
    integer i;
    // Mở file txt
    file = $fopen("C:/Users/nguye/Desktop/KTMT/DSIP/KV260/Binary_Instruction_Parameters/binary_parameter/test_model_1_1/weights_dense0_hex.txt", "r");
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
  parameter OFFSET = 32'h00410640; // Offset để gán dữ liệu bắt đầu từ vị trí 100
//  reg [DATA_WIDTH-1:0] data_array [0:ARRAY_SIZE-1]; // Mảng lưu dữ liệu
  integer file, r, line_number; // Biến tạm cho file và dòng dữ liệu
  reg [255:0] line; // Chuỗi tạm để đọc từng dòng
  reg [DATA_WIDTH-1:0] temp_data; // Biến tạm để lưu dữ liệu từ dòng
  initial begin
    // Gán giá trị mặc định cho mảng
    integer i;
    // Mở file txt
    file = $fopen("C:/Users/nguye/Desktop/KTMT/DSIP/KV260/Binary_Instruction_Parameters/binary_parameter/test_model_1_1/biases_dense0_hex.txt", "r");
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
reg [31:0] controller_instruction_temp_1[0:5000];       // chứa tạm instructions của ASIP 1
reg [31:0] controller_instruction_temp_2[0:5000];       // chứa tạm instructions của ASIP 2

// Stimulus
initial begin   
    // Nạp lệnh cho Controller 1
//   $readmemb("C:/Users/nguye/Desktop/KTMT/DSIP/KV260/Binary_Instruction_Parameters/binary_instruction/test_model_1_1/instructions_ASIP1_MC_bin.txt",controller_instruction_temp_1);
   $readmemb("C:/Users/nguye/Desktop/KTMT/DSIP/KV260/Binary_Instruction_Parameters/binary_instruction/test_model_1_1/instructions_ASIP1_MC_bin.txt",controller_instruction_temp_1);
   // Nạp lệnh cho DNN Core 1
   $readmemb("C:/Users/nguye/Desktop/KTMT/DSIP/KV260/Binary_Instruction_Parameters/binary_instruction/test_model_1_1/instruction_ASIP1_SC_bin.txt",OM_mem_1_inst);
   $display("OM_mem_1_inst[0] = %b", OM_mem_1_inst[0]);
    // Nạp lệnh cho Controller 2
//   $readmemb("C:/Users/nguye/Desktop/KTMT/DSIP/KV260/Binary_Instruction_Parameters/binary_instruction/test_model_1_1/instructions_ASIP2_MC_bin.txt",controller_instruction_temp_2);
   $readmemb("C:/Users/nguye/Desktop/KTMT/DSIP/KV260/Binary_Instruction_Parameters/binary_instruction/test_model_1_1/instructions_ASIP2_MC_bin.txt",controller_instruction_temp_2);
    // Nạp lệnh cho DNN Core 2
   $readmemb("C:/Users/nguye/Desktop/KTMT/DSIP/KV260/Binary_Instruction_Parameters/binary_instruction/test_model_1_1/instruction_ASIP2_SC_bin.txt",OM_mem_2_inst);
    // Nạp lệnh cho Controller 1
//   $readmemb("instruction_ASIP1_MC_bin.txt",controller_instruction_temp_1);
//   // Nạp lệnh cho DNN Core 1
//   $readmemb("instruction_ASIP1_SC_bin.txt",OM_mem_1_inst);
//    // Nạp lệnh cho Controller 2
//   $readmemb("instruction_ASIP2_MC_bin.txt",controller_instruction_temp_2);
//    // Nạp lệnh cho DNN Core 2
//   $readmemb("instruction_ASIP2_SC_bin.txt",OM_mem_2_inst);
    
   rst = 1;
   #400
   rst = 0;
   // Xử lý nạp lệnh của Controller 1 vào mem 
   foreach(controller_instruction_temp_1[i]) begin #10
       wen_MCMem_1 = 1;
       addr_w_MCMem_1 = i;
       data_w_MCMem_1 = controller_instruction_temp_1[i];
       if(i == 1024) break;
   end
   // Xử lý nạp lệnh của Controller 2 vào mem
   foreach(controller_instruction_temp_2[i]) begin #10
       wen_MCMem_2 = 1;
       addr_w_MCMem_2 = i;
       data_w_MCMem_2 = controller_instruction_temp_2[i];
       if(i == 1024) break;
   end
   
   #10
   start = 1;
   #10
   start = 0;
end
// === Các khối ở dưới dùng để debug ===
  integer A = 116;
  integer count_PC_hit_A = 0;
  bit was_at_A = 0;
  // task này viết dùng để test 4 hình từ 4 file liên tiếp 
  task read_if(input string filepath, input int unsigned OFFSET);
  parameter DATA_WIDTH = 16;
  parameter ARRAY_SIZE = 1879048192;

  integer file, r, line_number;
  reg [255:0] line;
  reg [DATA_WIDTH-1:0] temp_data;

  begin
    file = $fopen(filepath, "r");
    if (file == 0) begin
      $display("Không thể mở file: %s", filepath);
      disable read_if;
    end

    line_number = 0;
    while (!$feof(file)) begin
      r = $fgets(line, file);
      if (r) begin
        r = $sscanf(line, "%h", temp_data);
        if (r == 1) begin
          if (line_number + OFFSET < ARRAY_SIZE) begin
            OM_mem_1[line_number + OFFSET] = temp_data;
          end else begin
            $display("Dữ liệu vượt kích thước mảng, dòng %0d sẽ bị bỏ qua.", line_number);
          end
          line_number++;
        end else begin
          $display("Dòng %0d không hợp lệ: %s", line_number, line);
        end
      end
    end

    $fclose(file);
//    $display("Đã đọc xong file: %s", filepath);
  end
endtask: read_if
  int start_addr_2 = 32'h004222A0;
  int num_words = 10;
  // Khối này là để đếm xem số vòng lặp qua 1 điểm nào đó là bao nhiêu, tui dùng để debug các loại vòng lặp, vòng này bắt đầu từ A, đếm số lần PC qua A rồi quay lại A
  // Hiện tại thì vòng đang dùng để kiểm tra 4 ảnh liên tiếp
  

////
////
////
//always @(posedge uut2.clk) begin
//    if (uut2.controller.PC == A) begin
//            count_PC_hit_A = count_PC_hit_A + 1;
//            $display("PC vừa chạm mốc %0d tại thời điểm %0t -> Đếm: %0d", A, $time, count_PC_hit_A + 1);
//                if(count_PC_hit_A == 1) read_if("C:/Users/nguye/Desktop/KTMT/DSIP/old_design/Hardware Design/VivadoProject/Hardware_ASIP_SV_IPandOpt/0949_hex.txt",32'h00010000);
//                else if(count_PC_hit_A == 2) read_if("C:/Users/nguye/Desktop/KTMT/DSIP/old_design/Hardware Design/VivadoProject/Hardware_ASIP_SV_IPandOpt/0973_hex.txt",32'h00010000);
////                else if(count_PC_hit_A == 3) read_if("C:/Users/nguye/Desktop/KTMT/DSIP/old_design/Hardware Design/VivadoProject/Hardware_ASIP_SV_IPandOpt/0976_hex.txt",32'h00010000);
//    end
//end 
////
////
////







// Lấy 1000 ảnh /////////////////////////////////////////////////////
string image_files [0:999];
initial begin
    for (int i = 0; i < 1000; i++) begin
        // Tạo tên file kiểu image_000.hex.txt
        image_files[i] = $sformatf("C:/Users/nguye/Desktop/KTMT/38.DSIP_Quân_Bách/Hardware Design/KLTN/1000images/saved_images_hex/image_%03d.txt", i);
    end
end




int counter_img = -2;
int temp_mem[10];
function automatic int argmax(input int arr[], input int size);
    int max_val = arr[0];
    int max_idx = 0;
    int count = 1;  // đếm số lần xuất hiện của max

    for (int i = 1; i < size; i++) begin
        if (arr[i] > max_val) begin
            max_val = arr[i];
            max_idx = i;
            count = 1;
        end else if (arr[i] == max_val) begin
            count++;
        end
    end

    if (count > 1)
        return -1;  // nhiều phần tử cùng max → không xác định
    else
        return max_idx;
endfunction

//integer file;
//initial begin
//    file = $fopen("test_result.mem", "w");  // "w" để ghi mới
//    if (!file) $fatal("Không thể mở file!");
//end

always @(posedge uut2.clk) begin
    if (uut2.controller.PC == A) begin
        count_PC_hit_A = count_PC_hit_A + 1;
//        $display("PC vừa chạm mốc %0d tại thời điểm %0t -> Đếm: %0d", A, $time, count_PC_hit_A);

        if (count_PC_hit_A <= 1000) begin
            read_if(image_files[count_PC_hit_A - 1], 32'h00010000);
        end
        
        for (int i = 0; i < 10; i++) begin
            temp_mem[i] = uut2.dnn_core.OB.mem[i];  // copy từng phần tử từ reg sang int
        end
        $display("FILE: image_%03d.jpg  -   PREDICTION RESULT: %2d", counter_img, argmax(temp_mem, 10));
//        $fdisplay(file, "FILE: image_%03d.jpg  -   RESULT: %2d", counter_img, argmax(temp_mem, 10));

        counter_img = counter_img + 1;
    end
    
end
//////////////////////////////////////////////////////////////












int stop_pc = 116;
/* Khối này là khối ngắt chương trình khi PC đến stop PC, có thể đổi uut2 thành uut1 và ngược lại, khi thỏa điều kiện thì sẽ display ra các kết quả
 Đang display các kết quả trong dense ( OM_mem_2 )
 Kết quả đầu tiên xuất hiện có thể là kết quả nhiễu hoặc cũ, kết quả thứ hai và thứ ba là kết quả của hình 4983, kết quả thứ tư là của 0949, kết quả thứ năm là của 0973, và kết quả cuối cùng là của 0976*/
always @(posedge uut2.clk) begin
    if (uut2.controller.PC == stop_pc) begin
//        $display("=== STOPPING: PC reached %0d ===", stop_pc);
//        $display("Dumping %0d OM_mem_2 words starting from address %0d", num_words, start_addr_2);
        for (int i = 0; i < num_words; i++) begin
//          uncomment dòng sau để hiển thị từ OM_mem_1
//          $display("OM_mem_1[%0d] = %h", start_addr + i, OM_mem_1[start_addr + i]);
//          Lấy data từ OM_mem_2 để chắc rằng kquả đã được lưu vào mem
//            $display("OM_mem_2[%0d] = %h", start_addr_2 + i, OM_mem_2[start_addr_2 + i]);
        end
//        $stop;
    end
end

endmodule
