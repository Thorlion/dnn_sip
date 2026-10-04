module Mem_ctrl #(
    parameter BASE_DATA_OM = 32'h00010000,
    parameter IS_FIRST_COL = 0
)(
    input  logic clk,
    input  logic rst,
    output logic busy,

    // Command from controller
    input  logic [67:0]     command_mc,
    // PORT 0 =================================
    input  logic [67:0]     command_P0_in,
    input  logic [15:0]     data_P0_in,
    output logic [67:0]     command_P0_out,
    output logic [15:0]     data_P0_out,

    // PORT 1 =================================
    input  logic [67:0]     command_P1_in,
    input  logic [15:0]     data_P1_in,
    input  logic [211:0]    inst_P1_in,
    output logic [67:0]     command_P1_out,
    output logic [15:0]     data_P1_out,
    output logic [211:0]    inst_P1_out,

    // PORT OM ================================
    output logic [31:0]     OM_addr,
    output logic            OM_wen,
    output logic            OM_ren,

    input  logic [15:0]     OM_rd_data,
    output logic [15:0]     OM_wr_data,

    output logic            OM_inst_ren,
    input  logic [211:0]    OM_inst_rd,

    //PORT DNN core ===========================
    output logic [8:0]      DNN_addr,
    output logic            mem_inst_wen,
    output logic [63:0]     IB_wen,
    output logic [63:0]     KSP_wen,
    output logic            BSP_wen,
    output logic            OB_ren,
    output logic [15:0]     DNN_wr_data,
    input  logic [15:0]     DNN_rd_data,

    output logic [211:0]    DNN_inst_wr
);
    logic [211:0]   OM_inst_rd_temp;
    logic [4:0]     state;
    logic [67:0]    cmd_temp;
    logic [15:0]    data_temp;
    logic [211:0]   inst_temp;
    assign busy = (state != 0);

    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            state       <= '0;
            cmd_temp    <= '0; 
            data_temp   <= '0; 
            inst_temp   <= '0;
        end else begin
            // state = 0 & got cmd from controller (OM -> DNN)
            if (state == '0 && command_mc[67:64] == 4'b0001) begin
                state       <= 5'd1;
                cmd_temp    <= command_mc;
            end 
            // Case: state send data from OM to DNN
            else if (state == 5'd1) begin
                state <= 5'd2;
            end
            else if (state == 5'd2) begin
                state       <= 5'd0;
                cmd_temp    <= '0;
            end

            // state = 0 & got cmd from controller (DNN -> OM)
            else if (state == '0 && command_mc[67:64] == 4'b0100) begin
                state       <= 5'd3;
                cmd_temp    <= command_mc;
            end
            // Case: state send data from DNN to OM
            else if (state == 5'd3) begin
                state <= 5'd4;
            end
            else if (state == 5'd4) begin
                state       <= 5'd0;
                cmd_temp    <= '0;
            end

            // state = 0 & got cmd from controller (OM -> P0)
            else if (state == '0 && (command_mc[67:64] == 4'b0010 | command_mc[67:64] == 4'b0111)) begin
                state       <= 5'd5;
                cmd_temp    <= command_mc;
            end 
            // Case: state send data from OM to P0
            else if (state == 5'd5) begin
                state <= 5'd6;
            end
            else if (state == 5'd6) begin
                state       <= 5'd0;
                cmd_temp    <= '0;
            end

            // state = 0 & got cmd from controller (P0 -> OM or next DNN)
            else if (state == '0 && (command_P0_in[67:64] == 4'b0010 | command_P0_in[67:64] == 4'b0111)) begin
                state       <= 5'd7;
                cmd_temp    <= command_P0_in;
                data_temp   <= data_P0_in;
            end
            else if (state == 5'd7) begin
                state <= 5'd8;
            end
            else if (state == 5'd8) begin
                state       <= 5'd0;
                cmd_temp    <= '0;
                data_temp   <= '0;
            end

            // state = 0 & got cmd from controller (OM -> P1)
            else if (state == '0 && (command_mc[67:64] == 4'b0011 | command_mc[67:64] == 4'b1000)) begin
                state       <= 5'd9;
                cmd_temp    <= command_mc;
            end
            // Case: state send data from OM to P1
            else if (state == 5'd9) begin
                state <= 5'd10;
            end
            else if (state == 5'd10) begin
                state       <= 5'd0;
                cmd_temp    <= '0;
            end

            // state = 0 & got cmd from controller (P1 -> OM or next DNN)
            else if (state == '0 && (command_P1_in[67:64] == 4'b0011 | command_P1_in[67:64] == 4'b1000 | command_P1_in[67:64] == 4'b0110 | command_P1_in[67:64] == 4'b0100)) begin
                state       <= 5'd11;
                cmd_temp    <= command_P1_in;
                data_temp   <= data_P1_in;
                inst_temp   <= inst_P1_in;
            end
            else if (state == 5'd11) begin
                state <= 5'd12;
            end
            else if (state == 5'd12) begin
                state       <= 5'd0;
                cmd_temp    <= '0;
                data_temp   <= '0;
            end

            // state = 0 & got cmd to transfer data from OM to P1 (dest is OM-broadcast) (broadcase cmd & data)
            else if (state == '0 && command_mc[67:64] == 4'b0110) begin
                state       <= 5'd15;
                cmd_temp    <= command_mc;   
            end
            else if (state == 5'd15) begin
                state <= 5'd16;
            end
            else if (state == 5'd16) begin
                state       <= 5'd0;
                cmd_temp    <= '0;
            end

            else if (state == '0) begin
                data_temp   <= '0;
                cmd_temp    <= '0;
                inst_temp   <= '0;
            end
            else begin
                data_temp   <= '0;
                cmd_temp    <= '0;
                inst_temp   <= '0;
            end
        end
    end

    // Control Decoding state
    always_comb begin
        // Fully combinational Moore decoding; do not latch stale strobes/data.
        OM_addr = '0;
        OM_wen = 1'b0;
        OM_ren = 1'b0;
        OM_wr_data = '0;
        OM_inst_ren = 1'b0;
        DNN_addr = '0;
        mem_inst_wen = 1'b0;
        IB_wen = '0;
        KSP_wen = '0;
        BSP_wen = 1'b0;
        OB_ren = 1'b0;
        DNN_wr_data = '0;
        DNN_inst_wr = '0;
        command_P0_out = '0;
        data_P0_out = '0;
        command_P1_out = '0;
        data_P1_out = '0;
        inst_P1_out = '0;
        case(state) 
            5'd0: begin
                //PORT OM
                OM_addr     = '0;
                OM_wen      = '0;
                OM_ren      = '0;
                OM_wr_data  = '0;
                OM_inst_ren = '0;

                //PORT DNN Core
                DNN_addr        = '0;
                mem_inst_wen    = '0;
                IB_wen          = '0;
                KSP_wen         = '0;
                BSP_wen         = '0;
                OB_ren          = '0;
                DNN_wr_data     = '0;
                DNN_inst_wr     = '0;

                //PORT 0
                command_P0_out = '0;
                data_P0_out    = '0;

                //PORT 1
                command_P1_out = '0;
                data_P1_out    = '0;
                inst_P1_out    = '0;
            end
            
            //Case Data from OM to DNN
            5'd1: begin
                //PORT OM
                OM_addr     = cmd_temp[63:32];
                OM_wen      = '0;
                OM_wr_data  = '0;
                if (OM_addr < BASE_DATA_OM) begin
                    OM_inst_ren = 1'b1;
                end else begin
                    OM_ren = 1'b1;
                end
            end
            5'd2: begin
                //PORT OM
                OM_addr     = '0;
                OM_wen      = '0;
                OM_ren      = '0;
                OM_wr_data  = '0;
                OM_inst_ren = '0;

                //PORT DNN Core
                DNN_addr        = cmd_temp[8:0];    //DNN access address
                if (cmd_temp[18:16] == 3'b001) begin
                    IB_wen          = bit_selector(cmd_temp[15:9]); 
                    KSP_wen         = '0;
                    BSP_wen         = '0;
                    OB_ren          = '0;
                    mem_inst_wen    = '0;
                    DNN_wr_data     = OM_rd_data;
                end
                else if (cmd_temp[18:16] == 3'b010) begin
                    IB_wen          = '0;
                    KSP_wen         = bit_selector(cmd_temp[15:9]);
                    BSP_wen         = '0;
                    OB_ren          = '0;
                    mem_inst_wen    = '0;
                    DNN_wr_data     = OM_rd_data;
                end
                else if (cmd_temp[18:16] == 3'b011) begin
                    IB_wen          = '0;
                    KSP_wen         = '0;
                    BSP_wen         = 1'b1;
                    OB_ren          = '0;
                    mem_inst_wen    = '0;
                    DNN_wr_data     = OM_rd_data;
                end
                else if (cmd_temp[18:16] == 3'b101) begin
                    IB_wen          = '0;
                    KSP_wen         = '0;
                    BSP_wen         = '0;
                    OB_ren          = '0;
                    mem_inst_wen    = 1'b1;
                    DNN_inst_wr     = OM_inst_rd;
                end
                else begin
                    IB_wen          = '0;
                    KSP_wen         = '0;
                    BSP_wen         = '0;
                    OB_ren          = '0;
                    mem_inst_wen    = '0;
                end
            end

            //Case Data from DNN to OM
            5'd3: begin
                OB_ren          = 1'b1;
                DNN_addr         = cmd_temp[40:32];      // OB Size is 512bit
            end

            5'd4: begin
                // If DSIP connects directly with OM
                OB_ren          = '0;
                DNN_addr        = '0;
                if (IS_FIRST_COL) begin
                    OM_addr     = cmd_temp[31:0];
                    OM_wen      = 1'b1;
                    OM_wr_data  = DNN_rd_data;
                end
                else begin
                    command_P1_out = cmd_temp;
                    data_P1_out    = DNN_rd_data;
                end
            end
            
            // Case Data from OM to P0
            //Read OM
            5'd5: begin 
                OM_addr     = cmd_temp[63:32];
                OM_ren      = 1'b1;
            end
            //Send data to P0
            5'd6: begin
                OM_addr     = '0;
                OM_ren      = '0;
                command_P0_out = cmd_temp;
                data_P0_out    = OM_rd_data;
            end

            // Case Data from P0 to (OM or DNN) of next DSIP
            // Get data from P0
            5'd7: begin
                //Case send to OM
                if (cmd_temp[67:64] == 4'b0010) begin
                    OM_wen      = 1'b1;             // Access OM -> Enable write OM
                    OM_addr     = cmd_temp[31:0];   // Destination port
                    OM_wr_data  = data_temp;
                end
                else if (cmd_temp[67:64] == 4'b0111) begin
                    DNN_addr        = cmd_temp[8:0];    //DNN access address
                    DNN_wr_data     = data_temp;
                    if (cmd_temp[18:16] == 3'b001) begin
                        IB_wen          = bit_selector(cmd_temp[15:9]);
                        KSP_wen         = '0;
                        BSP_wen         = '0;
                    end
                    else if (cmd_temp[18:16] == 3'b010) begin
                        IB_wen          = '0;
                        KSP_wen         = bit_selector(cmd_temp[15:9]);
                        BSP_wen         = '0;
                    end
                    else if (cmd_temp[18:16] == 3'b011) begin
                        IB_wen          = '0;
                        KSP_wen         = '0;
                        BSP_wen         = 1'b1;
                    end
                    else begin
                        IB_wen          = '0;
                        KSP_wen         = '0;
                        BSP_wen         = '0;
                    end
                end
            end

            5'd8: begin
                OM_wen      = '0;
                OM_addr     = '0;
                OM_wr_data  = '0;

                DNN_addr        = '0;
                DNN_wr_data     = '0;

                IB_wen          = '0;
                KSP_wen         = '0;
                BSP_wen         = '0;
                mem_inst_wen    = '0;
            end
            
            //Case Data from OM to P1
            5'd9: begin
                OM_addr     = cmd_temp[63:32];
                OM_ren      = 1'b1;
            end
            //Send data to P1
            5'd10: begin
                OM_addr     = '0;
                OM_ren      = '0;
                command_P1_out = cmd_temp;
                data_P1_out    = OM_rd_data;
            end

            //Case Data from P1 to (OM or DNN) of next DSIP
            //Get data from P1            
            5'd11: begin
                //Case send to OM
                if (cmd_temp[67:64] == 4'b0011 | cmd_temp[67:64] == 4'b0100) begin
                    OM_wen      = 1'b1;             // Access OM -> Enable write OM
                    OM_addr     = cmd_temp[31:0];   // Destination port
                    OM_wr_data  = data_temp;
                end
                //Case send to DNN (both inst and data)
                else if (cmd_temp[67:64] == 4'b1000 | cmd_temp[67:64] == 4'b0110) begin
                    DNN_addr        = cmd_temp[8:0];    //DNN access address
                    DNN_wr_data     = data_temp;
                    if (cmd_temp[18:16] == 3'b001) begin
                        IB_wen          = bit_selector(cmd_temp[15:9]);
                        OM_wr_data      = data_temp;
                    end
                    else if (cmd_temp[18:16] == 3'b010) begin
                        KSP_wen         = bit_selector(cmd_temp[15:9]);
                        OM_wr_data      = data_temp;
                    end
                    else if (cmd_temp[18:16] == 3'b011) begin
                        BSP_wen         = 1'b1;
                        OM_wr_data      = data_temp;
                    end
                    else if (cmd_temp[18:16] == 3'b101) begin
                        mem_inst_wen    = 1'b1;
                        DNN_inst_wr     = inst_temp;
                    end
                end
            end

            5'd12: begin
                OM_wen      = '0;
                OM_addr     = '0;
                OM_wr_data  = '0;

                DNN_addr        = '0;
                DNN_wr_data     = '0;

                IB_wen          = '0;
                KSP_wen         = '0;
                BSP_wen         = '0;
                mem_inst_wen    = '0;
            end

            // Case Data from OM to P1 (broadcast)
            5'd15: begin
                //Read data from OM
                OM_addr     = cmd_temp[63:32];
                OM_wen      = '0;
                OM_wr_data  = '0;
                if( OM_addr < BASE_DATA_OM) begin
                    OM_inst_ren = 1'b1;
                end else begin
                    OM_ren = 1'b1;
                end
            end

            5'd16: begin
                // Control write to DNN of current DSIP
                //OM
                OM_addr     = '0;
                OM_wen      = '0;
                OM_inst_ren = '0;
                OM_ren      = '0;
                OM_wr_data  = '0;

                //DNN
                DNN_addr        = cmd_temp[8:0];    //DNN access address
                if(cmd_temp[18:16] == 3'b001) begin
                    IB_wen          = bit_selector(cmd_temp[15:9]);
                    KSP_wen         = '0;
                    BSP_wen         = '0;
                    OB_ren          = '0;
                    mem_inst_wen    = '0;
                    DNN_wr_data     = OM_rd_data;
                end
                else if(cmd_temp[18:16] == 3'b010) begin
                    IB_wen          = '0;
                    KSP_wen         = bit_selector(cmd_temp[15:9]);
                    BSP_wen         = '0;
                    OB_ren          = '0;
                    mem_inst_wen    = '0;
                    DNN_wr_data     = OM_rd_data;
                end
                else if(cmd_temp[18:16] == 3'b011) begin
                    IB_wen          = '0;
                    KSP_wen         = '0;
                    BSP_wen         = 1'b1;
                    OB_ren          = '0;
                    mem_inst_wen    = '0;
                    DNN_wr_data     = OM_rd_data;
                end
                else if(cmd_temp[18:16] == 3'b101) begin
                    IB_wen          = '0;
                    KSP_wen         = '0;
                    BSP_wen         = '0;
                    OB_ren          = '0;
                    mem_inst_wen    = 1'b1;
                    DNN_inst_wr     = OM_inst_rd;
                end
                command_P1_out = cmd_temp;
                data_P1_out    = OM_rd_data;
                inst_P1_out    = OM_inst_rd;
            end
            default: begin
            end
        endcase
    end

    function [127:0] bit_selector;
        input [6:0] position; // Vị trí bit đầu vào
        begin
            bit_selector = 128'h1 << position; // Dịch bit `1` sang vị trí tương ứng
        end
    endfunction
endmodule
