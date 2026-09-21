module Mode_ctrller_2 #(
    parameter START_DNN = 6'b010101,
    parameter VSYNC     = 6'b010110,
    parameter END_F     = 6'b010111
)(
    input  logic [5:0]  opcode,
    input  logic        clk,
    input  logic        rst,
    input  logic        start,          // DSIP start flag
    input  logic        dnn_done,       
    input  logic        vsync_in,       // DSIP vsync flag
    output logic        vsync_out,      
    output logic        start_DNN,      // DNN_core start flag
    output logic        end_flag,       // End instruction flag
    output logic        enable_PC       // PC enable flag   -> 1: PC enable, 0: PC disable
);
    logic [3:0] state;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state       <= '0;
            vsync_out   <= '0;
            start_DNN   <= '0;
            end_flag    <= '0;
            enable_PC   <= 1'b1;
        end else begin
            if (state == 4'd0 && start == 1) begin
                state       <= 4'd1;
                end_flag    <= '0;
                enable_PC   <= 1'b1;
            end
            else if (state == 4'd1 && opcode == VSYNC) begin
                state       <= 4'd2;
                vsync_out   <= 1'b1;
                enable_PC   <= '0;
            end
            else if (state == 4'd1 && opcode == END_F) begin
                state       <= 4'd6;
                vsync_out   <= '0;
                end_flag    <= 1'b1;
                enable_PC   <= 1;
            end 
            else if (state == 4'd2 && vsync_in == 1) begin
                state       <= 4'd3;
                vsync_out   <= '0;
                enable_PC   <= 1'b1;
            end
            else if (state == 4'd3 && opcode == START_DNN) begin
                state       <= 4'd4;
                start_DNN   <= 1'b1;
                enable_PC   <= '0;
            end
            else if (state == 4'd4) begin
                state       <= 4'd5;
                start_DNN   <= '0;
            end
            else if (state == 4'd5 && dnn_done == 1) begin
                state       <= 4'd1;
                start_DNN   <= '0;
                enable_PC   <= 1'b1;
            end
            else if (state == 4'd6) begin
                state       <= 4'd1;
                end_flag    <= '0;
            end
        end
    end

endmodule