# Master and DMA integration test

`master_dma_top.sv` instantiates `dsip_master`, `dma_write_top` as DMA0, and
`dma_read_top` as DMA1. It is the integration DUT for this testbench. Payload
memories connect to its ports and remain outside its synthesis boundary.

```text
                    master DMA_CONFIG instructions
                        | data / offset
                        | wen_dma0 / wen_dma1
                        v
OM async read ------> DMA0 ------> IB clocked write
OM clocked write <--- DMA1 <------ OB synchronous read
```

The two DMA instances share CSR data and offset signals, with separate write
enables selected by `funct3`: 0 selects DMA0, 1 selects DMA1, and 2 through 7
select neither DMA. The CSR byte offsets are:

| Offset | Meaning |
| --- | --- |
| `0x00` | Source word address |
| `0x04` | Destination word address |
| `0x08` | Number of words |
| `0x0C` | Control: write bit 0 as one to start |

The default payload width is 16 bits. Payload addresses increment by one per
word; the CSR offsets above are byte offsets. OM has independent read and write
ports, without arbitration or wait states. Its read data is combinational and
its writes are accepted on rising clock edges. IB writes are accepted on rising
edges. OB read data updates after a rising edge and holds while disabled.

## Testbench

`master_dma_tb.sv` connects an asynchronous-read OM array with 256 words, a
64-word IB, and a separate 64-word OB. Both local memories instantiate
`common/mem.sv`. The bench initializes IB and OB through their write ports while
holding the DUT in reset, then releases reset and runs the master program.
OB begins with a deterministic pattern representing computed output data.

`master_dma_program.mem` contains actual 32-bit instructions loaded by the
master's instruction memory. Its `DMA_CONFIG` opcode is the requested `0x78`.
Configuration data is placed in x5 by ADDI instructions; adjacent ADDI/CSR
instructions exercise EX forwarding. The bench also checks the complete
sequence of valid CSR writes, including their data, offset and selected DMA.

The program performs these transfers:

| Phase | DMA0: OM to IB | DMA1: OB to OM |
| --- | --- | --- |
| 0 | OM 16 to IB 4, 8 words | OB 8 to OM 128, 8 words |
| 1 | OM 32 to IB 20, 1 word | OB 24 to OM 160, 1 word |
| 2 | OM 255 to IB 63, 0 words | OB 63 to OM 255, 0 words |

It also issues source and START writes with every invalid `funct3` value.
These must not reach either DMA. Starts for the two valid DMAs are consecutive
instructions, allowing the two engines to operate concurrently on separate
local memories and separate OM regions.

Checks cover full-width address bounds, address order, data, exact read/write
counts, one-clock done pulses, completion on the final write, and zero-length
completion without memory accesses. The final comparison covers all OM and IB
locations, including locations that should remain unchanged. A watchdog fails
the test if either engine does not complete. Each DMA should complete three
transfers and copy nine words in total.

The program uses fixed NOP spacing between phases and ends in a self-loop.
This is test-program scheduling; it does not add DMA status polling or hardware
stalling to the master. Keep the program and the bench's phase expectations in
agreement when changing this example.

## Running with Verilator and GTKWave

From the `source` directory:

```powershell
python new_hw/script/run.py test=master_dma
python new_hw/script/run.py test=master_dma --wave
```

From `new_hw/script`, use `python run.py test=master_dma` with the same options.
Source files and the default output directory are resolved from the script's
location, independently of the current working directory.

For the shorter `run test=master_dma` spelling while working in `source`,
define this PowerShell function:

```powershell
function run { python ./new_hw/script/run.py @args }
run test=master_dma
run test=master_dma --wave
```

Both commands compile and run the testbench and save `compile.log`,
`simulation.log`, and `master_dma_result.log` in
`DSIP/tmp/verilator/master_dma/`. A nonzero exit status or a missing testbench
pass marker is reported as failure. Build warnings remain visible in the
compile log; compiler errors and failed testbench checks fail the run.

`--wave` also generates `master_dma.vcd` and launches GTKWave. A partial VCD
is opened after a failing simulation when available. GTKWave diagnostics go to
`gtkwave.log`. Without `--wave`, tracing is not compiled into the simulator and
GTKWave is not launched. The two modes use separate build directories. Wave
tracing includes the small payload arrays and omits the master's large RAMs.

The runner uses native tools on Linux/WSL. From Windows Python it automatically
delegates to WSL when Verilator is not on the Windows PATH. To choose Ubuntu
explicitly:

```powershell
python new_hw/script/run.py test=master_dma --wave --backend wsl --wsl-distro Ubuntu
```

Use `--backend native` to require native tools, `--jobs 2` to set the C++ build
parallelism, and `--output-dir <path>` to choose another output directory.
`--verilator <executable>` and `--gtkwave <executable>` select tools in the
chosen backend. GTKWave is only required with `--wave`. A WSL GTKWave GUI needs
a working graphical session, such as WSLg.

Dependencies are Python 3.9+, Verilator with `--binary`/`--timing` support,
GNU Make, and a C++ compiler with coroutine support. The runner uses Verilator's
[timed binary build](https://verilator.org/guide/latest/exe_verilator.html#cmdoption-binary)
and [VCD tracing](https://verilator.org/guide/latest/faq.html#how-do-i-generate-waveforms-traces-in-c),
then opens the trace with [GTKWave](https://gtkwave.github.io/gtkwave/man/gtkwave.1.html).

## Running with ModelSim

From the `source` directory, when compilation and simulation are approved:

```powershell
./new_hw/tb/dma/run_master_dma.ps1
```

The script follows the existing test scripts' ModelSim setup. Its default tools
directory is `D:/Quartus/modelsim_ase/win32aloem`; override it with
`-ModelSimBin <path>`. `-OutputDir <path>` overrides the output directory.
The script compiles only the master/DMA dependencies, copies the program image
into the run directory, and launches `master_dma_tb`.

Default artifacts are in `DSIP/tmp/new_hw_master_dma/`: `compile.log`,
`simulation.log`, `simulation.wlf`, and `master_dma_result.log`. A passing run
writes `MASTER_DMA_TB_PASS` to the result log. The script rejects a run that
does not produce that marker.

For direct simulator use, compile `riscv_pkg.sv` before its consumers and make
`master_dma_program.mem` available in the simulator's working directory.
The integration DUT's `IMEM_INIT_FILE` parameter is forwarded to `dsip_master`.
