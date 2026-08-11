param([string]$GodotBin = $env:GODOT_BIN)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($GodotBin)) { $GodotBin = 'C:\Users\AdminLFG\AppData\Local\Programs\Godot\Godot_v4.7-stable_win64_console.exe' }
& $GodotBin --headless --path . --script res://tools/benchmark_m1.gd -- --force-over-budget
if ($LASTEXITCODE -eq 0) { throw 'Forced over-budget benchmark unexpectedly passed.' }
Write-Host 'Benchmark gate self-test passed.'
