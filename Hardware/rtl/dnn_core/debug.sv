module DNN_Core_debug#(
    parameter DATA_W            = 16,                       
    parameter DECIMAL_BIT       = 8,    // Number of decimal bits
    parameter INSTR_W           = 212,   // Instruction Width
    parameter BUFFER_SIZE       = 512,  // Instruction buffer/mem size
    parameter SCRATCHPAD_W      = 512,   // Size of IB, KSP, OSP, FCSP, OB
    parameter BLOCKS_PER_ROW    = 64    // Số lượng block song song
)(
    //Global signals
    input  logic clk,
    input  logic rst,
 
    input  logic start,                                      // Start ASIP
    input  logic DC_write_en,                                // Enable write DNN core instruction memory
    input  logic [$clog2(BUFFER_SIZE)-1:0]      DC_addr_w,        // Address write DNN core instruction memory (Buffer 512 => 9 bit)
    input  logic [INSTR_W-1:0]                  DC_inst_w,                    // Instruction writing to DNN core instruction memory
    
    input  logic [BLOCKS_PER_ROW-1:0]           en_write_IB,            // Enable write IB (64 blocks)
    input  logic [BLOCKS_PER_ROW-1:0]           en_write_KSP,           // Enable write KSP (64 blocks)    
    input  logic                                en_write_BSP,           // Enable write BSP (64 blocks)
    input  logic [$clog2(SCRATCHPAD_W)-1:0]     IB_wr_addr,              // Address write IB (6 bit)
    
    input  logic [$clog2(SCRATCHPAD_W)-1:0]     KSP_wr_addr,             // Address write KSP (6 bit)
    input  logic [$clog2(SCRATCHPAD_W)-1:0]     BSP_wr_addr,             // Address write BSP (6 bit)
    
    input  logic [DATA_W-1:0]                   data_write,             //DATA write to IB, KSP, BSP

    //Controller enable read Output Buffer    
    output logic [DATA_W-1:0]                   OB_data_read,           //Data read from Output Buffer from Controller
    output logic [DATA_W-1:0]                   MEM_data_read,          // Data read from Memory from Controller
    output logic                                dnn_done,                   //Done signal from DNN core to controller
    
    input  logic                                en_C_read_OB,
    input  logic [$clog2(SCRATCHPAD_W)-1:0]     OB_MC_rd_addr,
    output logic [DATA_W-1:0]                   OB_MC_read
    //Observer only               
);
    // STAGE IF -> MEMLOAD -> CONV -> ACTIVATION -> POOLING -> MEMSTORE 

    // =========================================================================
    // Internal logic registers
    // =========================================================================    
    
    // STAGE IF
    logic                               run_en;   // Enable run AGU (Address Generator Unit)
    logic                               sit_en;   // Set Iteration for AGU (loop counter)
    logic                               sbp_en;   // Set Breakpoint for AGU
    logic                               sof_en;   // Set Offset for AGU
    logic [8:0]                         offset; // Offset for AGU
    //Update new base address
    logic                               new_base_addr;      // Alert AGU to change base address
    logic [$clog2(SCRATCHPAD_W)-1:0]    IB_rd_base_addr;    // Read Base address of IB
    logic [$clog2(SCRATCHPAD_W)-1:0]    KSP_rd_base_addr;   // Read Base address of KSP
    logic [$clog2(SCRATCHPAD_W)-1:0]    OSP_wr_base_addr;   // Write Base address of OSP
    logic [$clog2(SCRATCHPAD_W)-1:0]    OSP_rd_base_addr;   // Read Base address of OSP
    logic [$clog2(SCRATCHPAD_W)-1:0]    OB_wr_base_addr;    // Write Base address of OB
    logic [$clog2(SCRATCHPAD_W)-1:0]    OB_rd_base_addr;    // Read Base address of OB
    logic [$clog2(SCRATCHPAD_W)-1:0]    BSP_rd_base_addr;   // Read Base address of BSP
    logic [$clog2(SCRATCHPAD_W)-1:0]    FCSP_rd_base_addr;  // Read Base address of FCSP
    logic [$clog2(SCRATCHPAD_W)-1:0]    FCSP_wr_base_addr;  // Write Base address of FCSP
    // Declare AGU block
    logic select_next_PC;       // Response from AGU, after a loop or need to jump, select next PC
    logic [8:0] PC_start;       // Start address of loop command, assign to PC when select next enable
    logic [8:0] PC;             // Program Counter

    // logic [INSTR_W-1:0] instr_IF;       // Instruction stage IF 
    logic [$clog2(SCRATCHPAD_W)-1:0]    KSP_rd_addr; // Address read from KSP
    logic [$clog2(SCRATCHPAD_W)-1:0]    OSP_rd_addr;  // Address read from OSP
    logic [$clog2(SCRATCHPAD_W)-1:0]    BSP_rd_addr; // Address read from BSP
    logic [$clog2(SCRATCHPAD_W)-1:0]    FCSP_rd_addr; // Address read from FCSP

    logic [INSTR_W-1:0]                 instr_read;     // Instruction read from memory
    logic [$clog2(SCRATCHPAD_W)-1:0]    IB_rd_addr;              // Address read IB (6 bit)
    logic [$clog2(SCRATCHPAD_W)-1:0]    OB_rd_addr;              //Address read Output Buffer (6 bit)
    logic [$clog2(SCRATCHPAD_W)-1:0]    OB_wr_addr;              //Address write Output Buffer (6 bit)

    logic                                sel_lut;                // Select lookup table (LUT0 or LUT1)
    logic [DATA_W - 1 : 0]               LI_data_out;             // Read data of LI (Linear Interpolation Array)
    genvar i;                           // Create i for loop generator
    // =========================================================================
    // STAGE IF (Instruction Fetch)
    // =========================================================================
    // Memory to store Instruction of DNN Core
    mem #(
        .DATA_W     (INSTR_W),
        .DEPTH      (BUFFER_SIZE),
        .EN_OUT_FF  (0)
    )MemSC(
        .clk(clk),
        .wen(DC_write_en),
        .ren(1'b1),
        .addr_w(DC_addr_w),
        .addr_r(PC),
        .wdata(DC_inst_w),
        .rdata(instr_read)
    );
    // Instruction Read Slice:  
    // Global control   (64bit)
    // Done FLag        (1bit)
    // Slot1            (11bit): Control stage IF (Configuration)
    // Slot2            (91bit): Control stage IF (base_addr for Scratchpad)
    // Slot3            (11bit): Control stage MEMLOAD (assign value from memory to MLI, MLK, MLO)
    // Slot4            (6bit): Control stage CONV (choose operand for MAC & Bias)
    // Slot5            (9bit): Control stage ACTIVATION/Nonlinear (choose lookuptable & choose data to write to NOA) 
    // Slot6            (12bit): Control stage POOLING (Control maxpooling, choose operand & choose data to write to POA) 
    // Slot7            (6bit): Control stage MEMSTORE (assign value going to OB, OSP or FCSP)
    logic [10:0] slot1;     
    logic [90:0] slot2;
    assign slot1 = instr_read[146:136];
    assign slot2 = instr_read[135:45];
    assign dnn_done = instr_read[147];

    // Pre-Slicing Instruction
    logic [63:0] ps_global;      
    assign ps_global = instr_read[211:148];
    logic [10:0] ps_slot3;
    assign ps_slot3 = instr_read[44:34];
    logic [5:0] ps_slot4;
    assign ps_slot4 = instr_read[33:28];
    logic [8:0] ps_slot5;
    assign ps_slot5 = instr_read[27:19];
    logic [11:0] ps_slot6;
    assign ps_slot6 = instr_read[18:7];
    logic [6:0] ps_slot7;
    assign ps_slot7 = instr_read[6:0];

    // Decoder Instruction Stage IF (slot1 & slot2)
    DecoderIF #(
        .SCRATCHPAD_W(SCRATCHPAD_W)
    )decIF(
        // Input 
        .slot1,
        .slot2,
        // Output Slot1
        .run_en(run_en),
        .sit_en(sit_en),
        .sbp_en(sbp_en),
        .sof_en(sof_en),
        .offset(offset),
        // Output Slot2
        .new_base_addr(new_base_addr),              // Get base address from Instruction
        .IB_rd_base_addr(IB_rd_base_addr),          // New IB read base address
        .KSP_rd_base_addr(KSP_rd_base_addr),        // New KSP read base address
        .OSP_wr_base_addr(OSP_wr_base_addr),        // New OSP write base address
        .OSP_rd_base_addr(OSP_rd_base_addr),        // New OSP read base address
        .OB_wr_base_addr(OB_wr_base_addr),          // New OB write base address
        .OB_rd_base_addr(OB_rd_base_addr),          // New OB read base address
        .BSP_rd_base_addr(BSP_rd_base_addr),        // New BSP read base address
        .FCSP_wr_base_addr(FCSP_wr_base_addr),      // New FCSP write base address
        .FCSP_rd_base_addr(FCSP_rd_base_addr)       // New FCSP read base address
    );

    // Stage IF Instruction latch registers
    logic [63:0]    IF_global;
    logic [10:0]    IF_slot3;
    logic [5:0]     IF_slot4;
    logic [8:0]     IF_slot5;
    logic [11:0]    IF_slot6;
    logic [6:0]     IF_slot7;

    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            IF_global <= '0;
            IF_slot3  <= '0;
            IF_slot4  <= '0;
            IF_slot5  <= '0;
            IF_slot6  <= '0;
            IF_slot7  <= '0;
        end else begin
            IF_global <= ps_global;
            IF_slot3  <= ps_slot3;
            IF_slot4  <= ps_slot4;
            IF_slot5  <= ps_slot5;
            IF_slot6  <= ps_slot6;
            IF_slot7  <= ps_slot7;
        end
    end

    logic start_flag;  //Latch start
    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            start_flag <= '0;
        end else if (start) begin
            start_flag <= 1'b1;
        end else if (dnn_done) begin
            start_flag <= '0;
        end else begin
            start_flag <= start_flag;
        end
    end

    // Program Counter
    always_ff @(negedge clk or posedge rst) begin
        if(rst) begin
            PC <= '0;
        end else begin
            if ((start_flag) && (!dnn_done)) begin
                if(select_next_PC) begin
                    PC <= PC_start;
                end else begin
                    PC <= PC + 1'b1;
                end
            end
            else begin
                PC <= '0;
            end
        end
    end

    logic [$clog2(SCRATCHPAD_W)-1:0] OSP_wr_addr;
    logic [$clog2(SCRATCHPAD_W)-1:0] FCSP_wr_addr;
    logic n_active;

    AGU #(
        .SCRATCHPAD_W(SCRATCHPAD_W)
    ) du_AGU (
        .clk(clk),      
        .rst(rst),
        .run_en(run_en),                                // AGU start
        .sit_en(sit_en),                                // Set iteration (loop counter)
        .sbp_en(sbp_en),                                // Set breakpoint
        .sof_en(sof_en),                                // Set offset (flags to choose which address to change) 
        .offset(offset),                                // Offset (assign to breakpoing/flags/iterations)
        .PC(PC),                                        // Program counter 
        
        .new_base_addr(new_base_addr),
        .IB_rd_base_addr(IB_rd_base_addr),
        .KSP_rd_base_addr(KSP_rd_base_addr),
        .OSP_wr_base_addr(OSP_wr_base_addr),
        .OSP_rd_base_addr(OSP_rd_base_addr),
        .OB_wr_base_addr(OB_wr_base_addr),
        .OB_rd_base_addr(OB_rd_base_addr),
        .BSP_rd_base_addr(BSP_rd_base_addr),
        .FCSP_wr_base_addr(FCSP_wr_base_addr),
        .FCSP_rd_base_addr(FCSP_rd_base_addr),

        .IB_rd_base_addr_out(IB_rd_addr),
        .KSP_rd_base_addr_out(KSP_rd_addr),
        .OSP_wr_base_addr_out(OSP_wr_addr),
        .OSP_rd_base_addr_out(OSP_rd_addr),
        .OB_wr_base_addr_out(OB_wr_addr),
        .OB_rd_base_addr_out(OB_rd_addr),
        .BSP_rd_base_addr_out(BSP_rd_addr),
        .FCSP_wr_base_addr_out(FCSP_wr_addr),
        .FCSP_rd_base_addr_out(FCSP_rd_addr),
        
        .select_next_PC(select_next_PC),
        .PC_start(PC_start),
        .n_active(n_active)
    );

    //Declare IB (input buffer)
    logic [DATA_W-1:0] IB_read [0:BLOCKS_PER_ROW-1];
    generate 
        for(i=0; i<BLOCKS_PER_ROW; i++) begin: IB_array
            mem #(
                .DATA_W(DATA_W),
                .DEPTH(SCRATCHPAD_W),
                .EN_OUT_FF(1)
            ) IB (
                .clk(!clk),
                .wen(en_write_IB[i]),
                .ren(1'b1),
                .addr_w(IB_wr_addr), 
                .addr_r(IB_rd_addr),
                .wdata(data_write),
                .rdata(IB_read[i])
            );
        end
    endgenerate

    //Declare KSP (kernel scratchpad)
    logic [DATA_W-1:0] KSP_read [0:BLOCKS_PER_ROW-1];
    generate
        for(i=0; i<BLOCKS_PER_ROW; i++) begin: KSP_array
            mem #(
                .DATA_W(DATA_W),
                .DEPTH(SCRATCHPAD_W),
                .EN_OUT_FF(1)
            ) KSP (
                .clk(!clk),
                .wen(en_write_KSP[i]),
                .ren(1'b1),
                .addr_w(KSP_wr_addr), 
                .addr_r(KSP_rd_addr),
                .wdata(data_write),
                .rdata(KSP_read[i])
            );
        end
    endgenerate

    //Declare FCSP (fully connected scratchpad)
    logic [$clog2(SCRATCHPAD_W)-1:0] FCSP_MS_wr_addr;
    logic [DATA_W-1:0] POFC_rd_data;       // Read data from POFC (Partial-Output Fully-Connected)
    logic [DATA_W-1:0] FCSP_rd_data;       // Read data from FCSP (Fully-Connected Scratchpad)
    logic [DATA_W-1:0] POFC_wr_data;     // Data write to FCSP (Fully-Connected Scratchpad) 
    logic FCSP_store_en;               // Enable write to FCSP 

    mem #(
        .DATA_W(DATA_W),
        .DEPTH(SCRATCHPAD_W),
        .EN_OUT_FF(1)
    ) FCSP(
        .clk(!clk),
        .wen(FCSP_store_en),
        .ren(1'b1),
        .addr_w(FCSP_MS_wr_addr), 
        .addr_r(FCSP_rd_addr),
        .wdata(POFC_rd_data),
        .rdata(FCSP_rd_data)
    );

    //Declare POFC (Partial-Output Fully-Connected)
    regs #(
        .DATA_W(DATA_W)
    )POFC(
        .clk(!clk),
        .rst(rst),
        .wen(1'b1),
        .din(POFC_wr_data),
        .dout(POFC_rd_data)
    );

    //Declare BSP Memory (Bias Scratchpad)
    logic [DATA_W-1:0] BSP_read;    //Data read from BSP
    mem #(
        .DATA_W(DATA_W),
        .DEPTH(SCRATCHPAD_W),
        .EN_OUT_FF(1)
    ) BSP (
        .clk(!clk),
        .wen(en_write_BSP),
        .ren(1'b1),
        .addr_w(BSP_wr_addr),
        .addr_r(BSP_rd_addr),
        .wdata(data_write),
        .rdata(BSP_read)
    );
    
    logic [DATA_W-1:0] OSP_read [0:BLOCKS_PER_ROW-1];    //Data read from OSP
    // Declare PEOA (Pooling & Element-wise Operation Array)
    logic [DATA_W-1:0] PEOA_read[BLOCKS_PER_ROW-1:0];
    logic [$clog2(SCRATCHPAD_W)-1:0] OSP_MS_wr_addr;    //Address write to OSP at stage Mem Store
    logic [$clog2(SCRATCHPAD_W)-1:0] OSP_PL_wr_addr;    //Address read from OSP at stage Pooling
    logic           OSP_store_en;
    logic [63:0]    OSP_enable;
    generate
        for(i=0; i<BLOCKS_PER_ROW; i++) begin: OSP_array
            mem #(
                .DATA_W(DATA_W),
                .DEPTH(SCRATCHPAD_W),
                .EN_OUT_FF(1)
            ) OSP (
                .clk(!clk),
                .wen(OSP_store_en & OSP_enable[i]),
                .ren(1'b1),
                .addr_w(OSP_MS_wr_addr),
                .addr_r(OSP_rd_addr),
                .wdata(PEOA_read[i]),
                .rdata(OSP_read[i])
            );
        end
    endgenerate

    // =========================================================================
    // STAGE ML (Memory Load)
    // =========================================================================
    // Pipeline Latch registers
    logic [$clog2(SCRATCHPAD_W)-1:0] FCSP_ML_wr_addr;
    logic [$clog2(SCRATCHPAD_W)-1:0] OSP_ML_wr_addr;
    logic [$clog2(SCRATCHPAD_W)-1:0] OB_ML_wr_addr;
    logic [$clog2(SCRATCHPAD_W)-1:0] OB_ML_rd_addr;

    // Latch registers FCSP between IF & ML
    regs #(
        .DATA_W(($clog2(SCRATCHPAD_W)))     // 6 bit 
    )FCSP_IF_ML(
        .clk(clk),
        .rst(rst),
        .wen(1'b1),
        .din(FCSP_wr_addr),
        .dout(FCSP_ML_wr_addr)
    );
    
    // Latch registers OSP between IF & ML
    regs #(
        .DATA_W(($clog2(SCRATCHPAD_W)))
    )OSP_IF_ML(
        .clk(clk),   
        .rst(rst),
        .wen(1'b1),
        .din(OSP_wr_addr),
        .dout(OSP_ML_wr_addr)
    );

    // Latch registers OB write between IF & ML
    regs #(
        .DATA_W(($clog2(SCRATCHPAD_W)))
    )OB_wr_IF_ML(
        .clk(clk),   
        .rst(rst),
        .wen(1'b1),
        .din(OB_wr_addr),
        .dout(OB_ML_wr_addr)
    );

    // Latch registers OB read between IF & ML
    regs #(
        .DATA_W(($clog2(SCRATCHPAD_W)))
    )OB_rd_IF_ML(
        .clk(clk),   
        .rst(rst),
        .wen(1'b1),
        .din(OB_rd_addr),
        .dout(OB_ML_rd_addr)
    );


    // Stage ML Instruction latch registers 
    logic [63:0] ML_global;
    logic [10:0] ML_slot3;
    logic [5:0]  ML_slot4;
    logic [8:0]  ML_slot5;
    logic [11:0] ML_slot6;
    logic [6:0]  ML_slot7;
    // Latch logic
    always_ff @(posedge clk or posedge rst) begin  
        if(rst) begin
            ML_global <= '0;
            ML_slot3  <= '0;
            ML_slot4  <= '0;
            ML_slot5  <= '0;
            ML_slot6  <= '0;
            ML_slot7  <= '0;
        end else begin
            ML_global <= IF_global;
            ML_slot3  <= IF_slot3;
            ML_slot4  <= IF_slot4;
            ML_slot5  <= IF_slot5;
            ML_slot6  <= IF_slot6;
            ML_slot7  <= IF_slot7;
        end
    end

    localparam MLD0 = 3'b000;        // no load
    localparam MLD1 = 3'b001;        // load from IB
    localparam MLD2 = 3'b010;        // load from IB, KSP
    localparam MLD3 = 3'b011;        // load from IB, OSP
    localparam MLD4 = 3'b100;        // load from IB, KSP, OSP    
    localparam MLD5 = 3'b101;        // load from OSP, BSP
    localparam MLD6 = 3'b110;        // load from FCSP, BSP
    localparam MLD7 = 3'b111;        // load from FCSP, BSP, OSP

    logic en_load_IB;
    logic en_load_KSP;
    logic en_load_OSP;
    logic en_load_BSP;
    logic en_load_FCSP;
    logic [7:0] sel_MLOM;

    // Decoder stage ML
    DecoderML #(
        .MLD0(MLD0),
        .MLD1(MLD1),
        .MLD2(MLD2),
        .MLD3(MLD3),
        .MLD4(MLD4),
        .MLD5(MLD5),
        .MLD6(MLD6),
        .MLD7(MLD7)
    )decML(
        .slot3(ML_slot3),                  // Instruction
        .en_load_IB(en_load_IB),        // Enable load from Input Buffer
        .en_load_KSP(en_load_KSP),      // Enable load from Kernel Scratchpad
        .en_load_OSP(en_load_OSP),      // Enable load from Output Scratchpad
        .en_load_BSP(en_load_BSP),      // Enable load from Bias Scratchpad
        .en_load_FCSP(en_load_FCSP),    // Enable load from Fully Connected Scratchpad
        .sel_MLOM(sel_MLOM)             // Selec Memory Load OSP Muxed
    );

    // Declare MLI (Memory Load Input) register
    logic [DATA_W-1:0] MLI_read [0:BLOCKS_PER_ROW-1];
    generate 
        for(i=0; i<BLOCKS_PER_ROW; i++) begin: MLI_array
            regs #(
                .DATA_W(DATA_W)
            ) MLI(
                .clk(!clk),
                .rst(rst),  
                .wen(en_load_IB),
                .din(IB_read[i]),
                .dout(MLI_read[i])
            );
        end
    endgenerate

    // Declare MLK (Memory Load Kernel) register
    logic [DATA_W-1:0] MLK_read [0:BLOCKS_PER_ROW-1];
    generate 
        for(i=0; i<BLOCKS_PER_ROW; i++) begin: MLK_array
            regs #(
                .DATA_W(DATA_W)
            ) MLK(
                .clk(!clk),
                .rst(rst),  
                .wen(en_load_KSP),
                .din(KSP_read[i]),
                .dout(MLK_read[i])
            );
        end
    endgenerate

    // Declare MLB (Memory Load Bias) register
    logic [DATA_W-1:0] MLB_read;
    regs #(
        .DATA_W(DATA_W)
    ) MLB(
        .clk(!clk),
        .rst(rst),  
        .wen(en_load_BSP),
        .din(BSP_read),
        .dout(MLB_read)
    );

    // Declare MLFC (Memory Load Fully Connected) register
    logic [DATA_W-1:0] MLFC_read;
    regs #(
        .DATA_W(DATA_W)
    ) MLFC(
        .clk(!clk),
        .rst(rst),  
        .wen(en_load_FCSP),
        .din(FCSP_rd_data),
        .dout(MLFC_read)
    );

    // Declare MLO (Memory Load Output) register
    logic [DATA_W-1:0] MLO_read [0:BLOCKS_PER_ROW-1];
    generate
        for(i=0; i<BLOCKS_PER_ROW; i++) begin: MLO_array
            regs #(
                .DATA_W(DATA_W)
            ) MLO(
                .clk(!clk),
                .rst(rst),  
                .wen(en_load_OSP),
                .din(OSP_read[i]),
                .dout(MLO_read[i])
            );
        end
    endgenerate

    // Declare MLOM (Memory Load Output Muxed) register
    logic [DATA_W-1:0] MLOM_in;
    assign MLOM_in = OSP_read[sel_MLOM];
    logic [DATA_W-1:0] MLOM_read;
    regs #(
        .DATA_W(DATA_W)
    ) MLOM(
        .clk(!clk),
        .rst(rst),  
        .wen(en_load_OSP),
        .din(MLOM_in),
        .dout(MLOM_read)
    );

    // =========================================================================
    // STAGE CONV (Convolution)
    // =========================================================================
    logic [$clog2(SCRATCHPAD_W)-1:0] FCSP_CONV_wr_addr;
    logic [$clog2(SCRATCHPAD_W)-1:0] OSP_CONV_wr_addr;
    logic [$clog2(SCRATCHPAD_W)-1:0] OB_CONV_wr_addr;
    logic [$clog2(SCRATCHPAD_W)-1:0] OB_CONV_rd_addr;

    // Latch registers FCSP between ML & CONV
    regs #(
        .DATA_W($clog2(SCRATCHPAD_W))
    )FCSP_ML_CONV(
        .clk(clk),   
        .rst(rst),
        .wen(1'b1),
        .din(FCSP_ML_wr_addr),
        .dout(FCSP_CONV_wr_addr)
    );

    // Latch registers OSP between ML & CONV
    regs #(
        .DATA_W($clog2(SCRATCHPAD_W))
    )OSP_ML_CONV(
        .clk(clk),   
        .rst(rst),
        .wen(1'b1),
        .din(OSP_ML_wr_addr),
        .dout(OSP_CONV_wr_addr)
    );

    // Latch registers OB write between ML & CONV
    regs #(
        .DATA_W($clog2(SCRATCHPAD_W))
    )OB_wr_ML_CONV(
        .clk(clk),
        .rst(rst),
        .wen(1'b1),
        .din(OB_ML_wr_addr),
        .dout(OB_CONV_wr_addr)
    );

    // Latch registers OB read between ML & CONV
    regs #(
        .DATA_W($clog2(SCRATCHPAD_W))
    )OB_rd_ML_CONV(
        .clk(clk),
        .rst(rst),
        .wen(1'b1),
        .din(OB_ML_rd_addr),
        .dout(OB_CONV_rd_addr)  
    );
    
    // Stage CONV Instruction latch registers
    logic [63:0] CONV_global;
    logic [5:0]  CONV_slot4;
    logic [8:0]  CONV_slot5;
    logic [11:0] CONV_slot6;
    logic [6:0]  CONV_slot7; 
    // Latch logic
    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            CONV_global <= '0;
            CONV_slot4  <= '0;
            CONV_slot5  <= '0;
            CONV_slot6  <= '0;
            CONV_slot7  <= '0;
        end else begin
            CONV_global <= ML_global;
            CONV_slot4  <= ML_slot4;
            CONV_slot5  <= ML_slot5;
            CONV_slot6  <= ML_slot6;
            CONV_slot7  <= ML_slot7;
        end
    end

    logic [63:0] EOA_en;
    assign EOA_en = CONV_global;  // Select EOA from AGU
    
    logic [1:0] src_mult1;
    logic src_mult2;
    logic [1:0] src_acc;
    logic src_add_bias;

    // Decoder stage Convolution
    DecoderCONV decCONV (
        .slot4(CONV_slot4),

        .src_mult1(src_mult1),       // Select first operand for MAC (MLIout, MLIout_all, MLOout)
        .src_mult2(src_mult2),       // Select second operand for MAC (MLKout)
        .src_acc(src_acc),           // Select between MLOM (Memory Load OSP Muxed) and MLFC (Memory Load Fully Connected)
        .src_add_bias(src_add_bias)     // 0: MLOM_read 1: MLFC_read
    ); 

    logic [DATA_W-1:0] CONV_read [BLOCKS_PER_ROW-1:0];   // CONV read data
    logic [DATA_W-1:0] EOA_read [BLOCKS_PER_ROW-1:0];    // EOA (Element-wise Operation Array) read data
    logic [DATA_W-1:0] dbg_MLI_read  [BLOCKS_PER_ROW];
    logic [DATA_W-1:0] dbg_MLK_read  [BLOCKS_PER_ROW];
    logic [DATA_W-1:0] dbg_MLO_read  [BLOCKS_PER_ROW];
    logic [DATA_W-1:0] dbg_EOA_read  [BLOCKS_PER_ROW];
    logic [DATA_W-1:0] dbg_CONV_read [BLOCKS_PER_ROW];
    generate 
        for (i = 0; i < BLOCKS_PER_ROW; i = i + 1) begin: conv_array
            if(i != 0) begin
                assign dbg_MLI_read[i]  = MLI_read[i];
                assign dbg_MLK_read[i]  = MLK_read[i];
                assign dbg_MLO_read[i]  = MLO_read[i];
                assign dbg_EOA_read[i]  = EOA_read[i];
                assign dbg_CONV_read[i] = CONV_read[i];

                mac #(
                    .DATA_W(DATA_W),
                    .DECIMAL_BIT(DECIMAL_BIT)
                ) convo (
                    .mult_sel_1(src_mult1),     // 0 or MLIout or MLOout 
                    .mult_sel_2(src_mult2),     // 1 or MLIout
                    .acc_sel(src_acc),          
                    // 2'b00: acc_temp = mult_result[15:0];                // JUST RESULT FROM MULTIPICATION
                    // 2'b01: acc_temp = MLOout + mult_result[15:0];       // ADD MLIout
                    // 2'b10: acc_temp = EOAout + mult_result[15:0];       // ADD EOAout
                    // 2'b11: acc_temp = SEOAout + mult_result[15:0];      // ADD SEOAout

                    .MLIout(MLI_read[i]),
                    .MLIout_all(MLI_read[0]),
                    .MLKout(MLK_read[i]),
                    .MLOout(MLO_read[i]),
                    .EOAout(EOA_read[i]),
                    .SEOAout(EOA_read[i-1]),

                    .acc_result(CONV_read[i])
                );
            end else begin
                mac #(
                    .DATA_W(DATA_W),
                    .DECIMAL_BIT(DECIMAL_BIT)
                ) convo (
                    .mult_sel_1(src_mult1),     // 0 or MLIout or MLOout 
                    .mult_sel_2(src_mult2),     // 1 or MLIout
                    .acc_sel(src_acc),

                    .MLIout(MLI_read[i]),
                    .MLIout_all(MLI_read[0]),
                    .MLKout(MLK_read[i]),
                    .MLOout(MLO_read[i]),
                    .EOAout(EOA_read[i]),
                    .SEOAout('0),

                    .acc_result(CONV_read[i])
                );
            end
        end   
        for (i=0; i<BLOCKS_PER_ROW; i++) begin: EOA_array
            regs #(
                .DATA_W(DATA_W)
            ) EOA(
                .clk(!clk),
                .rst(rst),
                .wen(EOA_en[i]),
                .din(CONV_read[i]),
                .dout(EOA_read[i])
            );
        end
    endgenerate

    logic [DATA_W-1:0] LUT_data_in;
    logic [DATA_W-1:0] LUT_add_bias;
    assign LUT_add_bias = (src_add_bias == '0) ? MLOM_read : MLFC_read;
    assign LUT_data_in = LUT_add_bias + MLB_read;

    logic [DATA_W*2-1:0] LUT0_coordinated_0;    // [31:16]x1 [15:0]y1
    logic [DATA_W*2-1:0] LUT0_coordinated_1;    // [31:16]x2 [15:0]y2
    logic [DATA_W-1:0]   LUT0_dout;             // Latch din

    logic [DATA_W*2-1:0] LUT1_coordinated_0;    // [31:16]x1 [15:0]y1
    logic [DATA_W*2-1:0] LUT1_coordinated_1;    // [31:16]x2 [15:0]y2
    logic [DATA_W-1:0]   LUT1_dout;             // Latch din

    // Declare Lookup Table 0
    LUTable0 #(
        .DATA_W(DATA_W)
    ) lkuptable0 (
        .clk(!clk),
        .rst(rst),
        .din(LUT_data_in),

        .coordinated_0(LUT0_coordinated_0),
        .coordinated_1(LUT0_coordinated_1),
        .dout(LUT0_dout)  
    );
    
    LUTable1 #(
        .DATA_W(DATA_W)
    ) lkuptable1 (
        .clk(!clk),
        .rst(rst),
        .din(LUT_data_in),

        .coordinated_0(LUT1_coordinated_0),
        .coordinated_1(LUT1_coordinated_1),
        .dout(LUT1_dout)    
    );
    
    // =========================================================================
    // STAGE NL (NON-LINEAR)
    // =========================================================================
    logic [$clog2(SCRATCHPAD_W)-1:0] FCSP_NL_wr_addr;
    logic [$clog2(SCRATCHPAD_W)-1:0] OSP_NL_wr_addr;
    logic [$clog2(SCRATCHPAD_W)-1:0] OB_NL_wr_addr;
    logic [$clog2(SCRATCHPAD_W)-1:0] OB_NL_rd_addr;

    // Latch registers FCSP between CONV & NL
    regs #(
        .DATA_W($clog2(SCRATCHPAD_W))
    ) FCSP_CONV_NL (
        .clk(clk),  
        .rst(rst),
        .wen(1'b1),
        .din(FCSP_CONV_wr_addr),
        .dout(FCSP_NL_wr_addr)
    );

    // Latch registers OSP between CONV & NL
    regs #(
        .DATA_W($clog2(SCRATCHPAD_W))
    ) OSP_CONV_NL (
        .clk(clk),  
        .rst(rst),
        .wen(1'b1),
        .din(OSP_CONV_wr_addr),
        .dout(OSP_NL_wr_addr)    
    );
    
    // Latch registers OB write between CONV & NL
    regs #(
        .DATA_W($clog2(SCRATCHPAD_W))
    ) OB_CONV_NL (
        .clk(clk),  
        .rst(rst),
        .wen(1'b1),
        .din(OB_CONV_wr_addr),
        .dout(OB_NL_wr_addr)        
    );

    // Latch registers OB read between CONV & NL
    regs #(
        .DATA_W($clog2(SCRATCHPAD_W))
    ) OB_rd_CONV_NL (
        .clk(clk),  
        .rst(rst),
        .wen(1'b1),
        .din(OB_CONV_rd_addr),
        .dout(OB_NL_rd_addr)
    );

    // Stage NL Instruction latch registers
    logic [63:0] NL_global;
    logic [8:0]  NL_slot5;
    logic [11:0] NL_slot6;
    logic [6:0]  NL_slot7;
    // Latch logic 
    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            NL_global <= '0;
            NL_slot5  <= '0;
            NL_slot6  <= '0;
            NL_slot7  <= '0;
        end else begin
            NL_global <= CONV_global;
            NL_slot5  <= CONV_slot5;
            NL_slot6  <= CONV_slot6;
            NL_slot7  <= CONV_slot7;
        end
    end
    // sel_lut is output wire
    logic [7:0] sel_NOA;    // Select NOA (Nonlinear Operation Array)
    // Decoder stage NL
    DecoderNL decNL(
        .slot5(NL_slot5),       

        .sel_lut(sel_lut),      // 0: LUT0 1: LUT1
        .sel_NOA(sel_NOA)       // Select 0-63 EOA_read to NOA
    );

    // Declare NEOA (Nonlinear/Element-wise Operation Array)
    logic [DATA_W-1:0] NEOA_read [BLOCKS_PER_ROW-1:0];
    generate 
        for(i=0; i<BLOCKS_PER_ROW; i++) begin: NEOA_array
            regs #(
                .DATA_W(DATA_W)
            ) NEOA(
                .clk(!clk),
                .rst(rst),  
                .wen(1'b1),
                .din(EOA_read[i]),
                .dout(NEOA_read[i])
            );
        end
    endgenerate
    // Declare NOA (Nonlinear Operation Array)
    logic [DATA_W-1:0] NOA_data_wr;
    logic [DATA_W-1:0] NOA_data_rd;
    assign NOA_data_wr = EOA_read[sel_NOA];
    regs #(
        .DATA_W(DATA_W)
    ) NOA (
        .clk(!clk),
        .rst(rst),  
        .wen(1'b1),
        .din(NOA_data_wr),
        .dout(NOA_data_rd)  
    );

    // Select lut
    logic [DATA_W*2-1:0] LUT_coordinated_0;
    logic [DATA_W*2-1:0] LUT_coordinated_1;
    logic [DATA_W-1:0]   LUT_dout;

    assign LUT_coordinated_0 = (sel_lut == 0) ? LUT0_coordinated_0 : LUT1_coordinated_0;
    assign LUT_coordinated_1 = (sel_lut == 0) ? LUT0_coordinated_1 : LUT1_coordinated_1;
    assign LUT_dout          = (sel_lut == 0) ? LUT0_dout : LUT1_dout;

    Linear_Inter #(
        .DATA_W(DATA_W),
        .DECIMAL_BIT(DECIMAL_BIT)
    ) LI (
        .x(LUT_dout),
        .x1(LUT_coordinated_0[31:16]),
        .y1(LUT_coordinated_0[15:0]),
        .x2(LUT_coordinated_1[31:16]),
        .y2(LUT_coordinated_1[15:0]),

        .y(LI_data_out)
    );

    //Declare NOL (Nonlinear Operation Latch)
    logic [DATA_W-1:0] NOL_read;
    regs #(
        .DATA_W(DATA_W)
    ) NOL(
        .clk(!clk),
        .rst(rst),
        .wen(1'b1),
        .din(LI_data_out),
        .dout(NOL_read)
    );

    logic signed [DATA_W+5:0] sum_temp;
    //NFC(NonLinear/Fully Connected)
    logic [DATA_W- 1 : 0] NFC_data_wr; 
    logic [DATA_W- 1 : 0] NFC_data_rd;
    
    logic signed [DATA_W  : 0] sum_stage1 [0:31];   // 17 bits for overflow
    logic signed [DATA_W +1 : 0] sum_stage2 [0:15];
    logic signed [DATA_W +2 : 0] sum_stage3 [0:7];
    logic signed [DATA_W +3 : 0] sum_stage4 [0:3];
    logic signed [DATA_W +4 : 0] sum_stage5 [0:1];

    integer k;
    //Adder tree
    always_comb begin
        // Stage 1: 64 -> 32
        for (k = 0; k < 32; k = k + 1) begin
            sum_stage1[k] = EOA_read[2*k] + EOA_read[2*k + 1];
        end
        // Stage 2: 32 -> 16
        for (k = 0; k < 16; k = k + 1) begin
            sum_stage2[k] = sum_stage1[2*k] + sum_stage1[2*k + 1];
        end
        // Stage 3: 16 -> 8
        for (k = 0; k < 8; k = k + 1) begin
            sum_stage3[k] = sum_stage2[2*k] + sum_stage2[2*k + 1];
        end
        // Stage 4: 8 -> 4
        for (k = 0; k < 4; k = k + 1) begin
            sum_stage4[k] = sum_stage3[2*k] + sum_stage3[2*k + 1];
        end
        // Stage 5: 4 -> 2
        for (k = 0; k < 2; k = k + 1) begin
            sum_stage5[k] = sum_stage4[2*k] + sum_stage4[2*k + 1];
        end
        // Last Stage: 2 -> 1
        sum_temp = sum_stage5[0] + sum_stage5[1];
    end 
    /*
    //EXAMPLE ADDER TREE
    EOA_read[63:0] = {64->1}
    Stage1: begin 
        ss1[0] = 1 + 2 = 3
        ss1[1] = 3 + 4 = 7
        ... ss1[31] = 63 + 64 = 127
    end
    Stage2: begin
        ss2[0] = 3 + 7 = 10
        ss2[1] = 11 + 15 = 26
        ... ss2[15] = 123 + 127 = 250
    end
    Stage3: begin
        ss3[0] = 10 + 26 = 36
        ss3[1] = 42 + 58 = 100
        ... ss3[7] = 234 + 250 = 484
    end
    Stage4: begin
        ss4[0] = 36 + 100 = 136
        ss4[1] = 164 + 228 = 392
        ss4[2] = 292 + 356 = 648
        ss4[3] = 420 + 484 = 904
    end
    Stage5: begin
        ss5[0] = 136 + 392 = 528
        ss5[1] = 648 + 904 = 1552
    end
    sum_temp = 528 + 1552 = 2080 
    */

    //NFC
    assign NFC_data_wr = sum_temp;
    regs #(
        .DATA_W(DATA_W)
    ) NFC (
        .clk(!clk),
        .rst(rst),
        .wen(1'b1),
        .din(NFC_data_wr),
        .dout(NFC_data_rd)
    );

    // =========================================================================
    // STAGE PL (POOLING)
    // =========================================================================
    logic [$clog2(SCRATCHPAD_W)-1:0] FCSP_PL_wr_addr;
    logic [$clog2(SCRATCHPAD_W)-1:0] OB_PL_wr_addr;
    logic [$clog2(SCRATCHPAD_W)-1:0] OB_PL_rd_addr;

    // Latch registers FCSP between NL & PL
    regs #(
        .DATA_W($clog2(SCRATCHPAD_W))
    ) FCSP_NL_PL (
        .clk(clk),  
        .rst(rst),
        .wen(1'b1),
        .din(FCSP_NL_wr_addr),
        .dout(FCSP_PL_wr_addr)
    );

    // Latch registers OSP between NL & PL
    regs #(
        .DATA_W($clog2(SCRATCHPAD_W))
    ) OSP_NL_PL (
        .clk(clk),  
        .rst(rst),
        .wen(1'b1),
        .din(OSP_NL_wr_addr),
        .dout(OSP_PL_wr_addr)
    );

    // Latch registers OB between NL & PL
    regs #(
        .DATA_W($clog2(SCRATCHPAD_W))
    ) OB_wr_NL_PL (
        .clk(clk),  
        .rst(rst),
        .wen(1'b1),
        .din(OB_NL_wr_addr),
        .dout(OB_PL_wr_addr)
    );

    // Latch registers OB between NL & PL
    regs #(
        .DATA_W($clog2(SCRATCHPAD_W))
    ) OB_rd_NL_PL (
        .clk(clk),  
        .rst(rst),
        .wen(1'b1),
        .din(OB_NL_rd_addr),
        .dout(OB_PL_rd_addr)
    );

    // Stage PL Instruction latch registers
    logic [63:0] PL_global;
    logic [11:0] PL_slot6;
    logic [6:0] PL_slot7;
    // Latch logic
    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            PL_global   <= '0;
            PL_slot6    <= '0;
            PL_slot7    <= '0;
        end else begin
            PL_global   <= NL_global;
            PL_slot6    <= NL_slot6;
            PL_slot7    <= NL_slot7;
        end
    end

    logic [2:0] src_max;
    logic [7:0] sel_POA;
    logic sel_adder;
    // Decoder stage Pooling
    DecoderPL decPL (
        .slot6(PL_slot6),

        .src_max(src_max),
        .sel_POA(sel_POA),
        .sel_adder(sel_adder)
    );

    generate
        for (i=0; i<BLOCKS_PER_ROW; i++) begin: PEOA_array
            if (i != 0) begin
                regs #(
                    .DATA_W(DATA_W)
                ) PEOA(
                    .clk(!clk),
                    .rst(rst),  
                    .wen(1'b1),
                    .din(NEOA_read[i-1]),
                    .dout(PEOA_read[i])  
                );
            end else begin
                regs #(
                    .DATA_W(DATA_W)
                ) PEOA(
                    .clk(!clk),
                    .rst(rst),  
                    .wen(1'b1),
                    .din('0),
                    .dout(PEOA_read[i])
                );
            end
        end    
    endgenerate

    // Declare POA (Pooling Operation Array)
    logic [DATA_W-1:0] POA_data_wr;
    logic [DATA_W-1:0] POA_data_rd;
    assign POA_data_wr = NEOA_read[sel_POA];

    regs #(
        .DATA_W(DATA_W)
    ) POA(
        .clk(!clk),
        .rst(rst),  
        .wen(1'b1),
        .din(POA_data_wr),
        .dout(POA_data_rd)
    );

    // Declare POL (Pooling Operation Logic)
    logic [DATA_W-1:0] POL_read;
    regs #(
        .DATA_W(DATA_W)
    ) POL(
        .clk(!clk),
        .rst(rst),  
        .wen(1'b1),
        .din(NOL_read),  
        .dout(POL_read)
    );
    
    assign POFC_wr_data = (sel_adder == 1'b0) ? (NFC_data_rd) : (NFC_data_rd + POFC_rd_data);

    // Declare Max Pooling Block
    logic [DATA_W-1:0] max_pool_result;
    logic [DATA_W-1:0] POM_read;        // Output of Max Pooling Block (Processing Output Management)

    logic [DATA_W-1:0] OB_data_rd;
    logic [DATA_W-1:0] MEM_data_rd;

    logic [DATA_W-1:0] max_oper_1;
    logic [DATA_W-1:0] max_oper_2;

    // Select Operand for Max Pooling
    always_comb begin
        max_oper_1 = 'z;
        case (src_max)
            3'h0: max_oper_1 = '0;
            3'h1: max_oper_1 = NOA_data_rd;
            3'h2: max_oper_1 = OB_data_rd;
            3'h3: max_oper_1 = MEM_data_rd;
            3'h4: max_oper_1 = POL_read;
            3'h5: max_oper_1 = POM_read;
            default: max_oper_1 = 'z;
        endcase
    end    
    assign max_oper_2 = NOL_read;
    assign max_pool_result = (max_oper_1 > max_oper_2) ? max_oper_1 : max_oper_2;

    // Declare POM (Processing Output Management)
    generate
        regs #(
            .DATA_W(DATA_W)
        ) POM(
            .clk(!clk),
            .rst(rst),  
            .wen(1'b1),
            .din(max_pool_result),
            .dout(POM_read)  
        );
    endgenerate

    // =========================================================================
    // STAGE MS (MEM STORE)
    // =========================================================================
    logic [$clog2(SCRATCHPAD_W)-1:0] OB_MS_wr_addr;
    logic [$clog2(SCRATCHPAD_W)-1:0] OB_MS_rd_addr;
    // Stage MS Instruction latch registers
    logic [63:0] MS_global;
    logic [6:0] MS_slot7;   

    assign OSP_enable = MS_global << 1;
    // Latch registers FCSP between PL & MS
    regs #(
        .DATA_W($clog2(SCRATCHPAD_W))
    ) FCSP_PL_MS (
        .clk(clk),
        .rst(rst),
        .wen(1'b1),
        .din(FCSP_PL_wr_addr),
        .dout(FCSP_MS_wr_addr)
    );

    // Latch registers OSP between PL & MS
    regs #(
        .DATA_W($clog2(SCRATCHPAD_W))
    ) OSP_PL_MS (
        .clk(clk),
        .rst(rst),
        .wen(1'b1),
        .din(OSP_PL_wr_addr),
        .dout(OSP_MS_wr_addr)
    );

    // Latch registers OB write between PL & MS
    regs #(
        .DATA_W($clog2(SCRATCHPAD_W))
    ) OB_wr_PL_MS (
        .clk(clk),
        .rst(rst),
        .wen(1'b1),
        .din(OB_PL_wr_addr),
        .dout(OB_MS_wr_addr)
    );

    // Latch registers OB read between PL & MS
    regs #(
        .DATA_W($clog2(SCRATCHPAD_W))
    ) OB_rd_PL_MS (
        .clk(clk),
        .rst(rst),
        .wen(1'b1),
        .din(OB_PL_rd_addr),      
        .dout(OB_MS_rd_addr)
    );

    // Latch logic
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            MS_global   <= '0;
            MS_slot7    <= '0;
        end else begin
            MS_global   <= PL_global;
            MS_slot7    <= PL_slot7;
        end
    end 

    logic OB_store_en;
    logic [1:0] src_store_OB;
    logic [1:0] src_store_MEM;

    logic [DATA_W-1:0] OB_data_wr;
    logic [DATA_W-1:0] MEM_data_wr;
    //Decoder stage MS
    localparam MST0 = 3'h0;     // No store
    localparam MST1 = 3'h1;     // Store OB
    localparam MST2 = 3'h2;     // Store OSP
    localparam MST3 = 3'h3;     // Store FCSP
    localparam MST4 = 3'h4;     // Store OB, OSP
    localparam MST5 = 3'h5;     // Store OB, FCSP
    localparam MST6 = 3'h6;     // Store OSP, FCSP
    localparam MST7 = 3'h7;     // Store OB, OSP, FCSP

    DecoderMS #(
        .MST0(MST0),
        .MST1(MST1),
        .MST2(MST2),
        .MST3(MST3),
        .MST4(MST4),
        .MST5(MST5),
        .MST6(MST6),
        .MST7(MST7)
    ) decMS (
        .slot7(MS_slot7),

        .en_store_OB(OB_store_en),
        .en_store_OSP(OSP_store_en),
        .en_store_FCSP(FCSP_store_en),

        .src_store_OB(src_store_OB),
        .src_store_MEM(src_store_MEM)
    );
    
    // Select source write to OB
    always_comb begin
        case(src_store_OB)
            2'h0: begin
                OB_data_wr = POFC_rd_data;
            end
            2'h1: begin
                OB_data_wr = POA_data_rd;
            end
            2'h2: begin
                OB_data_wr = POM_read;
            end
            default: begin
                OB_data_wr = POL_read;
            end
        endcase
    end

    //Select source write to MEM
    always_comb begin
        case(src_store_MEM)
            2'h0: begin
                MEM_data_wr = POA_data_rd;
            end
            2'h1: begin
                MEM_data_wr = POM_read;
            end
            2'h2: begin
                MEM_data_wr = POL_read;
            end
            default: begin
                MEM_data_wr = 'z;
            end
        endcase
    end

    // Declare OB memory
    mem #(
        .DATA_W(DATA_W),
        .DEPTH(SCRATCHPAD_W),
        .EN_OUT_FF(0)
    ) OB (
        .clk(!clk),
        .wen(OB_store_en),
        .ren(1'b1),

        .addr_w(OB_MS_wr_addr),  
        .addr_r(OB_NL_rd_addr),
        .wdata(OB_data_wr),
        .rdata(OB_data_rd)
    );
    assign OB_data_read = OB_data_rd;   //Output

    //Declare OB_MC memory (Output memory connected to controller)
    mem #(
        .DATA_W(DATA_W),
        .DEPTH(SCRATCHPAD_W),
        .EN_OUT_FF(1)
    ) OB_MC (
        .clk(!clk),
        .wen(OB_store_en),
        .ren(en_C_read_OB),  
        .addr_w(OB_MS_wr_addr),
        .addr_r(OB_MC_rd_addr),
        .wdata(OB_data_wr),
        .rdata(OB_MC_read)
    );

    //Declare MEM register
    regs #(
        .DATA_W(DATA_W)
    ) MEM (
        .clk(!clk),
        .rst(rst),
        .wen(1'b1),
        .din(MEM_data_wr),
        .dout(MEM_data_rd)  
    );
    assign MEM_data_read = MEM_data_rd;  //Output
endmodule
