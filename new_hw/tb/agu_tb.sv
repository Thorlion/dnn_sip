`timescale 1ns/1ps

// IB indices come from a text file; only the KSP address feeds back.
module agu_tb;
    localparam int ADDRESS_WIDTH = 10;
    localparam int REG_WIDTH = 16;
    localparam int MAX_ADDRESS = (2 ** (ADDRESS_WIDTH + 1)) - 1;

    logic [ADDRESS_WIDTH:0] w_ib_addr;
    logic [ADDRESS_WIDTH:0] w_ksp_addr;
    logic [ADDRESS_WIDTH:0] w_osp_addr;
    logic [ADDRESS_WIDTH:0] w_bsp_addr;
    logic [ADDRESS_WIDTH:0] w_input_size;
    logic [ADDRESS_WIDTH:0] w_stride;
    logic [ADDRESS_WIDTH:0] w_weight_size;
    wire  [ADDRESS_WIDTH:0] w_next_ib_addr;
    wire  [ADDRESS_WIDTH:0] w_next_ksp_addr;
    wire  [ADDRESS_WIDTH:0] w_next_osp_addr;
    wire  [ADDRESS_WIDTH:0] w_next_bsp_addr;

    integer w_log;
    integer w_input_file;
    integer w_size_arg;
    integer w_stride_arg;
    integer w_kernel_arg;
    integer w_unused;
    integer w_chars;
    integer w_fields;
    integer w_input_index;
    integer w_line_number;
    integer w_step;
    logic [4095:0] w_line;
    string w_input_path;
    string w_first_token;
    string w_extra_token;
    string w_weight_position;

    agu #(.ADDRESS_WIDTH(ADDRESS_WIDTH), .REG_WIDTH(REG_WIDTH)) u_agu (
        .i_ib_addr(w_ib_addr),
        .i_ksp_addr(w_ksp_addr),
        .i_osp_addr(w_osp_addr),
        .i_bsp_addr(w_bsp_addr),
        .i_input_size(w_input_size),
        .i_stride(w_stride),
        .i_weight_size(w_weight_size),
        .o_ib_addr(w_next_ib_addr),
        .o_ksp_addr(w_next_ksp_addr),
        .o_osp_addr(w_next_osp_addr),
        .o_bsp_addr(w_next_bsp_addr)
    );

    task log_text(input string i_text);
        $display("%s", i_text);
        $fdisplay(w_log, "%s", i_text);
    endtask

    initial begin
        w_size_arg = 224;
        w_stride_arg = 4;
        w_kernel_arg = 11;
        w_input_path = "agu_input_indices.txt";
        w_unused = $value$plusargs("INPUT_SIZE=%d", w_size_arg);
        w_unused = $value$plusargs("STRIDE=%d", w_stride_arg);
        w_unused = $value$plusargs("WEIGHT_SIZE=%d", w_kernel_arg);
        w_unused = $value$plusargs("INPUT_FILE=%s", w_input_path);
        if (w_kernel_arg < 1 || w_kernel_arg > MAX_ADDRESS)
            $fatal(1, "WEIGHT_SIZE must be in 1..%0d", MAX_ADDRESS);

        w_log = $fopen("agu_output.log", "w");
        if (!w_log)
            $fatal(1, "Cannot open agu_output.log");
        w_input_file = $fopen(w_input_path, "r");
        if (!w_input_file)
            $fatal(1, "Cannot open input file: %s", w_input_path);

        w_input_size = w_size_arg;
        w_stride = w_stride_arg;
        w_weight_size = w_kernel_arg;
        w_ib_addr = '0;
        w_ksp_addr = '0;
        w_osp_addr = '0;
        w_bsp_addr = '0;
        w_line_number = 0;
        w_step = 0;

        log_text("AGU feedback trace: manually supplied IB indices, KSP feedback starting at zero.");
        log_text($sformatf("Input file: %s", w_input_path));
        log_text($sformatf("input_size=%0d stride=%0d weight_size=%0d address_bits=%0d",
            w_input_size, w_stride, w_weight_size, ADDRESS_WIDTH + 1));
        log_text("Each data line is one step. KSP_CURRENT is paired with that line's IB_INDEX.");
        log_text("WEIGHT_ROW/COL assume row-major kernel storage: row=KSP/K, col=KSP%K.");
        log_text("This is a trace of the current RTL, not a convolution-correctness check.");
        log_text("STEP | FILE_LINE | IB_INDEX | KSP_CURRENT | WEIGHT_ROW,COL | KSP_NEXT");

        while (!$feof(w_input_file)) begin
            w_chars = $fgets(w_line, w_input_file);
            w_line_number = w_line_number + 1;
            if (w_chars > 0) begin
                w_fields = $sscanf(w_line, "%s", w_first_token);
                // Skip blank lines and comments beginning with '#'.
                if (w_fields == 1 && w_first_token[0] != 8'h23) begin
                    w_fields = $sscanf(w_line, "%d %s", w_input_index, w_extra_token);
                    if (w_fields < 1)
                        $fatal(1, "Line %0d: expected a decimal IB index", w_line_number);
                    if (w_fields == 2 && w_extra_token[0] != 8'h23)
                        $fatal(1, "Line %0d: use one decimal IB index per line", w_line_number);
                    if (w_input_index < 0 || w_input_index > MAX_ADDRESS)
                        $fatal(1, "Line %0d: IB index must be in 0..%0d",
                            w_line_number, MAX_ADDRESS);

                    w_ib_addr = w_input_index;
                    #1;
                    if (w_ksp_addr < w_kernel_arg * w_kernel_arg)
                        w_weight_position = $sformatf("%0d,%0d",
                            w_ksp_addr / w_kernel_arg, w_ksp_addr % w_kernel_arg);
                    else
                        w_weight_position = "OUTSIDE_KERNEL";

                    log_text($sformatf("%0d | %0d | %0d | %0d | %s | %0d",
                        w_step, w_line_number, w_ib_addr, w_ksp_addr,
                        w_weight_position, w_next_ksp_addr));

                    // Only KSP feeds back. The next IB index always comes from the file.
                    w_ksp_addr = w_next_ksp_addr;
                    w_step = w_step + 1;
                end
            end
        end

        if (w_step == 0)
            $fatal(1, "The input file has no IB indices");
        log_text($sformatf("Logged %0d feedback steps.", w_step));
        log_text("AGU_TRACE_COMPLETE");
        $fclose(w_input_file);
        $fclose(w_log);
        $finish;
    end
endmodule
