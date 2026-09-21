module DecoderIF #(
    parameter SCRATCHPAD_W = 512
)(
    input  logic [10:0] slot1,
    input  logic [90:0] slot2,

    output logic run_en,
    output logic sit_en,
    output logic sbp_en,
    output logic sof_en,
    output logic [8:0] offset,

    output logic new_base_addr,
    // [8:0]
    output logic [$clog2(SCRATCHPAD_W)-1:0] IB_rd_base_addr,
    output logic [$clog2(SCRATCHPAD_W)-1:0] KSP_rd_base_addr,
    output logic [$clog2(SCRATCHPAD_W)-1:0] OSP_wr_base_addr,
    output logic [$clog2(SCRATCHPAD_W)-1:0] OSP_rd_base_addr,
    output logic [$clog2(SCRATCHPAD_W)-1:0] OB_wr_base_addr,
    output logic [$clog2(SCRATCHPAD_W)-1:0] OB_rd_base_addr,
    output logic [$clog2(SCRATCHPAD_W)-1:0] BSP_rd_base_addr,
    output logic [$clog2(SCRATCHPAD_W)-1:0] FCSP_wr_base_addr,
    output logic [$clog2(SCRATCHPAD_W)-1:0] FCSP_rd_base_addr
);
    // Slot1 Decoder (Configuration)
    always_comb begin
        case(slot1[10:9])
            2'b00: begin
                // Enable AGU run
                run_en = 1'b1;
                sit_en = 1'b0; sbp_en = 1'b0; sof_en = 1'b0;                
            end
            2'b01: begin
                // Set Breakpoint
                run_en = 1'b0; sit_en = 1'b0; sof_en = 1'b0;
                sbp_en = 1'b1;                
            end 
            2'b10: begin
                // Set offset
                run_en = 1'b0; sit_en = 1'b0; sbp_en = 1'b0;
                sof_en = 1'b1;    
            end 
            2'b11: begin
                // Set number of loop
                run_en = 1'b0; sbp_en = 1'b0; sof_en = 1'b0;
                sit_en = 1'b1;                
            end
            default: begin
                run_en = 1'b0; sit_en = 1'b0; sbp_en = 1'b0; sof_en = 1'b0;
            end
        endcase
    end

    assign offset = slot1[8:0];

    // Slot2 Decoder (base_addr for Scratchpad)
    always_comb begin
        new_base_addr       = slot2[90];
        IB_rd_base_addr     = slot2[89:80];
        KSP_rd_base_addr    = slot2[79:70];
        OSP_wr_base_addr    = slot2[69:60];
        OSP_rd_base_addr    = slot2[59:50];
        OB_wr_base_addr     = slot2[49:40];
        OB_rd_base_addr     = slot2[39:30];
        BSP_rd_base_addr    = slot2[29:20];
        FCSP_wr_base_addr   = slot2[19:10];
        FCSP_rd_base_addr   = slot2[9:0];
    end 
endmodule