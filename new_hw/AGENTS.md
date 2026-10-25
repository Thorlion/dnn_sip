# Project Instructions

## 1. Project Overview

This project implements a master-slave architecture for DNN acceleration, refer to the paper "DSIP: A Scalable Inference Accelerator for Convolutional Neural Networks" with slight changes.

The design targets two platforms, in order of priority:
1. **ASIC:** Cadence synthesis flow targeting a 45nm standard-cell technology.
2. **FPGA:** AMD Xilinx Kria KV260.

Prioritize functional correctness, cycle-accurate behavior, and ASIC synthesis compatibility before performance optimization.

## 2. Architecture

The accelerator architecture includes:
- 64 processing elements (DALUs).
- INT16 fixed-point arithmetic.
- Ping-pong input (IB) and output (OB) buffers.
- Kernel scratchpad (KSP) and output scratchpad (OSP).
- A programmable controller and instruction-based execution.

### Architecture Rules
- Preserve the existing architecture unless explicitly instructed otherwise.
- Follow existing dataflow, scheduling, and instruction specifications.
- Do not introduce additional hardware components without permission.
- Do not change the number of processing elements without approval.
- Preserve existing memory organization and data dependencies.
- Maintain cycle-accurate behavior across modules.

## Scope and Module Responsibilities

- Implement only the behavior requested in the current task.
- Preserve existing user edits and unfinished modules outside that scope.
- An unfinished dependency does not authorize implementing it.
- Do not invent configuration fields, ports, address maps, scheduling,
  handshakes, or fallback controls to complete an integration.
- When essential architectural behavior is unspecified, ask a focused
  question before implementing that behavior.
- Requests for suggestions or reviews do not authorize file changes.

## 3. RTL Coding Rules

- Use synthesizable SystemVerilog.
- Prefer `always_ff` for sequential logic and `always_comb` for combinational logic.
- Use nonblocking assignments (`<=`) for sequential logic.
- Use blocking assignments (`=`) for combinational logic.
- Avoid inferred latches and unintended combinational loops.
- Prefer parameterized modules when appropriate.
- Follow existing naming conventions and module structure.
- Prefix input signals with `i_`, for example `i_clk`.
- Prefix output signals with `o_`, for example `o_out`.
- Prefix internal signals, including wires and registers, with `w_`, for example `w_data`.
- Use explicit signal widths and signedness.
- Avoid unnecessary registers, intermediate signals, and logic duplication.
- Do not change module interfaces without approval.
- Do not modify unrelated modules.

### Timing and Reset
- Respect existing clock and reset conventions.
- Avoid introducing unnecessary clock domains.
- Do not create internally gated clocks without an approved implementation.
- Preserve existing pipeline stages and their latency unless instructed otherwise.
- Avoid long combinational paths where practical.

## 4. Arithmetic and Datapath

- Preserve the specified fixed-point representation.
- Explicitly handle signed arithmetic.
- Maintain correct intermediate multiplication and accumulation widths.
- Follow the documented overflow, truncation, rounding, and saturation behavior.
- Do not change numerical precision without approval.
- Prefer resource-efficient implementations when they preserve exact behavior.

## 5. Memory and Buffer Management

- Preserve ping-pong buffer operation.
- Follow the documented memory address mapping and read/write protocols.
- Account for synchronous memory read latency.
- Avoid unintended read/write conflicts.
- Do not assume unsupported memory-port capabilities.
- Keep technology-specific memory implementations behind wrappers where appropriate.

### ASIC and FPGA Compatibility
- Prioritize ASIC-compatible memory interfaces.
- Use SRAM macros or black-box models when specified.
- Do not replace memories with large register arrays without evaluating the impact.
- Avoid FPGA-specific primitives in shared RTL unless explicitly required.
- Keep ASIC and FPGA implementation differences isolated where possible.

## 6. Control and Scheduling

- Follow the existing instruction format and execution sequence.
- Preserve controller-to-core handshake behavior.
- Maintain correct buffer ownership and transfer ordering.
- Do not introduce additional pipeline stalls or execution cycles without permission.
- Ensure that scheduling changes preserve functional correctness.
- Treat existing scheduling documentation as the source of truth.

## 7. Verification

Always ask the user before compiling or performing verification, and wait for explicit approval. An RTL modification request alone does not authorize compilation or verification. This includes syntax and elaboration checks, linting, simulation, synthesis, and timing analysis.

The following activities apply only when verification is authorized:

- Create self-checking SystemVerilog testbenches.
- Test reset behavior and boundary conditions.
- Verify arithmetic correctness against a reference model.
- Test valid and invalid control sequences where applicable.
- Verify memory read/write behavior and buffer switching.
- Test handshakes, stalls, and instruction completion.
- Check cycle counts when timing behavior is specified.
- Add assertions where useful without unnecessarily complicating the design.
- Run relevant simulations after RTL modifications only with the user's approval.

### Verification Rules
- Do not modify expected results merely to make tests pass.
- Investigate mismatches between RTL and reference models.
- Distinguish between functional errors, timing errors, and testbench issues.
- Report unverified behavior explicitly.

## 8. Synthesis and Optimization

### Priority 1: ASIC
- Target the configured Cadence 45nm synthesis environment.
- Optimize for timing, area, and power without sacrificing correctness.
- Prefer structures that map efficiently to standard cells.
- Follow the existing constraints and synthesis configuration.
- Do not assume that inferred memories map automatically to SRAM macros.

### Priority 2: FPGA
- Maintain compatibility with AMD Xilinx KV260.
- Allow FPGA-specific optimizations only when they do not compromise ASIC requirements or when explicitly requested.

### Optimization Rules
- Do not perform architectural optimizations without approval.
- Avoid unnecessary logic duplication.
- Do not add pipeline stages without permission.
- Explain area, timing, and power tradeoffs when proposing optimizations.
- Distinguish measured synthesis results from estimates.

## 9. Development Workflow

Before modifying code:
1. Read the relevant RTL modules and documentation.
2. Understand the existing architecture and module interfaces.
3. Identify dependencies and potential side effects.
4. Prefer the smallest change that satisfies the request.

After modifying code:
1. Ask whether the user wants compilation or verification, unless already explicitly requested or approved for the current task.
2. Wait for approval before running any compilation or verification; run only the agreed checks.
3. Review the changes for unintended behavior.
4. Summarize what was changed.
5. Report test results and any remaining limitations.

Do not invent commands or tool configurations. Inspect existing scripts, Makefiles, and project documentation before running tools.

## 10. Agent Behavior and Restrictions

- **Follow the user's instructions exactly.**
- **Do not add excessive features without permission.**
- Prefer simple solutions over unnecessarily complex implementations.
- Do not refactor unrelated code.
- Do not rewrite working modules unless explicitly requested.
- Do not change external interfaces without approval.
- Do not change instruction encodings or memory maps without approval.
- Do not silently change cycle counts or pipeline latency.
- Do not remove existing verification coverage.
- Do not introduce new dependencies unless necessary.
- Do not assume unspecified architectural behavior.

When requirements are ambiguous:
- Inspect the existing implementation and documentation first.
- State assumptions clearly.
- Ask for clarification before making significant architectural changes.

When completing a task:
- Describe modifications briefly.
- List affected files.
- Report tests performed and their results.
- Identify unresolved issues.
- Suggest optional improvements separately; do not implement them without permission.
