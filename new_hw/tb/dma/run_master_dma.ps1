param(
    [string]$ModelSimBin = 'D:/Quartus/modelsim_ase/win32aloem',
    [string]$OutputDir = ''
)

$ErrorActionPreference = 'Stop'
$w_new_hw = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$w_program_file = Join-Path $PSScriptRoot 'master_dma_program.mem'
if (-not $OutputDir) {
    $w_workspace = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
    $OutputDir = Join-Path $w_workspace 'tmp/new_hw_master_dma'
}
foreach ($w_tool in @('vlib.exe', 'vlog.exe', 'vsim.exe')) {
    if (-not (Test-Path -LiteralPath (Join-Path $ModelSimBin $w_tool))) {
        throw "Missing ModelSim executable: $w_tool in $ModelSimBin"
    }
}

# The package must precede all modules importing riscv_pkg.
$w_sources = @(
    'ip/master_core/riscv_pkg.sv'
    'common/reg.sv'
    'common/mem.sv'
    'ip/master_core/reg_file.sv'
    'ip/master_core/imm_gen.sv'
    'ip/master_core/control_unit.sv'
    'ip/master_core/pipeline_reg.sv'
    'ip/master_core/forwarding_unit.sv'
    'ip/master_core/hazard_unit.sv'
    'ip/master_core/alu.sv'
    'ip/master_core/if_stage.sv'
    'ip/master_core/id_stage.sv'
    'ip/master_core/ex_stage.sv'
    'ip/master_core/mem_stage.sv'
    'ip/master_core/wb_stage.sv'
    'ip/master_core/pipelined_cpu.sv'
    'ip/master_core/instruction_memory.sv'
    'ip/master_core/data_memory.sv'
    'ip/dma/dma_csr.sv'
    'top/dsip_master.sv'
    'top/dma_write_top.sv'
    'top/dma_read_top.sv'
    'tb/dma/master_dma_top.sv'
    'tb/dma/master_dma_tb.sv'
) | ForEach-Object { Join-Path $w_new_hw $_ }

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
$w_output_dir = (Resolve-Path -LiteralPath $OutputDir).Path
$w_output_program = Join-Path $w_output_dir 'master_dma_program.mem'
if ($w_program_file -ne $w_output_program) {
    Copy-Item -LiteralPath $w_program_file -Destination $w_output_program -Force
}

Push-Location -LiteralPath $w_output_dir
try {
    if (-not (Test-Path -LiteralPath 'work')) {
        & (Join-Path $ModelSimBin 'vlib.exe') work
        if ($LASTEXITCODE -ne 0) { throw 'ModelSim library creation failed.' }
    }
    & (Join-Path $ModelSimBin 'vlog.exe') -sv -work work -l compile.log @w_sources
    if ($LASTEXITCODE -ne 0) { throw 'Master/DMA compilation failed; see compile.log.' }

    # A stale pass marker cannot make a failed simulation appear successful.
    Set-Content -LiteralPath 'master_dma_result.log' -Value 'MASTER_DMA_TB_PENDING' -Encoding ascii
    & (Join-Path $ModelSimBin 'vsim.exe') -c -lib work master_dma_tb `
        -l simulation.log -wlf simulation.wlf `
        -do 'onerror {quit -code 1}; log -r /*; run -all; quit -f'
    if ($LASTEXITCODE -ne 0) { throw 'Master/DMA simulation failed; see simulation.log.' }
    if (-not (Select-String -LiteralPath 'master_dma_result.log' -Pattern '^MASTER_DMA_TB_PASS$' -Quiet)) {
        throw 'Master/DMA testbench did not pass; see simulation.log and master_dma_result.log.'
    }
    Write-Output "Master/DMA result log: $(Join-Path $w_output_dir 'master_dma_result.log')"
} finally {
    Pop-Location
}
