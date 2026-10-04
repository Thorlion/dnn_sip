param([string]$ModelSimBin = 'D:\Quartus\modelsim_ase\win32aloem')
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$taskRun=Join-Path $taskRoot 'tmp/controller_posedge'
New-Item -ItemType Directory -Path $taskRun -Force | Out-Null
Push-Location $taskRun
try {
    if(!(Test-Path -LiteralPath work)) { & "$ModelSimBin/vlib.exe" work }
    $taskRTL=Join-Path $taskRoot 'source/hardware/rtl'
    $taskFiles=Get-Content -LiteralPath "$taskRTL/asip_files.f" |
        Where-Object {$_ -match '^(shared|controller)/'} |
        ForEach-Object {Join-Path $taskRTL $_}
    & "$ModelSimBin/vlog.exe" -sv -work work -l compile.log @taskFiles `
        "$PSScriptRoot/controller_posedge_tb.sv" "$PSScriptRoot/controller_modes_posedge_tb.sv" `
        "$PSScriptRoot/mem_ctrl_posedge_tb.sv"
    if($LASTEXITCODE -ne 0){throw 'Controller test compilation failed'}
    foreach($taskTB in @('controller_posedge_tb','controller_modes_posedge_tb','mem_ctrl_posedge_tb')) {
        & "$ModelSimBin/vsim.exe" -c -lib work $taskTB -l "$taskTB.log" `
            -wlf "$taskTB.wlf" -do 'run -all; quit -f' |
            Where-Object {$_ -match 'CONTROLLER_.*RESULT|MEM_CTRL_RESULT|TEST_|\*\* (Error|Fatal)'}
        if($LASTEXITCODE -ne 0 -or
           !(Select-String -LiteralPath "$taskTB.log" -SimpleMatch TEST_PASS) -or
           (Select-String -LiteralPath "$taskTB.log" -Pattern '\*\* (Error|Fatal)')) {
            throw "Controller verification failed; inspect tmp/controller_posedge/$taskTB.log"
        }
    }
} finally {Pop-Location}
