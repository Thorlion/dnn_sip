module memory_controller_tb;

    // Parameters
    parameter DATA_WIDTH = 16;
    parameter INSTRUCTION_WIDTH = 123;

    // Inputs
    bit clk;
    bit rst;
    bit [65:0] request;

    // Outputs
    wire wen_OM_data;
    wire ren_OM_data;
    wire [DATA_WIDTH - 1:0] data_w_OM;
    wire [31:0] addr_w_OM_data;
    wire [31:0] addr_r_OM_data;
    wire ren_OM_inst;
    wire [31:0] addr_r_OM_inst;
    wire wen_SCmem;
    wire [63:0] wen_IB;
    wire [63:0] wen_KSP;
    wire wen_BSP;
    wire [15:0] data_w_SC;
    wire [INSTRUCTION_WIDTH - 1:0] inst_w_SC;
    wire [31:0] addr_w_SC;
    wire ren_OB;
    wire [31:0] addr_r_SC;

    // Wires for connecting memory data
    bit [DATA_WIDTH - 1:0] data_r_OM;
    bit [INSTRUCTION_WIDTH - 1:0] inst_r_OM;
    bit [15:0] data_r_SC;
    wire ready_signal;
    bit new_request;
    wire [2:0] state;
    // Instantiate the module
    memory_controller #(
        .DATA_WIDTH(DATA_WIDTH),
        .INSTRUCTION_WIDTH(INSTRUCTION_WIDTH)
    ) uut (
        .clk(clk),
        .rst(rst),
        .request(request),
        .wen_OM_data(wen_OM_data),
        .ren_OM_data(ren_OM_data),
        .data_w_OM(data_w_OM),
        .data_r_OM(data_r_OM),
        .addr_w_OM_data(addr_w_OM_data),
        .addr_r_OM_data(addr_r_OM_data),
        .ren_OM_inst(ren_OM_inst),
        .inst_r_OM(inst_r_OM),
        .addr_r_OM_inst(addr_r_OM_inst),
        .wen_SCmem(wen_SCmem),
        .wen_IB(wen_IB),
        .wen_KSP(wen_KSP),
        .wen_BSP(wen_BSP),
        .data_w_SC(data_w_SC),
        .inst_w_SC(inst_w_SC),
        .addr_w_SC(addr_w_SC),
        .ren_OB(ren_OB),
        .data_r_SC(data_r_SC),
        .addr_r_SC(addr_r_SC),
        .ready_signal(ready_signal)
//        .new_request(new_request)
    );

    // Clock generation
    always #5 clk = ~clk;
//    always #30 data_r_OM = $random();
//    always #30 data_r_SC = $random();
    always #30 inst_r_OM = $random();
    
    // OB mem
    bit [DATA_WIDTH - 1: 0] mem_OB_data [0:63];
    initial begin
        foreach(mem_OB_data[i])
            mem_OB_data[i] = $random();
            
    end 
    always @(posedge clk) begin
        if(ren_OB) data_r_SC = mem_OB_data[request[31:0]];
    end
    
    // OM mem
    bit [DATA_WIDTH - 1: 0] mem_OM_data [0:63];
    initial begin
        foreach(mem_OM_data[i])
            mem_OM_data[i] = $random();
            
    end 
    always @(posedge clk) begin
        if(wen_OM_data) mem_OM_data[addr_w_OM_data] = data_w_OM;
        else if(ren_OM_data) data_r_OM = mem_OM_data[addr_r_OM_data];
    end
    
    // BSP mem
    bit [DATA_WIDTH - 1: 0] mem_BSP_data [0:63];
    always @(posedge clk) begin
        if(wen_BSP) mem_BSP_data[addr_w_SC] = data_r_OM;
    end
    
    initial begin
        // Initialize inputs
        clk = 0;
        rst = 1;
        request = 0;
//        data_r_OM = 16'hABCD;
//        inst_r_OM = 123'h123456789ABCDEF123456789;
//        data_r_SC = 16'hDEAD;

        // Reset the system
        #400;
        rst = 0;
        #50


        // Test case 1: Verify write enable signals for KSP, IB, BSP and SC instruction
//        new_request = 1;
        request = {2'b01, 32'h00000010, 32'b0000_000000_0000000000000000000000}; // Write to KSP
        #10
//        new_request = 0;
        #20
        request = {2'b01, 32'h00000010, 32'b0001_000100_0000000000000000000010}; // Write to IB
        #30;
//        new_request = 0;
        request = {2'b01, 32'h00000010, 32'b0010_000000_0000000000000000000101}; // Write to BSP
        #30
//        new_request = 1;
        request = {2'b01, 32'h00020000, 32'b0000_000000_0000000000000000000000}; // Write to SC instruction mem
        #30;
//        new_request = 0;
        request = {2'b00, 32'h00000000, 32'b0000_000000_0000000000000000000000}; // no action
        
        
        //         Test case 2: Opcode 10, write data from SC to OM
        #120
        request = {2'b10, 32'h00000020, 32'b0000_000000_0000000000000000000000}; // read data from addr 0 of OB and store in addr 0x20 of OM
        #30
        request = {2'b00, 32'h00000000, 32'b0000_000000_0000000000000000000000}; // no action

        #30
        request = {2'b10, 32'h00000021, 32'b0000_000000_0000000000000000000001}; // read data from addr 1 of OB and store in addr 0x21 of OM
        #30
        request = {2'b10, 32'h00000022, 32'b0000_000000_0000000000000000000010}; // read data from addr 2 of OB and store in addr 0x22 of OM
        #30
        request = {2'b10, 32'h00000023, 32'b0000_000000_0000000000000000000011}; // read data from addr 3 of OB and store in addr 0x23 of OM
        #30
        request = {2'b00, 32'h00000000, 32'b0000_000000_0000000000000000000000}; // no action

        $stop;
    end

endmodule
