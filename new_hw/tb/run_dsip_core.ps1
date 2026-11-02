param(
    [string]$ModelSimBin = 'D:/Quartus/modelsim_ase/win32aloem',
    [string]$ImemFile = '',
    [int]$RunCycles = 64,
    [string]$OutputDir = ''
)

$ErrorActionPreference = 'Stop'
if ($RunCycles -lt 1) {
    throw 'RunCycles must be positive.'
}
$w_new_hw = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $ImemFile) {
    $ImemFile = Join-Path $PSScriptRoot 'core_imem_instr.txt'
}
$w_imem_file = (Resolve-Path -LiteralPath $ImemFile).Path
if (-not $OutputDir) {
    $w_workspace = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $OutputDir = Join-Path $w_workspace 'tmp/new_hw_core'
}
foreach ($w_tool in @('vlib.exe', 'vlog.exe', 'vsim.exe')) {
    if (-not (Test-Path -LiteralPath (Join-Path $ModelSimBin $w_tool))) {
        throw "Missing ModelSim executable: $w_tool in $ModelSimBin"
    }
}

$w_sources = @(
    'common/reg.sv'
    'common/mem.sv'
    'ip/pc.sv'
    'ip/agu.sv'
    'ip/imem.sv'
    'ip/dec_if.sv'
    'ip/dec_ex.sv'
    'ip/dec_ms.sv'
    'ip/dalu.sv'
    'pipeline_reg/reg_if_ml.sv'
    'pipeline_reg/reg_ml_exe.sv'
    'pipeline_reg/reg_exe_nl.sv'
    'top/dsip_core.sv'
) | ForEach-Object { Join-Path $w_new_hw $_ }
$w_sources += Join-Path $PSScriptRoot 'dsip_core_tb.sv'

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
Push-Location -LiteralPath $OutputDir
try {
    if (-not (Test-Path -LiteralPath 'work')) {
        & (Join-Path $ModelSimBin 'vlib.exe') work
        if ($LASTEXITCODE -ne 0) { throw 'ModelSim library creation failed.' }
    }
    & (Join-Path $ModelSimBin 'vlog.exe') -sv -work work -l compile.log @w_sources
    if ($LASTEXITCODE -ne 0) { throw 'Core compilation failed; see compile.log.' }

    & (Join-Path $ModelSimBin 'vsim.exe') -c -lib work dsip_core_tb `
        "+IMEM_FILE=$w_imem_file" "+RUN_CYCLES=$RunCycles" `
        -l simulation.log -wlf simulation.wlf `
        -do 'onerror {quit -code 1}; log -r /*; run -all; quit -f'
    if ($LASTEXITCODE -ne 0) { throw 'Core simulation failed; see simulation.log.' }
    if (-not (Test-Path -LiteralPath 'core_output.log') -or
        -not (Select-String -LiteralPath 'core_output.log' -Pattern '^DSIP_CORE_TB_COMPLETE' -Quiet)) {
        throw 'Core testbench did not complete; see simulation.log.'
    }
    Write-Output "Core output log: $(Join-Path (Get-Location).Path 'core_output.log')"
} finally {
    Pop-Location
}
