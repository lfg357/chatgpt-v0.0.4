param(
    [string]$GodotBin = $env:GODOT_BIN,
    [switch]$Quick
)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($GodotBin)) { $GodotBin = 'C:\Users\AdminLFG\AppData\Local\Programs\Godot\Godot_v4.7-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $GodotBin)) { throw "Godot binary not found: $GodotBin" }

function Invoke-GodotChecked([string[]]$GodotArgs, [bool]$ExpectSuccess = $true) {
    & $GodotBin --headless --path . @GodotArgs
    $actual = $LASTEXITCODE
    if ($ExpectSuccess -and $actual -ne 0) { throw "Godot command failed ($actual): $($GodotArgs -join ' ')" }
    if ((-not $ExpectSuccess) -and $actual -eq 0) { throw "Godot command unexpectedly succeeded: $($GodotArgs -join ' ')" }
}

Write-Host '1/8 cache-free test suite (run this first in a clean snapshot)'
Invoke-GodotChecked @('--script', 'res://tests/test_runner.gd')
Write-Host '2/8 core autoload parse gate'
Invoke-GodotChecked @('--script', 'res://tools/check_autoload_parse.gd')
& powershell -ExecutionPolicy Bypass -File tools\autoload_parse_selftest.ps1 -GodotBin $GodotBin
if ($LASTEXITCODE -ne 0) { throw 'Autoload parse self-test failed.' }
Write-Host '3/8 headless project launch and scene smoke'
Invoke-GodotChecked @('--', '--scene-smoke')
Write-Host '4/8 runner deliberate-failure self-test'
& powershell -ExecutionPolicy Bypass -File tools\test_runner_selftest.ps1 -GodotBin $GodotBin
if ($LASTEXITCODE -ne 0) { throw 'Test runner self-test failed.' }
Write-Host '5/8 localization keys'
Invoke-GodotChecked @('--script', 'res://tools/check_localization.gd')
Write-Host '6/8 M1 performance gate self-test'
& powershell -ExecutionPolicy Bypass -File tools\benchmark_selftest.ps1 -GodotBin $GodotBin
if ($LASTEXITCODE -ne 0) { throw 'Benchmark gate self-test failed.' }
Write-Host '7/8 M1 performance gate'
$benchmarkArgs = @('--script', 'res://tools/benchmark_m1.gd')
if ($Quick) { $benchmarkArgs += @('--', '--quick') }
Invoke-GodotChecked -GodotArgs $benchmarkArgs
Write-Host '8/9 M1 endurance memory gate'
& powershell -ExecutionPolicy Bypass -File tools\endurance_selftest.ps1 -GodotBin $GodotBin
if ($LASTEXITCODE -ne 0) { throw 'Endurance gate self-test failed.' }
$enduranceArgs = @('--script', 'res://tools/terrain_endurance.gd')
if ($Quick) { $enduranceArgs += @('--', '--quick') }
Invoke-GodotChecked -GodotArgs $enduranceArgs
Write-Host '9/9 M2 control endurance'
$m2Args = @('--script', 'res://tools/m2_endurance.gd')
if ($Quick) { $m2Args += @('--', '--quick') }
Invoke-GodotChecked -GodotArgs $m2Args
Write-Host 'Verification passed.'
