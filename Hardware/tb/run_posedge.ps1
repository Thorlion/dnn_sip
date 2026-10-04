param(
    [string]$ModelSimBin = 'D:\Quartus\modelsim_ase\win32aloem',
    [ValidateSet('posedge_flow_tb','relu_activation_tb')]
    [string]$Testbench = 'posedge_flow_tb'
)
$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$taskRunDir = Join-Path $taskRoot 'tmp/posedge_flow'
New-Item -ItemType Directory -Path $taskRunDir -Force | Out-Null
Push-Location $taskRunDir
try {
    if (!(Test-Path -LiteralPath work)) {
        & "$ModelSimBin\vlib.exe" work
        if ($LASTEXITCODE -ne 0) { throw 'Could not create simulation library' }
    }
    $taskIP = Join-Path $taskRoot 'fpga/dsip.gen/sources_1/ip'
    & "$ModelSimBin\vlog.exe" -work work -l ip_compile.log `
        "$taskIP/BRAM_1/simulation/blk_mem_gen_v8_4.v" `
        "$taskIP/MEMSC_1/simulation/dist_mem_gen_v8_0.v" `
        "$taskIP/BRAM_1/sim/BRAM.v" "$taskIP/MEMSC_1/sim/MEMSC.v" "$taskIP/MEMOB_1/sim/MEMOB.v"
    if ($LASTEXITCODE -ne 0) { throw 'Memory IP compilation failed; regenerate project IP first' }
    $taskRTL = Join-Path $taskRoot 'source/hardware/rtl'
    $taskLog = if ($Testbench -eq 'posedge_flow_tb') { 'posedge_flow' } else { 'relu_activation' }
    $taskFiles = Get-Content -LiteralPath "$taskRTL/dnn_core_files.f" |
        ForEach-Object { Join-Path $taskRTL $_ }
    & "$ModelSimBin\vlog.exe" -sv -work work -l rtl_compile.log `
        @taskFiles "$PSScriptRoot/$Testbench.sv"
    if ($LASTEXITCODE -ne 0) { throw 'RTL compilation failed' }
    & "$ModelSimBin\vsim.exe" -c -lib work $Testbench -l "$taskLog.log" `
        -wlf "$taskLog.wlf" -do 'run -all; quit -f' |
        Where-Object { $_ -match '^# POSEDGE_FLOW|^# RELU_|^# TEST_|\*\* (Error|Fatal)' }
    if ($LASTEXITCODE -ne 0 -or
        !(Select-String -LiteralPath "$taskLog.log" -SimpleMatch TEST_PASS) -or
        (Select-String -LiteralPath "$taskLog.log" -Pattern '\*\* (Error|Fatal)')) {
        throw "Verification failed; inspect tmp/posedge_flow/$taskLog.log"
    }
} finally { Pop-Location }
