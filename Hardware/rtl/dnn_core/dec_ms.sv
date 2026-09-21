module DecoderMS #(
    parameter MST0 = 3'h0,             // No store
    parameter MST1 = 3'h1,             // Store OB
    parameter MST2 = 3'h2,             // Store OSP 
    parameter MST3 = 3'h3,             // Store FCSP        
    parameter MST4 = 3'h4,             // Store OB, OSP
    parameter MST5 = 3'h5,             // Store OB, FCSP
    parameter MST6 = 3'h6,             // Store OSP, FCSP
    parameter MST7 = 3'h7              // Store OB, OSP, FCSP
)(
    input  logic [6:0]  slot7,

    output logic        en_store_OB,
    output logic        en_store_OSP,
    output logic        en_store_FCSP,
    output logic [1:0]  src_store_OB,
    output logic [1:0]  src_store_MEM
);
    always_comb begin
        case(slot7[6:4])
            // No store
            MST0: begin
                en_store_OB = '0; en_store_OSP = '0; en_store_FCSP = '0; 
            end 
            // Store OB
            MST1: begin
                en_store_OB = 1'b1;
                en_store_OSP = '0; en_store_FCSP = '0;
            end
            // Store OSP
            MST2: begin
                en_store_OSP = 1'b1;
                en_store_OB = '0; en_store_FCSP = '0;
            end
            // Store FCSP
            MST3: begin
                en_store_FCSP = 1'b1;
                en_store_OB = '0; en_store_OSP = '0;
            end
            // Store OB, OSP
            MST4: begin
                en_store_OB = 1'b1; en_store_OSP = 1'b1;
                en_store_FCSP = '0;
            end
            // Store OB, FCSP
            MST5: begin
                en_store_OB = 1'b1; en_store_FCSP = 1'b1;
                en_store_OSP = '0;
            end
            // Store OSP, FCSP
            MST6: begin
                en_store_OSP = 1'b1; en_store_FCSP = 1'b1;
                en_store_OB = '0;
            end
            // Store OB, OSP, FCSP
            MST7: begin
                en_store_OB = 1'b1; en_store_OSP = 1'b1; en_store_FCSP = 1'b1;
            end
            default: begin
                en_store_OB = '0; en_store_OSP = '0; en_store_FCSP = '0;
            end
        endcase
    end

    assign src_store_OB     = slot7[3:2];
    assign src_store_MEM    = slot7[1:0];
endmodule