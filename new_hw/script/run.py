#!/usr/bin/env python3
"""Run DSIP SystemVerilog testbenches with Verilator and optional GTKWave.

From the source directory:

    python new_hw/script/run.py test=master_dma
    python new_hw/script/run.py test=master_dma --wave
    python new_hw/script/run.py test=single_system --wave

Windows Python automatically uses WSL when Verilator is not on the Windows
PATH. Run this file inside WSL/Linux to use its tools directly.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys


# The script lives in source/new_hw/script; resolve inputs independently of cwd.
NEW_HW = Path(__file__).resolve().parents[1]
SOURCE_ROOT = NEW_HW.parent


@dataclass(frozen=True)
class TestSpec:
    top: str
    sources: tuple[str, ...]
    assets: tuple[str, ...]
    result_log: str
    pass_marker: str
    waveform: str
    result_label: str = "PASS"
    layer_id: int | None = None


TESTS = {
    "master_dma": TestSpec(
        top="master_dma_tb",
        # Package first; FPGA board wrappers are intentionally excluded.
        sources=(
            "ip/master_core/riscv_pkg.sv",
            "common/reg.sv",
            "common/mem.sv",
            "ip/master_core/reg_file.sv",
            "ip/master_core/imm_gen.sv",
            "ip/master_core/control_unit.sv",
            "ip/master_core/pipeline_reg.sv",
            "ip/master_core/forwarding_unit.sv",
            "ip/master_core/hazard_unit.sv",
            "ip/master_core/alu.sv",
            "ip/master_core/if_stage.sv",
            "ip/master_core/id_stage.sv",
            "ip/master_core/ex_stage.sv",
            "ip/master_core/mem_stage.sv",
            "ip/master_core/wb_stage.sv",
            "ip/master_core/pipelined_cpu.sv",
            "ip/master_core/instruction_memory.sv",
            "ip/master_core/data_memory.sv",
            "ip/dma/dma_csr.sv",
            "top/dsip_master.sv",
            "top/dma_write_top.sv",
            "top/dma_read_top.sv",
            "tb/dma/master_dma_top.sv",
            "tb/dma/master_dma_tb.sv",
        ),
        assets=("tb/dma/master_dma_program.mem",),
        result_log="master_dma_result.log",
        pass_marker="MASTER_DMA_TB_PASS",
        waveform="master_dma.vcd",
    ),
    "conv1_full": TestSpec(
        top="single_conv_tb",
        layer_id=1,
        sources=(
            "ip/master_core/riscv_pkg.sv",
            "common/reg.sv",
            "common/mem.sv",
            "ip/master_core/reg_file.sv",
            "ip/master_core/imm_gen.sv",
            "ip/master_core/control_unit.sv",
            "ip/master_core/pipeline_reg.sv",
            "ip/master_core/forwarding_unit.sv",
            "ip/master_core/hazard_unit.sv",
            "ip/master_core/alu.sv",
            "ip/master_core/if_stage.sv",
            "ip/master_core/id_stage.sv",
            "ip/master_core/ex_stage.sv",
            "ip/master_core/mem_stage.sv",
            "ip/master_core/wb_stage.sv",
            "ip/master_core/pipelined_cpu.sv",
            "ip/master_core/instruction_memory.sv",
            "ip/master_core/data_memory.sv",
            "ip/slave_core/agu.sv",
            "ip/slave_core/pc.sv",
            "ip/slave_core/imem.sv",
            "ip/slave_core/dec_if.sv",
            "ip/slave_core/dec_ex.sv",
            "ip/slave_core/dec_ms.sv",
            "ip/slave_core/dalu.sv",
            "ip/slave_core/pipeline_reg/reg_if_ml.sv",
            "ip/slave_core/pipeline_reg/reg_ml_exe.sv",
            "ip/slave_core/pipeline_reg/reg_exe_nl.sv",
            "ip/dma/dma_csr.sv",
            "ip/dma/dma_write_decoder.sv",
            "ip/dma/dma_read_decoder.sv",
            "top/dsip_master.sv",
            "top/dsip_slave.sv",
            "top/dma_write_top.sv",
            "top/dma_read_top.sv",
            "tb/single_system/tb/single_system_top.sv",
            "tb/single_system/tb/single_system_tb.sv",
            "tb/single_system/tb/single_conv_tb.sv",
        ),
        assets=(
            "tb/single_system/master_mem/conv1_master_imem.mem",
            "tb/single_system/slave_mem/conv1_slave_imem.mem",
            "tb/single_system/om_mem/Conv1/input_img.mem",
            "tb/single_system/om_mem/Conv1/conv1_weight.mem",
        ),
        result_log="single_system_result.log",
        pass_marker="CONV1_FULL_TB_PASS",
        waveform="single_system.vcd",
    ),
}

TESTS["single_system"] = TESTS["conv1_full"]

TESTS["agu_loop"] = TestSpec(
    top="agu_loop_tb",
    sources=("ip/slave_core/dec_if.sv", "ip/slave_core/agu.sv", "tb/ip/agu_loop_tb.sv"),
    assets=(),
    result_log="agu_loop_result.log",
    pass_marker="AGU_LOOP_TB_PASS",
    waveform="agu_loop.vcd",
)

TESTS["conv2_full"] = TestSpec(
    top="single_conv_tb",
    layer_id=2,
    sources=TESTS["conv1_full"].sources,
    assets=(
        "tb/single_system/master_mem/conv2_master_imem.mem",
        "tb/single_system/slave_mem/conv2_slave_imem.mem",
        "tb/single_system/om_mem/Conv2/conv2_input.mem",
        "tb/single_system/om_mem/Conv2/conv2_weight.mem",
    ),
    result_log="single_system_result.log",
    pass_marker="CONV2_FULL_TB_PASS",
    waveform="single_system.vcd",
)

TESTS["conv3_full"] = TestSpec(
    top="single_conv_tb",
    layer_id=3,
    sources=TESTS["conv1_full"].sources,
    assets=(
        "tb/single_system/master_mem/conv3_master_imem.mem",
        "tb/single_system/slave_mem/conv3_slave_imem.mem",
        "tb/single_system/om_mem/Conv3/conv3_input.mem",
        "tb/single_system/om_mem/Conv3/conv3_weight.mem",
    ),
    result_log="single_system_result.log",
    pass_marker="CONV3_FULL_TB_PASS",
    waveform="single_system.vcd",
)

TESTS["conv4_full"] = TestSpec(
    top="single_conv_tb",
    layer_id=4,
    sources=TESTS["conv1_full"].sources,
    assets=(
        "tb/single_system/master_mem/conv4_master_imem.mem",
        "tb/single_system/slave_mem/conv4_slave_imem.mem",
        "tb/single_system/om_mem/Conv4/conv4_input.mem",
        "tb/single_system/om_mem/Conv4/conv4_weight.mem",
    ),
    result_log="single_system_result.log",
    pass_marker="CONV4_FULL_TB_PASS",
    waveform="single_system.vcd",
)

TESTS["conv5_full"] = TestSpec(
    top="single_conv_tb",
    layer_id=5,
    sources=TESTS["conv1_full"].sources,
    assets=(
        "tb/single_system/master_mem/conv5_master_imem.mem",
        "tb/single_system/slave_mem/conv5_slave_imem.mem",
        "tb/single_system/om_mem/Conv5/conv5_input.mem",
        "tb/single_system/om_mem/Conv5/conv5_weight.mem",
    ),
    result_log="single_system_result.log",
    pass_marker="CONV5_FULL_TB_PASS",
    waveform="single_system.vcd",
)


def test_name(value: str) -> str:
    key, separator, name = value.partition("=")
    if key != "test" or not separator or name not in TESTS:
        choices = ", ".join(f"test={name}" for name in TESTS)
        raise argparse.ArgumentTypeError(f"Select a supported test: {choices}")
    return name


def positive_int(value: str) -> int:
    number = int(value)
    if number < 1:
        raise argparse.ArgumentTypeError("Must be a positive integer")
    return number


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("test", type=test_name, metavar="test=NAME")
    parser.add_argument("--wave", action="store_true",
                        help="Generate a VCD and open it in GTKWave")
    parser.add_argument("--backend", choices=("auto", "native", "wsl"), default="auto",
                        help="Default: native tools, or WSL from Windows if Verilator is absent")
    parser.add_argument("--wsl-distro", help="Optional WSL distribution, such as Ubuntu")
    parser.add_argument("--verilator", default="verilator", help="Verilator executable or path")
    parser.add_argument("--gtkwave", default="gtkwave", help="GTKWave executable or path")
    parser.add_argument("--jobs", type=positive_int, default=min(4, os.cpu_count() or 1),
                        help="Parallel C++ build jobs (default: up to 4)")
    parser.add_argument("--output-dir", type=Path,
                        help="Default: DSIP/tmp/verilator/<test>")
    return parser.parse_args()


def executable(name: str) -> str:
    found = shutil.which(name)
    if found is None:
        raise RuntimeError(f"Executable not found: {name}. Install it or supply its full path.")
    # Keep tool paths valid when subprocesses change working directory.
    return str(Path(found).resolve())


def show_log_tail(path: Path) -> None:
    if path.exists():
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        print("\n".join(lines[-30:]), file=sys.stderr)


def run_logged(command: list[str], directory: Path, log: Path) -> int:
    display_command = (subprocess.list2cmdline(command) if os.name == "nt"
                       else shlex.join(command))
    with log.open("w", encoding="utf-8") as stream:
        stream.write(f"$ {display_command}\n\n")
        stream.flush()
        return subprocess.run(command, cwd=directory, stdin=subprocess.DEVNULL,
                              stdout=stream, stderr=subprocess.STDOUT).returncode


def wsl_run(args: argparse.Namespace) -> int:
    if os.name != "nt":
        raise RuntimeError("Use --backend native when Python is already running inside WSL/Linux.")
    prefix = [executable("wsl.exe")]
    if args.wsl_distro:
        prefix.extend(["--distribution", args.wsl_distro])
    prefix.append("--exec")

    def linux_path(path: Path) -> str:
        result = subprocess.run(prefix + ["wslpath", "-u", str(path.resolve())],
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        # WSL diagnostics can use UTF-16LE, while wslpath output is UTF-8.
        encoding = "utf-16-le" if b"\x00" in result.stdout else "utf-8"
        output = result.stdout.decode(encoding, errors="replace").strip()
        if result.returncode or not output:
            raise RuntimeError(f"WSL path conversion failed:\n{output}")
        return output

    command = prefix + ["python3", linux_path(Path(__file__)), f"test={args.test}",
                        "--backend", "native", "--jobs", str(args.jobs),
                        "--verilator", args.verilator, "--gtkwave", args.gtkwave]
    if args.wave:
        command.append("--wave")
    if args.output_dir is not None:
        command.extend(["--output-dir", linux_path(args.output_dir.expanduser())])
    print("Using WSL" + (f" ({args.wsl_distro})" if args.wsl_distro else ""), flush=True)
    return subprocess.run(command).returncode


def open_wave(viewer: str, waveform: Path, directory: Path) -> None:
    log = directory / "gtkwave.log"
    with log.open("w", encoding="utf-8") as stream:
        process = subprocess.Popen([viewer, str(waveform)], cwd=directory,
                                   stdin=subprocess.DEVNULL, stdout=stream,
                                   stderr=subprocess.STDOUT,
                                   start_new_session=(os.name != "nt"))
    # A display/setup error should be reported instead of silently losing the GUI.
    try:
        status = process.wait(timeout=1)
    except subprocess.TimeoutExpired:
        status = 0  # The GUI is running; leave it open without blocking the runner.
    if status:
        show_log_tail(log)
        raise RuntimeError(f"GTKWave exited with status {status}; see {log}")
    print(f"GTKWave: {waveform}", flush=True)


def native_run(args: argparse.Namespace) -> int:
    spec = TESTS[args.test]
    verilator = executable(args.verilator)
    viewer = executable(args.gtkwave) if args.wave else None
    output = (args.output_dir.expanduser() if args.output_dir is not None else
              SOURCE_ROOT.parent / "tmp" / "verilator" / args.test).resolve()
    sources = [NEW_HW / source for source in spec.sources]
    assets = [NEW_HW / asset for asset in spec.assets]
    for path in sources + assets:
        if not path.is_file():
            raise RuntimeError(f"Missing test source or input file: {path}")
    output.mkdir(parents=True, exist_ok=True)
    for asset in assets:
        destination = output / asset.name
        if asset.resolve() != destination.resolve():
            shutil.copyfile(asset, destination)

    # Separate build directories keep traced and untraced binaries distinct.
    build = output / ("obj_wave" if args.wave else "obj_log")
    binary_name = "simulate.exe" if os.name == "nt" else "simulate"
    binary = build / binary_name
    compile_log = output / "compile.log"
    simulation_log = output / "simulation.log"
    result_log = output / spec.result_log
    waveform = output / spec.waveform
    result_log.write_text("TEST_PENDING\n", encoding="utf-8")
    if args.wave and waveform.exists():
        waveform.unlink()  # Never open an old trace after a failed build/run.

    command = [verilator, "--binary", "--timing", "--top-module", spec.top,
               "--Mdir", str(build), "-o", binary_name, "--build-jobs", str(args.jobs),
               "--timescale", "1ns/1ps", "-Wno-fatal"]
    if spec.layer_id is not None:
        command.append(f"-GLAYER_ID={spec.layer_id}")
    if args.wave:
        # --trace is the VCD spelling supported by the installed Verilator 5.020.
        # Include the small payload memories, excluding the master's large RAMs.
        command.extend(["--trace", "--trace-max-array", "256", "-DENABLE_WAVES"])
    command.extend(str(path) for path in sources)

    print(f"[{args.test}] Building; log: {compile_log}", flush=True)
    if run_logged(command, output, compile_log):
        show_log_tail(compile_log)
        raise RuntimeError(f"Verilator build failed; see {compile_log}")
    if not binary.is_file():
        raise RuntimeError(f"Build did not produce the simulator: {binary}")

    print(f"[{args.test}] Simulating; log: {simulation_log}", flush=True)
    status = run_logged([str(binary)], output, simulation_log)
    passed = (status == 0 and result_log.is_file() and
              spec.pass_marker in result_log.read_text(encoding="utf-8", errors="replace").splitlines())
    if passed:
        print(f"[{args.test}] {spec.result_label}; results: {result_log}", flush=True)
    else:
        show_log_tail(simulation_log)
        print(f"[{args.test}] FAIL; see {simulation_log} and {result_log}", file=sys.stderr)

    # Open a partial trace too, so a failed assertion can be debugged in GTKWave.
    if args.wave:
        if not waveform.is_file() or waveform.stat().st_size == 0:
            raise RuntimeError(f"Simulation did not produce a waveform: {waveform}")
        open_wave(viewer, waveform, output)
    return 0 if passed else 1


def main() -> int:
    args = arguments()
    use_wsl = (args.backend == "wsl" or
               (args.backend == "auto" and os.name == "nt" and
                (args.wsl_distro is not None or shutil.which(args.verilator) is None)))
    try:
        return wsl_run(args) if use_wsl else native_run(args)
    except (OSError, RuntimeError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("Interrupted", file=sys.stderr)
        return 130


if __name__ == "__main__":
    sys.exit(main())
