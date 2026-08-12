param(
    [string]$GodotBin = $env:GODOT_BIN,
    [switch]$Quick
)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($GodotBin)) { $GodotBin = 'C:\Users\AdminLFG\AppData\Local\Programs\Godot\Godot_v4.7-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $GodotBin)) { throw "Godot binary not found: $GodotBin" }

$scriptRoot = Split-Path -Parent $PSCommandPath
$workspace = (Resolve-Path (Join-Path $scriptRoot '..')).Path
Set-Location -LiteralPath $workspace

function Invoke-GodotChecked([string[]]$GodotArgs, [bool]$ExpectSuccess = $true) {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $output = @(& $GodotBin --headless --path . @GodotArgs 2>&1) }
    finally { $ErrorActionPreference = $previousPreference }
    $output | ForEach-Object { Write-Host $_ }
    $actual = $LASTEXITCODE
    if ($ExpectSuccess -and $actual -ne 0) { throw "Godot command failed ($actual): $($GodotArgs -join ' ')" }
    if ((-not $ExpectSuccess) -and $actual -eq 0) { throw "Godot command unexpectedly succeeded: $($GodotArgs -join ' ')" }
    if ($ExpectSuccess) {
        $engineErrors = @($output | Where-Object { "$_" -match '(^|\s)(SCRIPT ERROR:|Parse Error:|ERROR:)' })
        if ($engineErrors.Count -gt 0) { throw "Godot printed engine errors: $($engineErrors -join ' | ')" }
    }
}

Write-Host '1/11 clean-snapshot import, test and resource parse gate'
& powershell -ExecutionPolicy Bypass -File (Join-Path $scriptRoot 'cold_import_selftest.ps1') -GodotBin $GodotBin
if ($LASTEXITCODE -ne 0) { throw 'Cold snapshot import gate failed.' }
Write-Host '2/11 cache-free test suite (run this first in a clean snapshot)'
Invoke-GodotChecked @('--script', 'res://tests/test_runner.gd')
Write-Host '3/11 core autoload parse gate'
Invoke-GodotChecked @('--script', 'res://tools/check_autoload_parse.gd')
& powershell -ExecutionPolicy Bypass -File tools\autoload_parse_selftest.ps1 -GodotBin $GodotBin
if ($LASTEXITCODE -ne 0) { throw 'Autoload parse self-test failed.' }
Write-Host '4/11 headless project launch and scene smoke'
Invoke-GodotChecked @('--', '--scene-smoke')
Write-Host '5/11 runner deliberate-failure self-test'
& powershell -ExecutionPolicy Bypass -File tools\test_runner_selftest.ps1 -GodotBin $GodotBin
if ($LASTEXITCODE -ne 0) { throw 'Test runner self-test failed.' }
Write-Host '6/11 localization keys'
Invoke-GodotChecked @('--script', 'res://tools/check_localization.gd')
Write-Host '7/11 M1 performance gate self-test'
& powershell -ExecutionPolicy Bypass -File tools\benchmark_selftest.ps1 -GodotBin $GodotBin
if ($LASTEXITCODE -ne 0) { throw 'Benchmark gate self-test failed.' }
Write-Host '8/11 M1 performance gate'
$benchmarkArgs = @('--script', 'res://tools/benchmark_m1.gd')
if ($Quick) { $benchmarkArgs += @('--', '--quick') }
Invoke-GodotChecked -GodotArgs $benchmarkArgs
Write-Host '9/11 M1 endurance memory gate'
& powershell -ExecutionPolicy Bypass -File tools\endurance_selftest.ps1 -GodotBin $GodotBin
if ($LASTEXITCODE -ne 0) { throw 'Endurance gate self-test failed.' }
$enduranceArgs = @('--script', 'res://tools/terrain_endurance.gd')
if ($Quick) { $enduranceArgs += @('--', '--quick') }
Invoke-GodotChecked -GodotArgs $enduranceArgs
Write-Host '10/11 M2 control endurance'
$m2Args = @('--script', 'res://tools/m2_endurance.gd')
if ($Quick) { $m2Args += @('--', '--quick') }
Invoke-GodotChecked -GodotArgs $m2Args
Write-Host '11/13 M3 production dive endurance'
Invoke-GodotChecked @('--script', 'res://tools/m3_endurance.gd')
Write-Host '12/13 M3 deterministic seed gate'
if ($Quick) {
    & powershell -ExecutionPolicy Bypass -File tools\m3_seed_validation.ps1 -GodotBin $GodotBin -Quick
} else {
    & powershell -ExecutionPolicy Bypass -File tools\m3_seed_validation.ps1 -GodotBin $GodotBin
}
if ($LASTEXITCODE -ne 0) { throw 'M3 deterministic seed gate failed.' }
Write-Host '13/14 M3 cross-process and cold-snapshot hash gate'
& powershell -ExecutionPolicy Bypass -File tools\m3_cross_process_gate.ps1 -GodotBin $GodotBin
if ($LASTEXITCODE -ne 0) { throw 'M3 cross-process hash gate failed.' }
Write-Host '14/14 M2 human acceptance gate'
& powershell -ExecutionPolicy Bypass -File tools\m2_acceptance_gate.ps1
if ($LASTEXITCODE -ne 0) { throw 'M2 human acceptance gate failed.' }
Write-Host 'Verification passed.'
