`define SINGLE 1
`define ONE_ONE 2
`define TWO_TWO 3

module Controller #(
    parameter INSTR_W       = 32,
    parameter DATA_W        = 32,
    parameter MCMEM_W       = 32,
    parameter ADDR_W        = 32,
    parameter BASE_DATA_OM  = 32'h00010000,
    // PARAMETER OF CONTROLLER MODE
    parameter MODEL         = `SINGLE,
    parameter IS_FIRST_ROW  = 1,
    parameter IS_FIRST_COL  = 1 
)(
    input  logic                        clk,
    input  logic                        rst,
    input  logic                        start,                                       // Start ASIP
    input  logic                        mcmem_wen,
    input  logic [$clog2(MCMEM_W)-1:0]  mcmem_wr_addr,
    input  logic [INSTR_W-1:0]          mcmem_wr_data,

    // Controller Mode
    input  logic                        vsync_in,
    input  logic                        hsync_in,
                        
    input  logic                        dnn_done,
    output logic                        vsync_out,
    output logic                        hsync_out,
    output logic                        start_DNN,                    // DNN_core start flag
    output logic                        end_flag,                          

    //PORT0 =============
    input  logic [67:0]                 command_P0_in,
    input  logic [15:0]                 data_P0_in,
    output logic [67:0]                 command_P0_out,
    output logic [15:0]                 data_P0_out,

    //PORT1 =============
    input  logic [67:0]                 command_P1_in,
    input  logic [15:0]                 data_P1_in,
    input  logic [211:0]                inst_P1_in,
    output logic [67:0]                 command_P1_out,
    output logic [15:0]                 data_P1_out,
    output logic [211:0]                inst_P1_out,

    //PORT OM =============
    output logic [31:0]                 OM_addr,
    output logic                        OM_wen,
    output logic                        OM_ren,

    input  logic [15:0]                 OM_rd_data,
    output logic [15:0]                 OM_wr_data,

    output logic                        OM_inst_ren,
    input  logic [211:0]                OM_inst_rd,

    //PORT DNN core =============
    output logic [8:0]                  DNN_addr,
    output logic                        mem_inst_wen,
    output logic [63:0]                 IB_wen,
    output logic [63:0]                 KSP_wen,
    output logic                        BSP_wen,
    output logic                        OB_ren,
    output logic [15:0]                 DNN_wr_data,
    input  logic [15:0]                 DNN_rd_data,
    output logic [211:0]                DNN_inst_wr,

    input  logic                        done_transfer_prev,
    output logic                        done_transfer,

    input  logic                        done_vtransfer_prev,
    output logic                        done_vtransfer
);
    logic           start_flag;

    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            start_flag <= '0;
        end else if (end_flag) begin
            start_flag <= 1'b0;
        end else if (start) begin
            start_flag <= 1'b1;
        end 
    end

    logic                       PC_sel;
    logic [15:0]                imm16;              // immediate 16 bit
    logic [DATA_W - 1:0]    extend_imm16;       // Extend immediate to 32 bit
    logic [DATA_W - 1:0]    extend_imm16_shift; // Value of ex_imm16 << 16
    logic [$clog2(MCMEM_W)-1:0] PC;
    logic [$clog2(MCMEM_W)-1:0] PC_next;
    logic instruction_valid;
    logic instruction_read_en;
    logic PC_en;            // Program Counter enable
    logic issue_valid;
    logic memory_busy;
    logic memory_inflight;
    logic fetch_memory_wait;
    logic end_drain;
    logic branch_wait;
    logic data_wait;
    logic data_use_ra, data_use_rb, data_use_rd, data_use_rtemp;
    // The synchronous RAM output is the instruction register. Read the NEXT
    // address on the edge which consumes the current instruction, so PC and
    // instruction remain aligned without adding an instruction-issue bubble.
    // A taken branch reads its target directly; a stall holds the RAM output.
    always_comb begin
        PC_next = PC;
        if (end_flag)
            PC_next = '0;
        else if (issue_valid)
            PC_next = PC_sel ? imm16 : PC + 1'b1;
    end
    // Bootstrap word zero on the start edge, before start_flag permits issue.
    // Repeated start pulses during execution must not refetch/reissue it.
    assign instruction_read_en = !rst && !end_flag &&
                                 ((!start_flag && start) || issue_valid);
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            PC <= '0;
            instruction_valid <= 1'b0;
        end else if (end_flag) begin
            PC <= '0;
            instruction_valid <= 1'b0;
        end else if (instruction_read_en) begin
            PC <= PC_next;
            instruction_valid <= 1'b1;
        end
    end

    logic [DATA_W-1:0] instruction;

    mem #(
        .DATA_W(DATA_W),
        .DEPTH(MCMEM_W),
        .EN_OUT_FF(1),
        .RAM_STYLE("block")
    ) MCMem(
        .clk(clk),
        .wen(mcmem_wen),
        .ren(instruction_read_en),
        .addr_w(mcmem_wr_addr),
        .addr_r(PC_next),
        .wdata(mcmem_wr_data),
        .rdata(instruction)
    );

    // {Opcode[31:26], RD[25:21], RA[20:16], RB[15:11], Rtemp[10:6], Unused [5:0]}
    wire [4:0] rd;
    wire [4:0] ra;
    wire [4:0] rb;
    wire [4:0] rtemp;

    logic [2:0] alu_op;
    logic [1:0] alu_oper1_sel;
    logic [2:0] alu_oper2_sel;
    logic br_signal;        // Branch jump signal
    logic cbr_signal;       // Conditional branch jump signal
    logic rf_wen;           // Register File write enable
    logic [3:0] type_access;
    Decoder_MC #(
        .INST_W(INSTR_W)
    ) mcdecoder(
        .inst(instruction),

        .rd(rd),
        .ra(ra),
        .rb(rb),
        .rtemp(rtemp),

        .imm16(imm16),
        .alu_op(alu_op),
        .alu_oper1_sel(alu_oper1_sel),
        .alu_oper2_sel(alu_oper2_sel),
        .br_signal(br_signal),
        .cbr_signal(cbr_signal),
        .rf_wen(rf_wen), 
        .type_access(type_access)  
    );

    logic [DATA_W-1:0] ra_rd_data;
    logic [DATA_W-1:0] rb_rd_data;
    logic [DATA_W-1:0] rd_rd_data;
    logic [4:0] rd_reg1;
    logic [4:0] rd_reg2;
    logic rf_wen_reg1;
    logic rf_wen_reg2;
    logic [4:0] rd_mid;
    logic rf_wen_mid;
    logic [DATA_W-1:0] alu_result;
    logic [DATA_W-1:0] alu_result_reg;
    logic [DATA_W-1:0] rtemp_rd_data;
    logic [DATA_W-1:0] ra_forwarded, rb_forwarded;
    logic [DATA_W-1:0] rd_forwarded, rtemp_forwarded;
    logic [DATA_W-1:0] branch_ra_data;

    reg_file #(
        .SIZE(32),
        .DATA_W(DATA_W)
    )rf(
        .clk(clk),
        .rst(rst),
        .ra(ra),
        .rb(rb),
        .rd_rd(rd),
        .rd_wr(rd_reg2),
        .rtemp(rtemp),
        .wen(rf_wen_reg2),
        .w_data(alu_result_reg),
        
        .ra_rd_data(ra_rd_data),
        .rb_rd_data(rb_rd_data),
        .rd_rd_data(rd_rd_data),
        .rtemp_rd_data(rtemp_rd_data)
    );

    // Stall true dependencies against both arithmetic and result-mux stages.
    // Ignore unused fields:
    // immediate bits overlap RB/RTEMP, and an ALU destination is not a source.
    // Memory transfers read all four registers to form their address packet.
    assign data_use_ra = (rf_wen && alu_oper1_sel == 0) || type_access != 0;
    assign data_use_rb = (rf_wen && alu_oper2_sel == 0) || type_access != 0;
    assign data_use_rd = type_access != 0;
    assign data_use_rtemp = type_access != 0;
    assign data_wait = (rf_wen_reg1 && rd_reg1 != 0 &&
                       ((data_use_ra && rd_reg1 == ra) ||
                        (data_use_rb && rd_reg1 == rb) ||
                        (data_use_rd && rd_reg1 == rd) ||
                        (data_use_rtemp && rd_reg1 == rtemp))) ||
                      (rf_wen_mid && rd_mid != 0 &&
                       ((data_use_ra && rd_mid == ra) ||
                        (data_use_rb && rd_mid == rb) ||
                        (data_use_rd && rd_mid == rd) ||
                        (data_use_rtemp && rd_mid == rtemp)));

    // During the bubbles EX1/EX2 drain into ALU_REG; decode forwards registered
    // WB data. No live ALU result feeds back into the operand/address registers.
    assign ra_forwarded = (rf_wen_reg2 && rd_reg2 != 0 && rd_reg2 == ra) ? alu_result_reg : ra_rd_data;
    assign rb_forwarded = (rf_wen_reg2 && rd_reg2 != 0 && rd_reg2 == rb) ? alu_result_reg : rb_rd_data;
    assign rd_forwarded = (rf_wen_reg2 && rd_reg2 != 0 && rd_reg2 == rd) ? alu_result_reg : rd_rd_data;
    assign rtemp_forwarded = (rf_wen_reg2 && rd_reg2 != 0 && rd_reg2 == rtemp) ? alu_result_reg : rtemp_rd_data;

    // A dependent CBR waits for its EX1/EX2 producer to reach ALU_REG.
    // Only issue/PC stall; the execution stages and WB continue draining.
    // Do not use live alu_result here: that would reconnect ALU -> branch -> PC.
    assign branch_wait = cbr_signal &&
                         ((rf_wen_reg1 && rd_reg1 != 0 && rd_reg1 == ra) ||
                          (rf_wen_mid && rd_mid != 0 && rd_mid == ra));
    assign branch_ra_data = (rf_wen_reg2 && rd_reg2 != 0 && rd_reg2 == ra) ?
                           alu_result_reg : ra_rd_data;

    assign extend_imm16 = {16'b0, imm16};
    assign extend_imm16_shift = extend_imm16<<16;

    //Region A ==========================================================================================================
    BranchDecision #(
        .DATA_W(DATA_W)
    ) decide_pc (
        .ra_rd_data(branch_ra_data),
        .br(br_signal),
        .cbr(cbr_signal),
        .PC_sel(PC_sel)
    );

    logic [DATA_W-1:0] alu_oper1;
    logic [DATA_W-1:0] alu_oper2;

    mux4to1 #(
        .DATA_W(DATA_W)
    ) mux_sel_oper1 (
        .d0(ra_forwarded),
        .d1('z),
        .d2('0),
        .d3('z),

        .sel(alu_oper1_sel),
        .dout(alu_oper1)  
    );

    mux8to1 #(
        .DATA_W(DATA_W)
    )mux_sel_oper2(
        .d0(rb_forwarded),
        .d1(extend_imm16),
        .d2('0),
        .d3(32'd1),
        .d4(extend_imm16_shift),
        .d5('z),
        .d6('z),
        .d7('z),

        .sel(alu_oper2_sel),
        .dout(alu_oper2)
    );

    logic [DATA_W-1:0] alu_oper1_reg;
    logic [DATA_W-1:0] alu_oper2_reg;

    logic [2:0] alu_op_reg;
    logic [4:0] ra_reg;
    logic [4:0] rb_reg;
    logic [5:0] opcode_reg;

    // Operand 1 latch reg
    regs #(.DATA_W(DATA_W)) DRA (.clk(clk), .rst(rst), .wen(issue_valid), .din(alu_oper1), .dout(alu_oper1_reg));
    // Operand 2 latch reg
    regs #(.DATA_W(DATA_W)) DRB (.clk(clk), .rst(rst), .wen(issue_valid), .din(alu_oper2), .dout(alu_oper2_reg));
    // RB addr latch reg
    regs #(.DATA_W(5)) ARD (.clk(clk), .rst(rst), .wen(1'b1), .din(rd), .dout(rd_reg1));
    // Reg_file write enable latch reg
    regs #(.DATA_W(1)) WENRF (.clk(clk), .rst(rst), .wen(1'b1), .din(issue_valid && rf_wen), .dout(rf_wen_reg1));
    // ALU_OP latch reg
    regs #(.DATA_W(3)) ALUOPREG (.clk(clk), .rst(rst), .wen(issue_valid), .din(alu_op), .dout(alu_op_reg));
    // RA addr latch reg
    regs #(.DATA_W(5)) ARA (.clk(clk), .rst(rst), .wen(1'b1), .din(ra), .dout(ra_reg));
    // RB addr latch reg
    regs #(.DATA_W(5)) ARB (.clk(clk), .rst(rst), .wen(1'b1), .din(rb), .dout(rb_reg));
    // OPCODE latch reg
    regs #(.DATA_W(6)) OPR (.clk(clk), .rst(rst), .wen(1'b1), .din(instruction[31:26]), .dout(opcode_reg));

    logic [DATA_W-1:0] alu_oper1_final;
    logic [DATA_W-1:0] alu_oper2_final;

    // Operands have already been forwarded at decode.
    assign alu_oper1_final = alu_oper1_reg;
    assign alu_oper2_final = alu_oper2_reg;

    MC_alu #(
        .DATA_W(DATA_W)
    ) alu (
        .clk(clk), .rst(rst), .wen(rf_wen_reg1),
        .operand_1(alu_oper1_final),        // RA(0), RD(1), 0(2)
        .operand_2(alu_oper2_final),        // RB(0), imm16(1), 0(2), 1(3), imm16<<16(4)
        .alu_op(alu_op_reg),
        .result(alu_result)
    );
    // Tags/valid advance with MUL_STAGE/OTHER_STAGE, even while decode waits.
    regs #(.DATA_W(1)) WENRF_MID (.clk(clk), .rst(rst), .wen(1'b1), .din(rf_wen_reg1), .dout(rf_wen_mid));
    regs #(.DATA_W(5)) ARD_MID (.clk(clk), .rst(rst), .wen(1'b1), .din(rd_reg1), .dout(rd_mid));
    // WB captures the result mux one cycle after registered arithmetic results.
    regs #(.DATA_W(DATA_W)) ALU_REG (.clk(clk), .rst(rst), .wen(rf_wen_mid), .din(alu_result), .dout(alu_result_reg));
    // Reg_file write enable latch reg 2
    regs #(.DATA_W(1)) WENRF2 (.clk(clk), .rst(rst), .wen(1'b1), .din(rf_wen_mid), .dout(rf_wen_reg2));
    // RD addr latch reg 2
    regs #(.DATA_W(5)) ARD2 (.clk(clk), .rst(rst), .wen(1'b1), .din(rd_mid), .dout(rd_reg2));

    // Region B ==========================================================================================================
    logic [DATA_W - 1:0] addr_base_src;
    assign addr_base_src = rd_forwarded;
    logic [DATA_W - 1:0] addr_offset_src;
    assign addr_offset_src = ra_forwarded;
    logic [DATA_W - 1:0] addr_base_dest;
    assign addr_base_dest = rb_forwarded;
    logic [DATA_W - 1:0] addr_offset_dest;
    assign addr_offset_dest = rtemp_forwarded;
    logic [3:0] type_access_reg;
    logic [DATA_W - 1:0] addr_base_src_reg;
    logic [DATA_W - 1:0] addr_offset_src_reg;
    logic [DATA_W - 1:0] addr_base_dest_reg;
    logic [DATA_W - 1:0] addr_offset_dest_reg;

    regs #(.DATA_W(4)) IR(.clk(clk), .rst(rst), .wen(1'b1), .din(issue_valid ? type_access : 4'd0), .dout(type_access_reg));
    regs #(.DATA_W(DATA_W)) DR_Base_OM(.clk(clk), .rst(rst), .wen(issue_valid), .din(addr_base_src), .dout(addr_base_src_reg));
    regs #(.DATA_W(DATA_W)) DR_Offset_OM(.clk(clk), .rst(rst), .wen(issue_valid), .din(addr_offset_src), .dout(addr_offset_src_reg));
    regs #(.DATA_W(DATA_W)) DR_Base_DNN(.clk(clk), .rst(rst), .wen(issue_valid), .din(addr_base_dest), .dout(addr_base_dest_reg));
    regs #(.DATA_W(DATA_W)) DR_Offset_DNN(.clk(clk), .rst(rst), .wen(issue_valid), .din(addr_offset_dest), .dout(addr_offset_dest_reg));

    logic [67:0] cmd;  
    MemAcsCmdGen #(
        .DATA_W(DATA_W)
    ) macg (
        .base_addr_src(addr_base_src_reg),
        .offset_addr_src(addr_offset_src_reg),
        .base_addr_dst(addr_base_dest_reg),
        .offset_addr_dst(addr_offset_dest_reg),
        .type_access(type_access_reg),

        .cmd(cmd)
    );
    // command latch reg
    logic [67:0] cmd_reg;
    // If an incoming port request wins the idle memory FSM while a local
    // command is in flight, retain that command until it can be accepted.
    regs #(.DATA_W(68)) CMD_REG(.clk(clk), .rst(rst),
        .wen(!memory_busy || cmd_reg[67:64] == 0), .din(cmd), .dout(cmd_reg));

    // Memory/control instructions wait for outstanding transfers, while ALU
    // and branch work can overlap them. No command is dropped or reissued,
    // and a following SDC/END cannot pass an unfinished memory write.
    assign memory_inflight = (type_access_reg != 0) || (cmd_reg[67:64] != 0) || memory_busy;
    assign fetch_memory_wait = memory_inflight &&
                               ((type_access != 0) ||
                                (instruction[31:26] >= 6'd21 && instruction[31:26] <= 6'd24));
    assign end_drain = (instruction[31:26] == 6'b010111) &&
                       ((rf_wen_reg1 && rd_reg1 != 0) ||
                        (rf_wen_mid && rd_mid != 0) || (rf_wen_reg2 && rd_reg2 != 0));
    assign issue_valid = instruction_valid && start_flag && PC_en && !end_flag && !fetch_memory_wait &&
                         !end_drain && !branch_wait && !data_wait;

    Mem_ctrl #(
        .BASE_DATA_OM(BASE_DATA_OM),
        .IS_FIRST_COL(IS_FIRST_COL)
    ) mctrl (
        .clk(clk),
        .rst(rst),
        .busy(memory_busy),

        // command from controller
        .command_mc(cmd_reg),

        // PORT0 ==================================
        .command_P0_in(command_P0_in),
        .data_P0_in(data_P0_in),
        .command_P0_out(command_P0_out),
        .data_P0_out(data_P0_out),

        // PORT1 ==================================
        .command_P1_in(command_P1_in),
        .data_P1_in(data_P1_in),
        .inst_P1_in(inst_P1_in),
        .command_P1_out(command_P1_out),
        .data_P1_out(data_P1_out),
        .inst_P1_out(inst_P1_out),

        // PORT OM ==================================
        .OM_addr(OM_addr),
        .OM_wen(OM_wen),
        .OM_ren(OM_ren),
        .OM_rd_data(OM_rd_data),
        .OM_wr_data(OM_wr_data),
        .OM_inst_ren(OM_inst_ren),
        .OM_inst_rd(OM_inst_rd),

        // PORT DNN Core ===========================
        .DNN_addr(DNN_addr),
        .DNN_rd_data(DNN_rd_data),
        .DNN_wr_data(DNN_wr_data),
        .DNN_inst_wr(DNN_inst_wr),
        .mem_inst_wen(mem_inst_wen),
        .IB_wen(IB_wen),
        .KSP_wen(KSP_wen),
        .BSP_wen(BSP_wen),
        .OB_ren(OB_ren)
    );

    // Region C ==========================================================================================================
    logic [5:0] mode_opcode;
    // A held PC is not reissued; waiting states still respond to handshakes.
    assign mode_opcode = issue_valid ? instruction[31:26] : 6'b111111;
    generate 
        if(MODEL == `SINGLE) begin
            assign hsync_out       = '0;
            assign done_transfer   = '0;
            assign done_vtransfer  = '0;
            Mode_ctrller_2 mode_ctrl(
                .opcode(mode_opcode),
                .clk(clk),
                .rst(rst),        
                .start(start),      // DSIP start flag
                .dnn_done(dnn_done),       
                .vsync_in(vsync_in),       // DSIP vsync flag
                .vsync_out(vsync_out),      
                .start_DNN(start_DNN),      // DNN_core start flag
                .end_flag(end_flag),       // End instruction flag
                .enable_PC(PC_en)
            );
        end
        else if (MODEL == `ONE_ONE) begin
            assign done_vtransfer  = '0;
            Mode_ctrller_3  #(
                .IS_FIRST_COL(IS_FIRST_COL),
                .IS_FIRST_ROW(IS_FIRST_ROW)
            )mode_ctrl(
                .opcode(mode_opcode),
                .clk(clk),
                .rst(rst),        
                .start(start),      // DSIP start flag
                .DNN_done(dnn_done),
                .vsync_in(vsync_in),       // DSIP vsync flag
                .hsync_in(hsync_in),
                .vsync_out(vsync_out),
                .hsync_out(hsync_out),
                .start_DNN_core(start_DNN),      // DNN_core start flag
                .enable_PC(PC_en),
                .end_flag(end_flag),
                .done_transfer_prev(done_transfer_prev),
                .done_transfer(done_transfer)
            );
        end
        else if (MODEL == `TWO_TWO) begin
            Mode_ctrller_4 #(
                .IS_FIRST_COL(IS_FIRST_COL),
                .IS_FIRST_ROW(IS_FIRST_ROW)
            )mode_ctrl(
                .opcode(mode_opcode),
                .clk(clk),
                .rst(rst),
                .start(start),      // DSIP start flag
                .vsync_in(vsync_in),       // DSIP vsync flag
                .hsync_in(hsync_in),
                .DNN_done(dnn_done),
                .vsync_out(vsync_out),
                .hsync_out(hsync_out),
                .start_DNN_core(start_DNN),      // DNN_core start flag
                .enable_PC(PC_en),
                .end_flag(end_flag),
                .done_transfer_prev(done_transfer_prev),
                .done_transfer(done_transfer),
                .done_vtransfer_prev(done_vtransfer_prev),
                .done_vtransfer(done_vtransfer)
            );
        end
    endgenerate
endmodule
