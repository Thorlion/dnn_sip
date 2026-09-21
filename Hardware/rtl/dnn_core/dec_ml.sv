module DecoderML #(
    parameter MLD0 = 3'b000,        // no load
    parameter MLD1 = 3'b001,        // load from IB
    parameter MLD2 = 3'b010,        // load from IB, KSP
    parameter MLD3 = 3'b011,        // load from IB, OSP
    parameter MLD4 = 3'b100,        // load from IB, KSP, OSP    
    parameter MLD5 = 3'b101,        // load from OSP, BSP
    parameter MLD6 = 3'b110,        // load from FCSP, BSP
    parameter MLD7 = 3'b111         // load from FCSP, BSP, OSP
)(
    input  logic [10:0] slot3,
    //Enable load signal
    output logic en_load_IB,
    output logic en_load_KSP,
    output logic en_load_OSP,
    output logic en_load_BSP,
    output logic en_load_FCSP,
    //Select MLOM (Memory Load OSP Muxed_ Select 1-63 )
    output logic [7:0] sel_MLOM         
);
    always_comb begin
        case(slot3[10:8])
            MLD0: begin     // not load
                en_load_IB = 0; en_load_KSP = 0; en_load_OSP = 0; en_load_BSP = 0; en_load_FCSP = 0;
            end
            MLD1: begin     // load IB
                en_load_IB = 1'b1; 
                {en_load_KSP, en_load_OSP, en_load_BSP, en_load_FCSP} = 4'b0000;
            end
            MLD2: begin     // load IB, KSP
                en_load_IB  = 1'b1;
                en_load_KSP = 1'b1;
                {en_load_OSP, en_load_BSP, en_load_FCSP} = 3'b000;
            end
            MLD3: begin     // load IB, OSP
                en_load_IB  = 1'b1;
                en_load_OSP = 1'b1;
                {en_load_KSP, en_load_BSP, en_load_FCSP} = 3'b000;
            end
            MLD4: begin     // load IB, KSP, OSP
                en_load_IB  = 1'b1;
                en_load_KSP = 1'b1;
                en_load_OSP = 1'b1;
                {en_load_BSP, en_load_FCSP} = 2'b00;
            end
            MLD5: begin     // load from OSP, BSP
                en_load_OSP = 1'b1;
                en_load_BSP = 1'b1;
                {en_load_IB, en_load_KSP, en_load_FCSP} = 3'b000;
            end
            MLD6: begin     // load from FCSP, BSP
                en_load_FCSP = 1'b1;
                en_load_BSP = 1'b1;
                {en_load_IB, en_load_KSP, en_load_OSP} = 3'b000;
            end
            MLD7: begin     // load from FCSP, BSP, OSP
                en_load_FCSP = 1'b1;
                en_load_BSP = 1'b1;
                en_load_OSP = 1'b1;
                {en_load_IB, en_load_KSP} = 2'b00;
            end
            default: begin
                en_load_IB = 0; en_load_KSP = 0; en_load_OSP = 0; en_load_BSP = 0; en_load_FCSP = 0;
            end
        endcase
    end
    // Select MLOM (Memory Load OSP Muxed)
    assign sel_MLOM = slot3[7:0];
    
endmodule