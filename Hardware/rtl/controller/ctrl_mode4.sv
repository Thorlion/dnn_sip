module Mode_ctrller_4 #(
    //parameter ID = 0,
    parameter IS_FIRST_ROW = 1'b1,      // = 1 là ASIP đầu tiên của 1 hàng
    parameter IS_FIRST_COL = 1'b1       // = 1 là ASIP đầu tiên của 1 cột
)(
    input wire [5:0] opcode,   
    input wire clk,
    input wire rst,    
    input wire start,                       // tin hieu bat dau DSIP
    input wire vsync_in,                    // tin hieu dong bo chieu doc tu cac DSIP subsequence
    input wire hsync_in,                    // = AND all hsync_out signal
     
    input wire DNN_done,
    output reg vsync_out,
    output reg hsync_out,
    output reg start_DNN_core,                  // tin hieu dau ra de bat dau kich hoat cho DNN core hoat dong
    output reg enable_PC,                    // tin hieu cho phep PC tiep tuc    - neu bang 0 thi ngung PC
    output reg end_flag,                    // tin hieu bao rang ket thuc lenh

    input wire done_transfer_prev,
    output reg done_transfer,
    
    input wire done_vtransfer_prev,
    output reg done_vtransfer
); 

    localparam SDC          = 6'b010101;
    localparam VSYNC        = 6'b010110;
    localparam END_F          = 6'b010111;
    localparam HSYNC        = 6'b011000;
    
    localparam IDLE = 0,
               WAIT_VSYNC = 1,
               WAIT_VSYNC_IN = 2,
               WAIT_TO_V_TRANSFER = 3,
               V_TRANSFER = 4,
               WAIT_VSYNC_END_IN = 5,
               START_CORE = 6,
               WAIT_CORE_DONE = 7,
               WAIT_HSYNC = 8,
               WAIT_HSYNC_IN = 9,
               WAIT_TO_TRANSFER = 10,
               TRANSFER = 11,
               WAIT_HSYNC_END_IN = 12,
               STATE_END = 13;
                
    reg [3:0] state;
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            state <= IDLE;
            done_transfer <= 0;
            done_vtransfer <= 0;
            enable_PC <= 1;
            vsync_out <= 0;
            hsync_out <= 0;
            end_flag <= 0;
        end
        else begin
            case (state)
                IDLE: begin
                    done_transfer <= 0;
                    done_vtransfer <= 0;
                    if(start)  begin
                        state <= WAIT_VSYNC;
                    end
                    
                    enable_PC <= 1;
                    vsync_out <= 0;
                    hsync_out = 0;
                    end_flag <= 0;
                    
                end
                
                // Tạo tín hiệu đồng bộ dọc (vẫn sử dụng nhưng hiện tại chưa có nhiều tác dụng)
                WAIT_VSYNC: begin
                    end_flag = 0;
                    if(opcode == VSYNC) begin
                        vsync_out = 1;
                        state <= WAIT_VSYNC_IN;
                        enable_PC <= 0;
                    end

                end
                
                // Chờ tín hiệu đồng bộ dọc (vẫn sử dụng nhưng hiện tại chưa có nhiều tác dụng)
                WAIT_VSYNC_IN: begin
                    if(vsync_in) begin
                        vsync_out = 0;
                        state <= WAIT_TO_V_TRANSFER;
                        enable_PC <= 0;
                    end
                end
                
                WAIT_TO_V_TRANSFER: begin
                    if(IS_FIRST_COL || done_vtransfer_prev) begin
                            state <= V_TRANSFER;
                            enable_PC <= 1;
                    end
                end
                
                V_TRANSFER: begin
                    if(opcode == VSYNC) begin
                        vsync_out <= 1;
                        done_vtransfer <= 1;
                        enable_PC = 0;
                        state <= WAIT_VSYNC_END_IN;
                    end     
                
                end
                
                WAIT_VSYNC_END_IN: begin
                     if(vsync_in) begin
                        done_vtransfer <= 0;
                        vsync_out <= 0;
                        enable_PC <= 1;
                        state <= START_CORE;
                    end
                end                
                
                START_CORE: begin
                    // neu khong can cho DNN core hoat động nữa thì nhảy sang HSYNC -> chuyển data sang các OM khác
                    if (opcode == HSYNC) begin
                        // chỉ có DSIP đầu cột mới cần xử lý tiếp HSYNC
//                        if(IS_FIRST_COL) begin
                            hsync_out = 1;
                            state <= WAIT_HSYNC_IN;
                            enable_PC = 0;
//                        end
                        // nếu k phải DSIP đầu cột -> nhảy tới WAIT_HSYNC_END_IN và đợi hsync_in, không cần tạo hsync_out
//                        else begin
//                            enable_PC = 0;
//                            state <= TRANSFER;
//                        end
                    end
                    
                    // nếu vẫn còn tính toán thì sử dụng lệnh SDC để chạy DNN core tiếp
                    else if(opcode == SDC) begin
                        enable_PC <= 0;
                        start_DNN_core <= 1;
                        state <= WAIT_CORE_DONE;
                    end
                end
                
                // Chờ cho DNN xử lý xong
                WAIT_CORE_DONE: begin
                    if(DNN_done) begin
                        enable_PC = 1;
                        state <= WAIT_HSYNC;
                    end
                    else start_DNN_core <= 0;
                end
                
                // State này dùng để báo cho các ASIP khác rằng mình đã sẵn sàng cho quá trình Transferring data
                WAIT_HSYNC: begin
                    // Nếu không muốn cho DNN chạy nữa thì tới giai đoạn truyền data sang OM mới
                    if(opcode == HSYNC) begin
                        hsync_out = 1;
                        state <= WAIT_HSYNC_IN;
                        enable_PC = 0;
                    end
                    
                    // Nếu DNN vẫn cần xử lý tiếp thì quay về stage WAIT_VSYNC
                    else begin
                        state <= WAIT_VSYNC;
                    end
                end
                
                // Được sử dụng để đảm bảo rằng toàn bộ ASIP đã sẵn sàng cho quá trình Transferring data
                WAIT_HSYNC_IN: begin
                    if(hsync_in) begin
                        hsync_out = 0;
                        state <= WAIT_TO_TRANSFER;
                        enable_PC = 0;
                    end                    
                end
                
                // Kiểm tra điều kiện để bắt đầu truyền dữ liệu
                WAIT_TO_TRANSFER: begin
                    // DSIP0x           //DSIPx0                DSIPxy (xy != 0)
                    if(IS_FIRST_ROW || done_transfer_prev || (!IS_FIRST_ROW & !IS_FIRST_COL)) begin
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
                        enable_PC = 0;
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