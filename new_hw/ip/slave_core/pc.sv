// Instruction-indexed program counter with active-low asynchronous reset.
// Hold RESET_PC until i_start is sampled high on a rising clock edge.
// Each start pulse loads i_start_pc and enables operation until halt/reset.
// Priority is start/restart > halt > branch load > increment > hold.
// A load is allowed while i_en is low; qualify i_load with branch validity.
// Arithmetic wraps modulo 2**PC_W.
module slave_pc #(
    parameter int unsigned PC_W = 9,
    parameter logic [PC_W-1:0] RESET_PC = '0,
    parameter logic [PC_W-1:0] PC_STEP = PC_W'(1)
)(
    input  logic                i_start,
    input  logic                i_halt,
    input  logic [PC_W-1:0]     i_start_pc,
    input  logic                i_clk,
    input  logic                i_rst_n,
    input  logic                i_en,
    input  logic                i_load,
    input  logic [PC_W-1:0]     i_load_pc,
    output logic [PC_W-1:0]     o_pc,
    output logic                o_running
);
    logic r_running;

    assign o_running = r_running;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n)
            r_running <= 1'b0;
        else if (i_start)
            r_running <= 1'b1;
        else if (i_halt)
            r_running <= 1'b0;
    end

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n)
            o_pc <= RESET_PC;
        else if (i_start)
            o_pc <= i_start_pc;
        else if (r_running && !i_halt) begin
            if (i_load)
                o_pc <= i_load_pc;
            else if (i_en)
                o_pc <= o_pc + PC_STEP;
        end
    end
endmodule
