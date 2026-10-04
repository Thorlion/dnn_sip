module Mode_ctrller_3 #(
    //parameter ID <= 0,
    parameter IS_FIRST_ROW = 1,      // <= 1 là ASIP đầu tiên của 1 hàng
    parameter IS_FIRST_COL = 1       // <= 1 là ASIP đầu tiên của 1 cột
)(
    input logic [5:0]    opcode,   
    input logic          clk,
    input logic          rst,    
    input logic          start,                       // tin hieu bat dau DSIP
    input logic          vsync_in,                    // tin hieu dong bo chieu doc tu cac DSIP subsequence
    input logic          hsync_in,                    // <= AND all hsync_out signal
     
    input  logic DNN_done,
    output logic vsync_out,
    output logic hsync_out,
    output logic start_DNN_core,                  // tin hieu dau ra de bat dau kich hoat cho DNN core hoat dong
    output logic enable_PC,                    // tin hieu cho phep PC tiep tuc    - neu bang 0 thi ngung PC
    output logic end_flag,                    // tin hieu bao rang ket thuc lenh

    input  logic done_transfer_prev,
    output logic done_transfer
); 

    localparam SDC          = 6'b010101;
    localparam VSYNC        = 6'b010110;
    localparam END_F        = 6'b010111;
    localparam HSYNC        = 6'b011000;
    
    localparam IDLE             = 0,
               WAIT_VSYNC       = 1,
               WAIT_VSYNC_IN    = 2,
               START_CORE       = 3,
               WAIT_CORE_DONE   = 4,
               WAIT_HSYNC       = 5,
               WAIT_HSYNC_IN    = 6,
               WAIT_TO_TRANSFER = 7,
               TRANSFER         = 8,
               WAIT_HSYNC_END_IN= 9,
               STATE_END        = 10;
                
    logic [3:0] state;
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            state           <= IDLE;
            done_transfer   <= 0;
            enable_PC       <= 1;
            vsync_out       <= 0;
            hsync_out       <= 0;
            end_flag        <= 0;
            start_DNN_core  <= 0;
        end
        else begin
            case (state)
                IDLE: begin
                    done_transfer   <= 0;
                    if(start) state <= WAIT_VSYNC;
                    enable_PC       <= 1;
                    vsync_out       <= 0;
                    hsync_out       <= 0;
                    end_flag        <= 0;
                end
                
                // Tạo tín hiệu đồng bộ dọc (vẫn sử dụng nhưng hiện tại chưa có nhiều tác dụng)
                WAIT_VSYNC: begin
                    end_flag <= 0;
                    if(opcode == VSYNC) begin
                        vsync_out   <= 1;
                        state       <= WAIT_VSYNC_IN;
                        enable_PC   <= 0;
                    end
                    /* Sau khi SDC lần cuối thì MC vẫn phải hđộng để lưu dữ liệu từ OB vào OM, sau đó mới gọi HSYNC
                        Vẫn có thể gọi HSYNC trước xong rồi gộp phần lưu dữ liệu 256/256 và Transfer vào làm 1 và bỏ phần dưới
                        Nhưng nếu như vậy thì có nên lưu luôn từ OB vào OM2 không ? 
                        Ở đây tui dùng vế đầu để gần hơn với suy nghĩ của tui*/
                    else if(opcode == HSYNC) begin
                        hsync_out   <= 1;
                        state       <= WAIT_HSYNC_IN;
                        enable_PC   <= 0;
                    end
                end
                
                // Chờ tín hiệu đồng bộ dọc (vẫn sử dụng nhưng hiện tại chưa có nhiều tác dụng)
                WAIT_VSYNC_IN: begin
                    if(vsync_in) begin
                        vsync_out   <= 0;
                        state       <= START_CORE;
                        enable_PC   <= 1;
                    end
                end
                
                // tạo tín hiệu cho DNN hoạt động
                START_CORE: begin
                    if(opcode == SDC) begin
                        enable_PC <= 0;
                        start_DNN_core <= 1;
                        state <= WAIT_CORE_DONE;
                    end
                end
                
                // Chờ cho DNN xử lý xong
                WAIT_CORE_DONE: begin
                    start_DNN_core <= 0;
                    // Ignore sticky completion while the core samples start.
                    if(!start_DNN_core && DNN_done) begin
                        enable_PC <= 1;
                        state <= WAIT_HSYNC;
                    end
                end
                
                // State này dùng để báo cho các ASIP khác rằng mình đã sẵn sàng cho quá trình Transferring data
                WAIT_HSYNC: begin
                    // Nếu không muốn cho DNN chạy nữa thì tới giai đoạn truyền data sang OM mới
                    if(opcode == HSYNC) begin
                        hsync_out <= 1;
                        state <= WAIT_HSYNC_IN;
                        enable_PC <= 0;
                    end
                    
                    // Nếu DNN vẫn cần xử lý tiếp thì quay về stage WAIT_VSYNC
                    else begin
                        state <= WAIT_VSYNC;
                    end
                end
                
                // Được sử dụng để đảm bảo rằng toàn bộ ASIP đã sẵn sàng cho quá trình Transferring data
                WAIT_HSYNC_IN: begin
                    if(hsync_in) begin
                        hsync_out <= 0;
                        state <= WAIT_TO_TRANSFER;
                        enable_PC <= 0;
                    end                    
                end
                
                // Kiểm tra điều kiện để bắt đầu truyền dữ liệu
                WAIT_TO_TRANSFER: begin
                    if(IS_FIRST_ROW || done_transfer_prev) begin
                        state <= TRANSFER;
                        enable_PC <= 1;
                    end
                end
                //stage transferring data
                TRANSFER: begin
                    // Nếu truyền xong data thì đồng bộ ngang cho các ASIP khác hoạt động
                    if(opcode == HSYNC) begin
                        hsync_out <= 1;
                        done_transfer <= 1;
                        enable_PC <= 0;
                        state <= WAIT_HSYNC_END_IN;
                    end                 
                end
                
                
                // Khi toàn bộ ASIP ngang hoàn thành quá trình truyền dữ liệu
                // thì quay về IDLE 
                WAIT_HSYNC_END_IN: begin
                    if(hsync_in) begin
                        done_transfer <= 0;
                        hsync_out <= 0;
                        enable_PC <= 1;
                        state <= STATE_END;
                    end
                end
                // quay về
                STATE_END: begin
                    if(opcode == END_F) begin
                        state <= WAIT_VSYNC;
                        end_flag <= 1;
                        enable_PC <= 1;
                    end
                end
            endcase
        end
    end
    
endmodule
