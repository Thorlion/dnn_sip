param(
    [string]$ModelSimBin = 'D:/Quartus/modelsim_ase/win32aloem',
    [int]$InputSize = 224,
    [int]$Stride = 4,
    [int]$WeightSize = 11,
    [string]$InputFile = '',
    [string]$OutputDir = ''
)

$ErrorActionPreference = 'Stop'
$w_new_hw = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $InputFile) {
    $InputFile = Join-Path $PSScriptRoot 'agu_input_indices.txt'
}
$w_input_file = (Resolve-Path -LiteralPath $InputFile).Path
if (-not $OutputDir) {
    $w_workspace = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $OutputDir = Join-Path $w_workspace 'tmp/new_hw_agu'
}
foreach ($w_tool in @('vlib.exe', 'vlog.exe', 'vsim.exe')) {
    if (-not (Test-Path -LiteralPath (Join-Path $ModelSimBin $w_tool))) {
        throw "Missing ModelSim executable: $w_tool in $ModelSimBin"
    }
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
Push-Location -LiteralPath $OutputDir
try {
    if (-not (Test-Path -LiteralPath 'work')) {
        & (Join-Path $ModelSimBin 'vlib.exe') work
        if ($LASTEXITCODE -ne 0) { throw 'ModelSim library creation failed.' }
    }
    & (Join-Path $ModelSimBin 'vlog.exe') -sv -work work -l compile.log `
        (Join-Path $w_new_hw 'ip/agu.sv') (Join-Path $PSScriptRoot 'agu_tb.sv')
    if ($LASTEXITCODE -ne 0) { throw 'AGU compilation failed; see compile.log.' }

    & (Join-Path $ModelSimBin 'vsim.exe') -c -lib work agu_tb `
        "+INPUT_SIZE=$InputSize" "+STRIDE=$Stride" "+WEIGHT_SIZE=$WeightSize" "+INPUT_FILE=$w_input_file" `
        -l simulation.log -wlf simulation.wlf `
        -do 'onerror {quit -code 1}; run -all; quit -f'
    if ($LASTEXITCODE -ne 0) { throw 'AGU simulation failed; see simulation.log.' }
    if (-not (Test-Path -LiteralPath 'agu_output.log') -or
        -not (Select-String -LiteralPath 'agu_output.log' -Pattern '^AGU_TRACE_COMPLETE$' -Quiet)) {
        throw 'AGU trace did not complete; see simulation.log.'
    }
    Write-Output "AGU output log: $(Join-Path (Get-Location).Path 'agu_output.log')"
} finally {
    Pop-Location
}
