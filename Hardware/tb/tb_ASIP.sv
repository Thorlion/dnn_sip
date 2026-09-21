`timescale 1ns / 1ps
`define SINGLE 1
`define ONE_ONE 2
`define TWO_TWO 3

module tb_ASIP;
// Parameters
    parameter MODEL         = `SINGLE;
    parameter IS_FIRST_ROW  = 1;
    parameter IS_FIRST_COL  = 1; 
    parameter INSTR_W       = 32;               
    parameter MCMEM_W       = 4096;
    parameter DATA_W_MC     = 32;
    parameter ADDR_W        = 32;
    parameter BASE_DATA_OM  = 32'h00010000;
    
    // DNN core parameters
    parameter DATA_W_DNN    = 16;
    parameter DECIMAL_BIT   = 8;
    parameter INSTR_W_DNN   = 212;
    parameter BUFFER_SIZE   = 512;
    parameter SCRATCHPAD_W  = 512;
    parameter BLOCKS_PER_ROW= 64;

    logic                       clk;
    logic                       rst;
    logic                       start;

    logic                       mcmem_wen;
    logic [$clog2(MCMEM_W)-1:0] mcmem_wr_addr;          // [11:0]
    logic [INSTR_W-1:0]         mcmem_wr_data;

    // MODE controller
    logic                       vsync_in;
    logic                       hsync_in;

    logic                       vsync_out;
    logic                       hsync_out;
    logic                       start_DNN;
    logic                       end_flag;
    
    //PORT0 =================================================
    logic [67:0]                command_P0_in;
    logic [15:0]                data_P0_in;
    logic [67:0]                command_P0_out;
    logic [15:0]                data_P0_out;
    
    //PORT1 =================================================
    logic [67:0]                command_P1_in;
    logic [15:0]                data_P1_in;
    logic [67:0]                command_P1_out;
    logic [15:0]                data_P1_out;

    //PORT OM ================================================
    logic [ADDR_W-1:0]          OM_addr;
    logic                       OM_wen;
    logic                       OM_ren;
    logic [31:0]                OM_rd_data;
    logic [31:0]                OM_wr_data;
    logic                       OM_inst_ren;
    logic [211:0]               OM_inst_rd;

    //PORT DNN core ==========================================
    logic [8:0]                 DNN_addr;
    logic                       mem_inst_wen;
    logic [63:0]                IB_wen;
    logic [63:0]                KSP_wen;
    logic                       BSP_wen;
    logic                       OB_ren;
    logic [31:0]      DNN_wr_data;
    logic [INSTR_W_DNN-1:0]     DNN_inst_wr;

    logic                       done_transfer_prev;
    logic                       done_transfer;
    
    logic [DATA_W_DNN-1:0]      OB_data_read;
    logic [DATA_W_DNN-1:0]      MEM_data_read;
    logic                       dnn_done;

    ASIP #(
        .MODEL(MODEL),
        .IS_FIRST_ROW(IS_FIRST_ROW),
        .IS_FIRST_COL(IS_FIRST_COL),
        .INSTR_W(INSTR_W),
        .MCMEM_W(MCMEM_W),
        .DATA_W_MC(DATA_W_MC),
        .ADDR_W(ADDR_W),
        .BASE_DATA_OM(BASE_DATA_OM),

        .DATA_W_DNN(DATA_W_DNN),
        .DECIMAL_BIT(DECIMAL_BIT),
        .INSTR_W_DNN(INSTR_W_DNN),
        .BUFFER_SIZE(BUFFER_SIZE),
        .SCRATCHPAD_W(SCRATCHPAD_W),
        .BLOCKS_PER_ROW(BLOCKS_PER_ROW)
    )dut(
        .clk(clk),
        .rst(rst),
        .start(start),

        .mcmem_wen(mcmem_wen),
        .mcmem_wr_addr(mcmem_wr_addr),
        .mcmem_wr_data(mcmem_wr_data),
        
        // MODE controller
        .vsync_in(vsync_out),
        .hsync_in(hsync_in),

        .vsync_out(vsync_out),
        .hsync_out(hsync_out),
        .start_DNN(start_DNN),
        .end_flag(end_flag),
        
        //PORT0 ==============
        .command_P0_in(command_P0_in),
        .data_P0_in(data_P0_in),
        .command_P0_out(command_P0_out),
        .data_P0_out(data_P0_out),
        
        //PORT1 ==============
        .command_P1_in(command_P1_in),
        .data_P1_in(data_P1_in),
        .command_P1_out(command_P1_out),
        .data_P1_out(data_P1_out),
        
        //PORT OM ==============
        .OM_addr(OM_addr),
        .OM_wen(OM_wen),
        .OM_ren(OM_ren),
        .OM_rd_data(OM_rd_data),
        .OM_wr_data(OM_wr_data),
        .OM_inst_ren(OM_inst_ren),
        .OM_inst_rd(OM_inst_rd),
        
        //PORT DNN core ==============
        .DNN_addr(DNN_addr),
        .mem_inst_wen(mem_inst_wen),
        .IB_wen(IB_wen),
        .KSP_wen(KSP_wen),
        .BSP_wen(BSP_wen),
        .OB_ren(OB_ren),
        .DNN_wr_data(DNN_wr_data),
        .DNN_inst_wr(DNN_inst_wr),
        
        .done_transfer_prev(done_transfer_prev),
        .done_transfer(done_transfer),
        
        .OB_data_read(OB_data_read),
        .MEM_data_read(MEM_data_read),

        .dnn_done(dnn_done)
    );
    
    // Captured OB[0] through OB[9] for the Vivado waveform.
    // DNN_Core uses the MEMOB IP (instance OBIP), so its storage array is not
    // directly visible. At completion, temporarily drive the asynchronous
    // OB read address and save each returned value into waveform-visible regs.
    logic signed [DATA_W_DNN-1:0] ob_wave [0:9];
    logic [$clog2(SCRATCHPAD_W)-1:0] ob_probe_addr;
    integer ob_index;

    always @(posedge end_flag) begin
        force dut.dnn_core.OB_NL_rd_addr = ob_probe_addr;

        for (ob_index = 0; ob_index < 10; ob_index = ob_index + 1) begin
            ob_probe_addr = ob_index;
            #1ns; // MEMOB dpo is asynchronous; allow it to settle.
            ob_wave[ob_index] = $signed(OB_data_read);
            $display("[%0t] OB[%0d] = 0x%h (%0d)",
                     $time, ob_index, ob_wave[ob_index], ob_wave[ob_index]);
        end

        release dut.dnn_core.OB_NL_rd_addr;
    end

    // Clock generator
    initial begin
        clk = '0;
        forever #5 clk = ~clk; // 100MHz
    end

    // SIMULATE OM ===================================
    logic [DATA_W_DNN-1:0] OM_mem [0:1879048192];
    logic [DATA_W_DNN-1:0] data_read_from_OM;

    always_ff @(posedge clk) begin
        if (OM_wen) begin
            OM_mem[OM_addr] <= OM_wr_data;
        end
        else if (OM_ren) begin
            data_read_from_OM <= OM_mem[OM_addr];
        end
    end
    assign OM_rd_data = data_read_from_OM;

    logic [INSTR_W_DNN-1:0] OM_mem_inst [0:65535];
    logic [INSTR_W_DNN-1:0] inst_read_from_OM;
    always_ff @(posedge clk) begin
        if (OM_inst_ren) begin
            inst_read_from_OM <= OM_mem_inst[OM_addr];
        end
    end
    assign OM_inst_rd = inst_read_from_OM;

    // Read Input Features =============================
    localparam DATA_W_IF = 16;                  // 16-bit data width
    localparam ARRAY_SIZE_IF = 1879048192;      // 2^27 (Array size)
    localparam OFFSET_IF = 32'h00010000;       // Offset to start reading from address 100
    module read_input_features;
        integer file, r, line_number;           // Temporary variables for file & line
        reg [255:0] line;                       // Temporary line to read each line
        logic [DATA_W_IF-1:0] temp_data;        // Temporary data to read each data
        initial begin
            integer i;
            file = $fopen("C:/Users/nguye/Desktop/KTMT/DSIP/old_design/Hardware Design/VivadoProject/Hardware_ASIP_SV_IPandOpt/0973_hex.txt", "r");
            if (file == 0) begin
                $display("Input feature file not found!");
                $finish;
            end
            line_number = '0;
            while (!$feof(file)) begin
                r = $fgets(line, file);         // Read line from file
                if (r) begin
                    r = $sscanf(line, "%h", temp_data);     // Read hex data from line
                    if (r == 1) begin
                    // Assign data to memory array with offset
                        if (line_number + OFFSET_IF < ARRAY_SIZE_IF) begin
                            OM_mem[line_number + OFFSET_IF] = temp_data;        // Assign from OFFSET
                        end else begin
                            $display("Input feature file too large!, line %0d will be skipped.", line_number);
                        end
                        line_number = line_number + 1;
                    end else begin
                        $display("Line %0d is not a valid hex number: %s", line_number, line);
                    end
                end
            end
            $fclose(file);
        end
    endmodule

    // Read Conv0 Weights =============================
    localparam DATA_W_C0W = 16;                  // 16-bit data width
    localparam ARRAY_SIZE_C0W = 1879048192;      // 2^27 (Array size)
    localparam OFFSET_C0W = 32'h00010C00;       // Offset to start reading from address 100
    module read_conv0_weights;
        integer file, r, line_number;           // Temporary variables for file & line
        logic [255:0] line;                     // Temporary line to read each line
        logic [DATA_W_C0W-1:0] temp_data;        // Temporary data to read each data
        initial begin
            integer i;
            file = $fopen("C:/Users/nguye/Desktop/KTMT/DSIP/KV260/Binary_Instruction_Parameters/binary_parameter/test_model_1/weights_conv0_hex.txt", "r");
            if (file == 0) begin
                $display("Conv0 weights file not found!");
                $finish;
            end    
            line_number = '0;
            while (!$feof(file)) begin
                r = $fgets(line, file);         // Read line from file
                if (r) begin
                    r = $sscanf(line, "%h", temp_data);     // Read hex data from line
                    if (r == 1) begin
                    // Assign data to memory array with offset
                        if (line_number + OFFSET_C0W < ARRAY_SIZE_C0W) begin
                            OM_mem[line_number + OFFSET_C0W] = temp_data;        // Assign from OFFSET
                        end else begin
                            $display("Conv0 weights file too large!, line %0d will be skipped.", line_number);
                        end
                        line_number = line_number + 1;
                    end else begin
                        $display("Line %0d is not a valid hex number: %s", line_number, line);
                    end
                end
            end
            $fclose(file);
        end
    endmodule

    // Read Conv0 Biases =============================
    localparam DATA_W_C0B = 16;                  // 16-bit data width
    localparam ARRAY_SIZE_C0B = 1879048192;      // 2^27 (Array size)
    localparam OFFSET_C0B = 32'h00010F60;       // Offset to start reading from address 100
    module read_conv0_biases;
        integer file, r, line_number;           // Temporary variables for file & line
        logic [255:0] line;                     // Temporary line to read each line
        logic [DATA_W_C0B-1:0] temp_data;        // Temporary data to read each data
        initial begin
            integer i;
            file = $fopen("C:/Users/nguye/Desktop/KTMT/DSIP/KV260/Binary_Instruction_Parameters/binary_parameter/test_model_1/biases_conv0_hex.txt", "r");
            if (file == 0) begin
                $display("Conv0 biases file not found!");
                $finish;
            end    
            line_number = '0;
            while (!$feof(file)) begin
                r = $fgets(line, file);         // Read line from file
                if (r) begin
                    r = $sscanf(line, "%h", temp_data);     // Read hex data from line
                    if (r == 1) begin
                    // Assign data to memory array with offset
                        if (line_number + OFFSET_C0B < ARRAY_SIZE_C0B) begin
                            OM_mem[line_number + OFFSET_C0B] = temp_data;        // Assign from OFFSET
                        end else begin
                            $display("Conv0 biases file too large!, line %0d will be skipped.", line_number);
                        end
                        line_number = line_number + 1;
                    end else begin
                        $display("Line %0d is not a valid hex number: %s", line_number, line);
                    end
                end
            end    
            $fclose(file);
        end
    endmodule

    // Read Dense0 Weights =============================
    localparam DATA_W_D0W = 16;                  // 16-bit data width
    localparam ARRAY_SIZE_D0W = 1879048192;      // 2^27 (Array size)
    localparam OFFSET_D0W = 32'h000133A0;       // Offset to start reading from address 100
    module read_dense0_weights;
        integer file, r, line_number;           // Temporary variables for file & line
        logic [255:0] line;                     // Temporary line to read each line
        logic [DATA_W_D0W-1:0] temp_data;        // Temporary data to read each data
        initial begin
            integer i;
            file = $fopen("C:/Users/nguye/Desktop/KTMT/DSIP/KV260/Binary_Instruction_Parameters/binary_parameter/test_model_1/weights_dense0_hex.txt", "r");
            if (file == 0) begin
                $display("Dense0 weights file not found!");
                $finish;
            end    
            line_number = '0;
            while (!$feof(file)) begin
                r = $fgets(line, file);         // Read line from file
                if (r) begin
                    r = $sscanf(line, "%h", temp_data);     // Read hex data from line
                    if (r == 1) begin
                    // Assign data to memory array with offset
                        if (line_number + OFFSET_D0W < ARRAY_SIZE_D0W) begin
                            OM_mem[line_number + OFFSET_D0W] = temp_data;        // Assign from OFFSET
                        end else begin
                            $display("Dense0 weights file too large!, line %0d will be skipped.", line_number);
                        end
                        line_number = line_number + 1;
                    end else begin
                        $display("Line %0d is not a valid hex number: %s", line_number, line);
                    end
                end
            end    
            $fclose(file);    
        end
    endmodule

    // Read Dense0 Biases =============================
    localparam DATA_W_D0B = 16;                  // 16-bit data width
    localparam ARRAY_SIZE_D0B = 1879048192;      // 2^27 (Array size)
    localparam OFFSET_D0B = 32'h004133A0;       // Offset to start reading from address 100
    module read_dense0_biases;  
        integer file, r, line_number;           // Temporary variables for file & line
        logic [255:0] line;                     // Temporary line to read each line
        logic [DATA_W_D0B-1:0] temp_data;        // Temporary data to read each data
        initial begin
            integer i;  
            file = $fopen("C:/Users/nguye/Desktop/KTMT/DSIP/KV260/Binary_Instruction_Parameters/binary_parameter/test_model_1/biases_dense0_hex.txt", "r");
            if (file == 0) begin
                $display("Dense0 biases file not found!");  
                $finish;
            end
            line_number = '0;
            while (!$feof(file)) begin
                r = $fgets(line, file);         // Read line from file
                if (r) begin
                    r = $sscanf(line, "%h", temp_data);     // Read hex data from line
                    if (r == 1) begin
                    // Assign data to memory array with offset
                        if (line_number + OFFSET_D0B < ARRAY_SIZE_D0B) begin
                            OM_mem[line_number + OFFSET_D0B] = temp_data;        // Assign from OFFSET
                        end else begin
                            $display("Dense0 biases file too large!, line %0d will be skipped.", line_number);
                        end
                        line_number = line_number + 1;
                    end else begin
                        $display("Line %0d is not a valid hex number: %s", line_number, line);
                    end
                end
            end
            $fclose(file);
        end
    endmodule

    // Read Instructions =============================
    logic [31:0] ctrl_inst_temp [0:5000];
    initial begin
        $readmemb("C:/Users/nguye/Desktop/KTMT/DSIP/KV260/Binary_Instruction_Parameters/binary_instruction/test_model_1/instructions_controller_core.txt",ctrl_inst_temp);
        $readmemb("C:/Users/nguye/Desktop/KTMT/DSIP/KV260/Binary_Instruction_Parameters/binary_instruction/test_model_1/instructions_DNN_core.txt",OM_mem_inst);

        rst = 1;
        #400
        rst = 0;
        // Nap lenh của controller vào mem
        foreach(ctrl_inst_temp[i]) begin #10
            mcmem_wen       = 1;
            mcmem_wr_addr   = i;
            mcmem_wr_data   = ctrl_inst_temp[i];
            if(i == 1024) break;
        end

        #10 start = 1;
        #10 start = 0;
    end
    
    
endmodule
