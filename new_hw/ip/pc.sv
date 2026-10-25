// Word-addressed program counter with active-low asynchronous reset.
// Hold RESET_PC until i_start is sampled high on a rising clock edge.
// One start pulse enables operation until reset; later pulses do not restart it.
// On the start edge and while running, priority is load > increment > hold.
// A load is allowed while i_en is low; qualify i_load with branch validity.
// Arithmetic wraps modulo 2**PC_W.
module pc #(
    parameter int unsigned PC_W = 9,
    parameter logic [PC_W-1:0] RESET_PC = '0,
    parameter logic [PC_W-1:0] PC_STEP = 1'b1
)(
    input  logic                i_start,
    input  logic                i_clk,
    input  logic                i_rst_n,
    input  logic                i_en,
    input  logic                i_load,
    input  logic [PC_W-1:0]     i_load_pc,
    output logic [PC_W-1:0]     o_pc
);
    logic w_running;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n)
            w_running <= 1'b0;
        else if (i_start)
            w_running <= 1'b1;
    end

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n)
            o_pc <= RESET_PC;
        else if (w_running || i_start) begin
            if (i_load)
                o_pc <= i_load_pc;
            else if (i_en)
                o_pc <= o_pc + PC_STEP;
        end
    end
endmodule
