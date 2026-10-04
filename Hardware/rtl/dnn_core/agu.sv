module AGU #(
    parameter SCRATCHPAD_W = 512
)(
    input  logic clk,
    input  logic rst,
    input  logic run_en,
    input  logic sit_en,
    input  logic sbp_en,
    input  logic sof_en,
    input  logic [8:0] offset,
    input  logic [8:0] PC,

    input  logic new_base_addr,
    input  logic [$clog2(SCRATCHPAD_W)-1:0] IB_rd_base_addr,
    input  logic [$clog2(SCRATCHPAD_W)-1:0] KSP_rd_base_addr,
    input  logic [$clog2(SCRATCHPAD_W)-1:0] OSP_wr_base_addr,
    input  logic [$clog2(SCRATCHPAD_W)-1:0] OSP_rd_base_addr,    
    input  logic [$clog2(SCRATCHPAD_W)-1:0] OB_wr_base_addr,
    input  logic [$clog2(SCRATCHPAD_W)-1:0] OB_rd_base_addr,
    input  logic [$clog2(SCRATCHPAD_W)-1:0] BSP_rd_base_addr,
    input  logic [$clog2(SCRATCHPAD_W)-1:0] FCSP_wr_base_addr,
    input  logic [$clog2(SCRATCHPAD_W)-1:0] FCSP_rd_base_addr,

    output logic [$clog2(SCRATCHPAD_W)-1:0] IB_rd_base_addr_out,
    output logic [$clog2(SCRATCHPAD_W)-1:0] KSP_rd_base_addr_out,
    output logic [$clog2(SCRATCHPAD_W)-1:0] OSP_wr_base_addr_out,
    output logic [$clog2(SCRATCHPAD_W)-1:0] OSP_rd_base_addr_out,
    output logic [$clog2(SCRATCHPAD_W)-1:0] OB_wr_base_addr_out,
    output logic [$clog2(SCRATCHPAD_W)-1:0] OB_rd_base_addr_out,
    output logic [$clog2(SCRATCHPAD_W)-1:0] BSP_rd_base_addr_out,
    output logic [$clog2(SCRATCHPAD_W)-1:0] FCSP_wr_base_addr_out,
    output logic [$clog2(SCRATCHPAD_W)-1:0] FCSP_rd_base_addr_out,

    output logic select_next_PC,        // 1: select next PC, 0: select current PC
    output logic [8:0] PC_start,        // Start address of loop command, assign to PC when select next enable
    output logic n_active               // 1: AGU is not active, 0: AGU is active
);
    //Internal logic registers

    // Latch registers
    logic [$clog2(SCRATCHPAD_W)-1:0] IB_rd_reg;
    logic [$clog2(SCRATCHPAD_W)-1:0] KSP_rd_reg; 
    logic [$clog2(SCRATCHPAD_W)-1:0] OSP_wr_reg;
    logic [$clog2(SCRATCHPAD_W)-1:0] OSP_rd_reg;
    logic [$clog2(SCRATCHPAD_W)-1:0] OB_wr_reg;
    logic [$clog2(SCRATCHPAD_W)-1:0] OB_rd_reg;
    logic [$clog2(SCRATCHPAD_W)-1:0] BSP_rd_reg;
    logic [$clog2(SCRATCHPAD_W)-1:0] FCSP_wr_reg;
    logic [$clog2(SCRATCHPAD_W)-1:0] FCSP_rd_reg;

    // 
    logic [8:0]                 flag;               // Masked flag from offset, each bit for each base address register
    logic [8:0]                 iteration;          // Loop number remaining
    logic [8:0]                 pc_loop;            // Loop end address
    logic [8:0]                 pc_start;           // Loop start address
    
    logic                       not_equal;            // Result of compare interation & 0 to check remaining loop
    logic [8:0]                 select;         // Result of flag&not_equal

    logic [7:0]                 add_buf;
    logic reach_bp;
    // Result registers of adder
    logic [$clog2(SCRATCHPAD_W)-1:0] IB_new_rd_addr;
    logic [$clog2(SCRATCHPAD_W)-1:0] KSP_new_rd_addr;
    logic [$clog2(SCRATCHPAD_W)-1:0] OSP_new_wr_addr;
    logic [$clog2(SCRATCHPAD_W)-1:0] OSP_new_rd_addr;
    logic [$clog2(SCRATCHPAD_W)-1:0] OB_new_wr_addr;
    logic [$clog2(SCRATCHPAD_W)-1:0] OB_new_rd_addr;
    logic [$clog2(SCRATCHPAD_W)-1:0] BSP_new_rd_addr;
    logic [$clog2(SCRATCHPAD_W)-1:0] FCSP_new_wr_addr;
    logic [$clog2(SCRATCHPAD_W)-1:0] FCSP_new_rd_addr;

    // Update outputs
    assign IB_rd_base_addr_out      = IB_rd_reg;
    assign KSP_rd_base_addr_out     = KSP_rd_reg;
    assign OSP_wr_base_addr_out     = OSP_wr_reg;
    assign OSP_rd_base_addr_out     = OSP_rd_reg;
    assign OB_wr_base_addr_out      = OB_wr_reg;
    assign OB_rd_base_addr_out      = OB_rd_reg;
    assign BSP_rd_base_addr_out     = BSP_rd_reg;
    assign FCSP_wr_base_addr_out    = FCSP_wr_reg;
    assign FCSP_rd_base_addr_out    = FCSP_rd_reg;

    assign not_equal = (iteration != '0) ? 1'b1 : 1'b0;

    assign reach_bp = (pc_loop - 1  == PC && iteration != 0) ? 1 : 0;

    // Controler flag
    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            flag        <= '0;
            pc_loop     <= '0;
            iteration   <= '0;
            pc_start    <= '0;

            add_buf     <= '0;
            n_active    <= '0;
        end 
        
        else if (iteration == 0 && (PC == pc_loop)) begin
            add_buf <= 0;
        end
        
        // set flag
        else if (sof_en) begin
            flag     <= offset; 
            n_active <= 1;
        end
        // turn off flag when finish counting
        else if(run_en && not_equal == 0) begin
            flag     <= 0; //reset after finishing loop
            n_active <= 1;
        end
        // set pc loop
        else if(sbp_en) begin
            pc_start    <= PC + 3;
            pc_loop     <= PC + 3 + offset; 
            n_active    <= 1;
        end
        // set iteration
        else if(sit_en) begin
            iteration   <= offset; 
            n_active    <= 1;
        end
        // run counter
        else if(run_en) begin
            if(pc_loop - 2 == PC) begin
                n_active <= 1;
            end 
             else begin            
                n_active <= 0;
                if(iteration > 0 && reach_bp) begin
                    iteration   <= iteration - 1; 
                    add_buf     <= add_buf + 1;
                end
                else if (iteration == '0) begin
                end 
            end
        end
        else begin
            n_active <= 0;
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            select_next_PC <= 1'b1;
        end
        else begin
            // Both clocked processes see the pre-edge iteration value.
            // At 1, this is the final pass: decrement to zero without jumping.
            if(reach_bp == 0 || iteration <= 1) begin
                select_next_PC <= '0;
            end
            else begin
                select_next_PC <= 1'b1;
            end
        end
    end
    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            IB_rd_reg   <= '0;
            KSP_rd_reg  <= '0;
            OSP_wr_reg  <= '0;
            OSP_rd_reg  <= '0;
            OB_wr_reg   <= '0;
            OB_rd_reg   <= '0;
            BSP_rd_reg  <= '0;
            FCSP_wr_reg <= '0;
            FCSP_rd_reg <= '0;
        end else begin
            IB_rd_reg   <= IB_new_rd_addr;
            KSP_rd_reg  <= KSP_new_rd_addr;
            OSP_wr_reg  <= OSP_new_wr_addr;
            OSP_rd_reg  <= OSP_new_rd_addr;
            OB_wr_reg   <= OB_new_wr_addr;
            OB_rd_reg   <= OB_new_rd_addr;
            BSP_rd_reg  <= BSP_new_rd_addr;
            FCSP_wr_reg <= FCSP_new_wr_addr;
            FCSP_rd_reg <= FCSP_new_rd_addr;
        end 
    end
    
    assign PC_start = pc_start;

    assign select = flag & {9{not_equal}};

    agu_adder #(
        .SCRATCHPAD_W(SCRATCHPAD_W)
    ) aIB (
        .cur_addr(IB_rd_reg),
        .new_addr(IB_rd_base_addr),
        .select_addr(new_base_addr),
        .select_offset(select[0]),
        
        .add_buf(add_buf),
        .addr_out(IB_new_rd_addr)
    );

    agu_adder #(
        .SCRATCHPAD_W(SCRATCHPAD_W)
    ) aKSP (
        .cur_addr(KSP_rd_reg),
        .new_addr(KSP_rd_base_addr),
        .select_addr(new_base_addr),
        .select_offset(select[1]),
        
        .add_buf(add_buf),
        .addr_out(KSP_new_rd_addr)
    );

    agu_adder #(
        .SCRATCHPAD_W(SCRATCHPAD_W)
    ) aOSPwr (
        .cur_addr(OSP_wr_reg),
        .new_addr(OSP_wr_base_addr),
        .select_addr(new_base_addr),
        .select_offset(select[2]),
        
        .add_buf(add_buf),
        .addr_out(OSP_new_wr_addr)
    );

    agu_adder #(
        .SCRATCHPAD_W(SCRATCHPAD_W)
    ) aOSPrd (
        .cur_addr(OSP_rd_reg),
        .new_addr(OSP_rd_base_addr),
        .select_addr(new_base_addr),
        .select_offset(select[3]),
        
        .add_buf(add_buf),    
        .addr_out(OSP_new_rd_addr)
    );

    agu_adder #(
        .SCRATCHPAD_W(SCRATCHPAD_W)
    ) aOBwr (
        .cur_addr(OB_wr_reg),
        .new_addr(OB_wr_base_addr),
        .select_addr(new_base_addr),
        .select_offset(select[4]),
        
        .add_buf(add_buf),
        .addr_out(OB_new_wr_addr)
    );

    agu_adder #(
        .SCRATCHPAD_W(SCRATCHPAD_W)
    ) aOBrd (
        .cur_addr(OB_rd_reg),
        .new_addr(OB_rd_base_addr),
        .select_addr(new_base_addr),
        .select_offset(select[5]),
        
        .add_buf(add_buf),
        .addr_out(OB_new_rd_addr)
    );

    agu_adder #(
        .SCRATCHPAD_W(SCRATCHPAD_W)
    ) aBSP (
        .cur_addr(BSP_rd_reg),
        .new_addr(BSP_rd_base_addr),
        .select_addr(new_base_addr),
        .select_offset(select[6]),
        
        .add_buf(add_buf),
        .addr_out(BSP_new_rd_addr)
    );

    agu_adder #(
        .SCRATCHPAD_W(SCRATCHPAD_W)
    ) aFCSPwr (
        .cur_addr(FCSP_wr_reg),
        .new_addr(FCSP_wr_base_addr),
        .select_addr(new_base_addr),
        .select_offset(select[7]),
        
        .add_buf(add_buf),
        .addr_out(FCSP_new_wr_addr)
    );

    agu_adder #(
        .SCRATCHPAD_W(SCRATCHPAD_W)
    ) aFCSPrd (
        .cur_addr(FCSP_rd_reg),
        .new_addr(FCSP_rd_base_addr),
        .select_addr(new_base_addr),    
        .select_offset(select[8]),
        
        .add_buf(add_buf),
        .addr_out(FCSP_new_rd_addr)
    );


endmodule
