param([string]$GodotBin = $env:GODOT_BIN)
if ([string]::IsNullOrWhiteSpace($GodotBin)) { $GodotBin = 'C:\Users\AdminLFG\AppData\Local\Programs\Godot\Godot_v4.7-stable_win64_console.exe' }
& $GodotBin --headless --path . --script res://tools/check_autoload_parse.gd -- --selftest-failure
if ($LASTEXITCODE -eq 0) { throw 'Autoload parse self-test unexpectedly passed.' }
Write-Host 'Autoload parse self-test passed.'
