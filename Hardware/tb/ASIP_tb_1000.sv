`timescale 1ns / 1ps
`define SINGLE 1
`define ONE_ONE 2
`define TWO_TWO 3


module ASIP_tb_1000;

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
parameter MODEL = `SINGLE;
parameter IS_FIRST_ROW = 1;
parameter IS_FIRST_COL = 1;


// Inputs
bit clk;
bit rst;
bit start;
bit wen_MCMem;
bit [$clog2(MCMEM_SIZE)-1:0] addr_w_MCMem;
bit [INSTRUCTION_WIDTH-1:0] data_w_MCMem;
bit vsync_in;
bit hsync_in;
bit all_DNN_done_signal;
wire vsync_out;
wire hsync_out;
wire start_DNN_core;
wire end_flag;

//PORT0 ==============
bit [67:0] command_P0_in;
bit [15:0] data_P0_in;
wire [67:0] command_P0_out;
wire [15:0] data_P0_out;

//PORT1
bit [67:0] command_P1_in;
bit [15:0] data_P1_in;
wire [67:0] command_P1_out;
wire [15:0] data_P1_out;


//PORT OM
wire [31:0] addr_OM;
wire wen_OM;
wire ren_OM;
bit [31:0] data_r_OM;
wire [31:0] data_w_OM;
wire ren_OM_inst;
bit [211:0] inst_r_OM;

//PORT DNN core
wire [8:0] addr_DNN;
wire wen_inst_mem;
wire [63:0] wen_IB;
wire [63:0] wen_KSP;
wire wen_BSP;
wire ren_OB;
wire [31:0] data_w_DNN;
wire [211:0] inst_w_DNN;
bit done_transfer_prev;
wire done_transfer;

wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_write_OB;
wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_read_OB;

bit [7:0] select;

wire [DATA_WIDTH_DNN_CORE - 1 : 0] NEOA_read_out;
wire sel_lut;

wire [DATA_WIDTH_DNN_CORE - 1 : 0] li_data_out;

wire [DATA_WIDTH_DNN_CORE - 1 : 0] POA_read_out;


wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_write_OSP_ML_out;
wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_write_OSP_CONV_out;
wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_write_FCSP_ML_out;
wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_write_OB_ML_out;
wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_read_OB_ML_out;
wire [DATA_WIDTH_DNN_CORE - 1 : 0] OB_read_out;
wire [DATA_WIDTH_DNN_CORE - 1 : 0] MEM_read_out;

wire [$clog2(SCRATCHPAD_SIZE)-1:0] addr_read_IB;
wire done_DNN;

wire DSIP_done;

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
    .MODEL(MODEL),
    .IS_FIRST_ROW(IS_FIRST_ROW),
    .IS_FIRST_COL(IS_FIRST_COL)
) uut (
    .clk(clk),
    .rst(rst),
    .start(start),
    .wen_MCMem(wen_MCMem),
    .addr_w_MCMem(addr_w_MCMem),
    .data_w_MCMem(data_w_MCMem),
    
    .vsync_in(vsync_out),
    .hsync_in(hsync_in),
//    .all_DNN_done_signal(done_DNN),
    .vsync_out(vsync_out),
    .hsync_out(hsync_out),
    .start_DNN_core(start_DNN_core),
    .end_flag(end_flag),
//PORT0 ==============
    .command_P0_in(command_P0_in),
    .data_P0_in(data_P0_in),
    .command_P0_out(command_P0_out),
    .data_P0_out(data_P0_out),
//PORT1
    .command_P1_in(command_P1_in),
    .data_P1_in(data_P1_in),
    .command_P1_out(command_P1_out),
    .data_P1_out(data_P1_out),
//PORT OM
    .addr_OM(addr_OM),
    .wen_OM(wen_OM),
    .ren_OM(ren_OM),
    .data_r_OM(data_r_OM),
    .data_w_OM(data_w_OM),
    .ren_OM_inst(ren_OM_inst),
    .inst_r_OM(inst_r_OM),
//PORT DNN core
    .addr_DNN(addr_DNN),
    .wen_inst_mem(wen_inst_mem),
    .wen_IB(wen_IB),
    .wen_KSP(wen_KSP),
    .wen_BSP(wen_BSP),
    .ren_OB(ren_OB),
    .data_w_DNN(data_w_DNN),
    .inst_w_DNN(inst_w_DNN),
    .done_transfer_prev(done_transfer_prev),
    .done_transfer(done_transfer),

    .done_DNN(done_DNN),
    .DSIP_done(DSIP_done)
);



// Clock generation
initial begin
    clk = 0;
    forever #5 clk = ~clk; // 100 MHz clock
end


// CODE MO PHONG OM ========================================================
reg [DATA_WIDTH_DNN_CORE - 1:0] OM_mem[0:1879048192];
reg [DATA_WIDTH_DNN_CORE - 1:0] data_read_from_OM;
always @(posedge clk) begin
    if(wen_OM) OM_mem[addr_OM] <= data_w_OM;
    else if(ren_OM) data_read_from_OM <= OM_mem[addr_OM];
end
assign data_r_OM = data_read_from_OM;

reg [INSTRUCTION_WIDTH_DNN_CORE-1:0] OM_mem_inst[0:65535];
reg [INSTRUCTION_WIDTH_DNN_CORE-1:0] inst_read_from_OM;
always @(posedge clk) begin
    if(ren_OM_inst) inst_read_from_OM <= OM_mem_inst[addr_OM];
end
assign inst_r_OM = inst_read_from_OM;
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
    file = $fopen("D:/ST/DSIP/codeDSIP/venv/model_tiny_test/0973_hex.txt", "r");
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
            OM_mem[line_number + OFFSET] = temp_data; // Gán từ vị trí OFFSET
//            $display("Đọc dòng %0d: %h -> Gán vào OM_mem[%0d]", line_number, temp_data, line_number + OFFSET);
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
    file = $fopen("D:/ST/DNN_SIP/Traffic Object Detection/Hardware Design/KLTN/binary_parameter/test_model_1/weights_conv0_hex.txt", "r");
    
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
            OM_mem[line_number + OFFSET] = temp_data; // Gán từ vị trí OFFSET
//            $display("Đọc dòng %0d: %h -> Gán vào OM_mem[%0d]", line_number, temp_data, line_number + OFFSET);
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
    file = $fopen("D:/ST/DNN_SIP/Traffic Object Detection/Hardware Design/KLTN/binary_parameter/test_model_1/biases_conv0_hex.txt", "r");
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
            OM_mem[line_number + OFFSET] = temp_data; // Gán từ vị trí OFFSET
//            $display("Đọc dòng %0d: %h -> Gán vào OM_mem[%0d]", line_number, temp_data, line_number + OFFSET);
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
  end
endmodule






// doc dense0 weights
module read_weights_dense0;
  // Định nghĩa các tham số và mảng
  parameter DATA_WIDTH = 16;  // Độ rộng dữ liệu (16 bit)
  parameter ARRAY_SIZE = 1879048192; // Kích thước mảng
  parameter OFFSET = 32'h000133A0; // Offset để gán dữ liệu bắt đầu từ vị trí 100
//  reg [DATA_WIDTH-1:0] data_array [0:ARRAY_SIZE-1]; // Mảng lưu dữ liệu
  integer file, r, line_number; // Biến tạm cho file và dòng dữ liệu
  reg [255:0] line; // Chuỗi tạm để đọc từng dòng
  reg [DATA_WIDTH-1:0] temp_data; // Biến tạm để lưu dữ liệu từ dòng
  initial begin
    // Gán giá trị mặc định cho mảng
    integer i;
    // Mở file txt
    file = $fopen("D:/ST/DNN_SIP/Traffic Object Detection/Hardware Design/KLTN/binary_parameter/test_model_1/weights_dense0_hex.txt", "r");
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
            OM_mem[line_number + OFFSET] = temp_data; // Gán từ vị trí OFFSET
//            $display("Đọc dòng %0d: %h -> Gán vào OM_mem[%0d]", line_number, temp_data, line_number + OFFSET);
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
  end
endmodule


// doc dense0 biases
module read_biases_dense0;
  // Định nghĩa các tham số và mảng
  parameter DATA_WIDTH = 16;  // Độ rộng dữ liệu (16 bit)
  parameter ARRAY_SIZE = 1879048192; // Kích thước mảng
  parameter OFFSET = 32'h004133A0; // Offset để gán dữ liệu bắt đầu từ vị trí 100
//  reg [DATA_WIDTH-1:0] data_array [0:ARRAY_SIZE-1]; // Mảng lưu dữ liệu
  integer file, r, line_number; // Biến tạm cho file và dòng dữ liệu
  reg [255:0] line; // Chuỗi tạm để đọc từng dòng
  reg [DATA_WIDTH-1:0] temp_data; // Biến tạm để lưu dữ liệu từ dòng
  initial begin
    // Gán giá trị mặc định cho mảng
    integer i;
    // Mở file txt
    file = $fopen("D:/ST/DNN_SIP/Traffic Object Detection/Hardware Design/KLTN/binary_parameter/test_model_1/biases_dense0_hex.txt", "r");
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
            OM_mem[line_number + OFFSET] = temp_data; // Gán từ vị trí OFFSET
//            $display("Đọc dòng %0d: %h -> Gán vào OM_mem[%0d]", line_number, temp_data, line_number + OFFSET);
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
  end
endmodule






// ============================================================================
// TEST 1000 IMAGES - SINGLE MODEL
// Cách dùng:
// 1) Sửa IMAGE_DIR đúng thư mục chứa image_000.txt ... image_999.txt.
// 2) Nếu kết quả bị lệch tên ảnh, chỉnh RESULT_LATENCY_HITS = 0/1/2.
//    Với flow hiện tại của bản 1-1 đang dùng offset 2 lần chạm PC, nên mặc định để 2.
// 3) RESULT_PC phải là PC tại điểm kết thúc 1 vòng inference / điểm nạp ảnh mới.
//    Bản đang debug dùng PC = 116.
// ============================================================================
localparam int NUM_IMAGES = 1000;
localparam int NUM_CLASSES = 10;
localparam int RESULT_PC = 116;
localparam int RESULT_LATENCY_HITS = 2;
localparam int unsigned INPUT_OFFSET = 32'h00010000;

string IMAGE_DIR = "D:/ST/DNN_SIP/Traffic Object Detection/Hardware Design/KLTN/1000images/saved_images_hex";
string image_files [0:NUM_IMAGES-1];

int next_image_idx = 0;
int result_img_idx = -RESULT_LATENCY_HITS;
int temp_mem [0:NUM_CLASSES-1];
int result_file;
bit was_at_RESULT_PC = 1'b0;

task automatic build_image_file_list;
    for (int i = 0; i < NUM_IMAGES; i++) begin
        image_files[i] = $sformatf("%s/image_%03d.txt", IMAGE_DIR, i);
    end
endtask

task automatic read_if(input string filepath, input int unsigned OFFSET);
    integer file, r, line_number;
    reg [255:0] line;
    reg [DATA_WIDTH_DNN_CORE-1:0] temp_data;
    begin
        file = $fopen(filepath, "r");
        if (file == 0) begin
            $display("[%0t] ERROR: Khong the mo file image: %s", $time, filepath);
            $finish;
        end

        line_number = 0;
        while (!$feof(file)) begin
            r = $fgets(line, file);
            if (r) begin
                r = $sscanf(line, "%h", temp_data);
                if (r == 1) begin
                    OM_mem[OFFSET + line_number] = temp_data;
                    line_number++;
                end
                else begin
                    $display("[%0t] WARNING: Dong %0d khong hop le trong file %s: %s",
                             $time, line_number, filepath, line);
                end
            end
        end
        $fclose(file);
        $display("[%0t] Loaded image %0d/%0d: %s (%0d words)",
                 $time, next_image_idx + 1, NUM_IMAGES, filepath, line_number);
    end
endtask

function automatic int argmax(input int arr[], input int size);
    int max_val;
    int max_idx;
    int same_max_count;
    begin
        max_val = arr[0];
        max_idx = 0;
        same_max_count = 1;

        for (int i = 1; i < size; i++) begin
            if (arr[i] > max_val) begin
                max_val = arr[i];
                max_idx = i;
                same_max_count = 1;
            end
            else if (arr[i] == max_val) begin
                same_max_count++;
            end
        end

        if (same_max_count > 1)
            return -1;
        else
            return max_idx;
    end
endfunction

initial begin
    build_image_file_list();
    result_file = $fopen("single_1000_result.txt", "w");
    if (result_file == 0) begin
        $display("[%0t] WARNING: Khong the mo file single_1000_result.txt de ghi ket qua", $time);
    end
end

always @(posedge clk) begin
    if (rst) begin
        was_at_RESULT_PC <= 1'b0;
    end
    else begin
        // Bắt cạnh PC == RESULT_PC để tránh đếm nhiều lần nếu PC đứng tại RESULT_PC nhiều chu kỳ
        if ((uut.controller.PC == RESULT_PC) && !was_at_RESULT_PC) begin
            was_at_RESULT_PC <= 1'b1;

            // Nạp ảnh kế tiếp vào vùng input OM cho vòng inference tiếp theo
            if (next_image_idx < NUM_IMAGES) begin
                read_if(image_files[next_image_idx], INPUT_OFFSET);
                next_image_idx++;
            end

            // Đọc kết quả từ OB. Bỏ qua vài hit đầu nếu pipeline còn warm-up.
            if ((result_img_idx >= 0) && (result_img_idx < NUM_IMAGES)) begin
                for (int i = 0; i < NUM_CLASSES; i++) begin
                    temp_mem[i] = $signed(uut.dnn_core.OB.mem[i]);
                end

                $display("[%0t] FILE: image_%03d.jpg  -  PREDICTION RESULT: %0d",
                         $time, result_img_idx, argmax(temp_mem, NUM_CLASSES));

                if (result_file != 0) begin
                    $fdisplay(result_file,
                              "FILE: image_%03d.jpg  -  PREDICTION RESULT: %0d",
                              result_img_idx, argmax(temp_mem, NUM_CLASSES));
                end
            end

            result_img_idx++;

            if (result_img_idx >= NUM_IMAGES) begin
                $display("[%0t] DONE: da lay du ket qua cho %0d images", $time, NUM_IMAGES);
                if (result_file != 0) $fclose(result_file);
                $finish;
            end
        end
        else if (uut.controller.PC != RESULT_PC) begin
            was_at_RESULT_PC <= 1'b0;
        end
    end
end

//doc controller instruction
reg [31:0] controller_instruction_temp[0:5000];
// Stimulus
initial begin   
   $readmemb("D:/ST/DNN_SIP/Traffic Object Detection/Hardware Design/KLTN/binary_instruction/test_model_1/instructions_controller_core.txt",controller_instruction_temp);
   $readmemb("D:/ST/DNN_SIP/Traffic Object Detection/Hardware Design/KLTN/binary_instruction/test_model_1/instructions_DNN_core.txt",OM_mem_inst);

   rst = 1;
   #400
   rst = 0;
   // Nap lenh của controller vào mem
   foreach(controller_instruction_temp[i]) begin #10
       wen_MCMem = 1;
       addr_w_MCMem = i;
       data_w_MCMem = controller_instruction_temp[i];
       if(i == 1024) break;
   end
   
   #10
   start = 1;
   #10
   start = 0;
end

endmodule

