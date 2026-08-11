param(
    [string]$GodotBin = $env:GODOT_BIN
)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($GodotBin)) { $GodotBin = 'C:\Users\AdminLFG\AppData\Local\Programs\Godot\Godot_v4.7-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $GodotBin)) { throw "Godot binary not found: $GodotBin" }

function Invoke-GodotChecked([string[]]$Args, [bool]$ExpectSuccess = $true) {
    & $GodotBin --headless --path . @Args
    $actual = $LASTEXITCODE
    if ($ExpectSuccess -and $actual -ne 0) { throw "Godot command failed ($actual): $($Args -join ' ')" }
    if ((-not $ExpectSuccess) -and $actual -eq 0) { throw "Godot command unexpectedly succeeded: $($Args -join ' ')" }
}

Write-Host '1/5 headless project launch and script parse'
Invoke-GodotChecked @('--', '--scene-smoke')
Write-Host '2/5 runner deliberate-failure self-test'
Invoke-GodotChecked @('--script', 'res://tests/test_runner.gd', '--', '--selftest-failure') $false
Write-Host '3/5 test suite'
Invoke-GodotChecked @('--script', 'res://tests/test_runner.gd')
Write-Host '4/5 localization keys'
Invoke-GodotChecked @('--script', 'res://tools/check_localization.gd')
Write-Host '5/5 M1 performance smoke'
Invoke-GodotChecked @('--script', 'res://tools/benchmark_m1.gd')
Write-Host 'Verification passed.'
