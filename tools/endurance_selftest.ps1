param([string]$GodotBin = $env:GODOT_BIN)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($GodotBin)) { $GodotBin = 'C:\Users\AdminLFG\AppData\Local\Programs\Godot\Godot_v4.7-stable_win64_console.exe' }
& $GodotBin --headless --path . --script res://tools/terrain_endurance.gd -- --force-over-memory
if ($LASTEXITCODE -eq 0) { throw 'Forced memory-growth endurance run unexpectedly passed.' }
Write-Host 'Endurance gate self-test passed.'
