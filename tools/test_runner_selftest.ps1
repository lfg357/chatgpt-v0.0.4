param([string]$GodotBin = $env:GODOT_BIN)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($GodotBin)) { $GodotBin = 'C:\Users\AdminLFG\AppData\Local\Programs\Godot\Godot_v4.7-stable_win64_console.exe' }
function Expect-Exit([string[]]$GodotArgs, [int]$Expected) {
  & $GodotBin --headless --path . --script res://tests/test_runner.gd -- @GodotArgs
  if ($LASTEXITCODE -ne $Expected) { throw "Expected $Expected, got ${LASTEXITCODE}: $($GodotArgs -join ' ')" }
}
Expect-Exit -GodotArgs @('--selftest-failure') -Expected 1
Expect-Exit -GodotArgs @('--selftest-zero') -Expected 1
Expect-Exit -GodotArgs @('--test-root=res://tests/fixtures/hooks') -Expected 0
Expect-Exit -GodotArgs @('--test-root=res://tests/fixtures/failure') -Expected 1
Expect-Exit -GodotArgs @('--test-root=res://tests/fixtures/timeout') -Expected 1
Expect-Exit -GodotArgs @('--test-root=res://tests/fixtures/load_failure') -Expected 1
Expect-Exit -GodotArgs @('--test-root=res://tests/fixtures/exception') -Expected 1
Expect-Exit -GodotArgs @('--test-root=res://tests/fixtures/exception_hook') -Expected 1
Write-Host 'Runner self-test passed.'
