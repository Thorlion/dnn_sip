# New hardware primitives

Signal prefixes: `i_` for inputs, `o_` for outputs, and `w_` for internal signals.

## Single-port memory: `common/mem.sv`

The module is named `mem_1rw` to avoid colliding with the legacy `mem` module.
It has one shared address port and performs at most one operation per rising
clock edge:

| `i_en` | `i_we` | Operation | `o_rdata` |
| --- | --- | --- | --- |
| 0 | X | No access | Holds its previous value |
| 1 | 0 | Read `i_addr` | Updates after this edge |
| 1 | 1 | Write `i_wdata` to `i_addr` | Holds its previous value |

Parameters:

- `DATA_W`: bits per word, default 16.
- `ADDR_W`: address width, default 9.
- `DEPTH`: number of words, default `2**ADDR_W`. Override it for non-power-of-two
  memories; addresses must remain in `0..DEPTH-1`.
- `RAM_STYLE`: FPGA inference hint, default `"block"`. This is not an ASIC SRAM
  macro implementation or a guarantee of FPGA primitive mapping.

There is no memory reset, power-up initialization, or second read port.
Storage and the read output are unknown until written/read appropriately.
Writes do not return the new or old word: they leave `o_rdata` unchanged.
The coding pattern follows the synchronous
[single-port no-change RAM template](https://docs.amd.com/r/en-US/ug901-vivado-synthesis/Single-Port-Block-RAM-No-Change-Mode-Verilog).

## Program counter: `ip/pc.sv`

Module `pc` has parameterized `PC_W`, `RESET_PC`, and `PC_STEP`. Reset is
asynchronous and active low. Update priority is:

1. `i_rst_n = 0`: set `o_pc` to `RESET_PC`.
2. `i_load`: set `o_pc` to `i_load_pc`, even if `i_en` is low.
3. `i_en`: add `PC_STEP`.
4. Otherwise hold.

The PC counts word addresses and wraps modulo `2**PC_W`. A non-power-of-two
instruction-memory depth needs explicit program-range control. Qualify `i_load`
with branch/instruction validity in the surrounding controller.

Example matching PC and instruction-memory widths:

```systemverilog
localparam int PC_W = 9;
localparam int INSTR_W = 212;

pc #(.PC_W(PC_W)) program_counter (
    .i_clk(i_clk), .i_rst_n(i_rst_n), .i_en(w_pc_en), .i_load(w_branch_valid),
    .i_load_pc(w_branch_target), .o_pc(w_pc_addr)
);

mem_1rw #(.DATA_W(INSTR_W), .ADDR_W(PC_W)) instruction_memory (
    .i_clk(i_clk), .i_en(w_imem_en), .i_we(w_programming),
    .i_addr(w_programming ? w_programming_addr : w_pc_addr),
    .i_wdata(w_programming_data), .o_rdata(w_instruction)
);
```

The controller must account for synchronous reads: at a rising edge, memory
samples the pre-edge address. Loading a branch target into the PC on that edge
does not make the target instruction available on the same edge. During
programming, stall the PC unless intentional execution is supported elsewhere.

## Verification

Run from the repository root:

```powershell
./new_hw/tb/run_pc_mem.ps1
```

The vendor-IP-free ModelSim testbench checks 16-bit memories of 512 and 1024
words, 212-bit instruction words, non-power-of-two depth, a one-word/one-bit
memory, PC widths 1/9/12/32, nonzero reset, a custom step, wraparound, load
priority, disabled accesses, synchronous reads, and no-change writes. Logs and
the simulation library are placed in the workspace's `tmp/new_hw_pc_mem/`.
ModelSim 10.1d passed all nine configurations, totaling 21,318 checks.
These tests do not establish full-core behavior, timing closure, or RAM mapping.
