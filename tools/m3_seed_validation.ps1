param([string]$GodotBin = $env:GODOT_BIN, [switch]$Quick)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($GodotBin)) { $GodotBin = 'C:\Users\AdminLFG\AppData\Local\Programs\Godot\Godot_v4.7-stable_win64_console.exe' }
$scriptRoot = Split-Path -Parent $PSCommandPath
$workspace = (Resolve-Path (Join-Path $scriptRoot '..')).Path
$arguments = @('--headless', '--path', $workspace, '--script', 'res://tools/m3_seed_validation.gd')
if ($Quick) { $arguments += @('--', '--quick') }
$previous = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
try { $output = @(& $GodotBin @arguments 2>&1) } finally { $ErrorActionPreference = $previous }
$output | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0) { throw "M3 seed validation exited $LASTEXITCODE" }
$errors = @($output | Where-Object { "$_" -match '(^|\s)(SCRIPT ERROR:|Parse Error:|ERROR:)' })
if ($errors.Count -gt 0) { throw "M3 seed validation printed engine errors: $($errors -join ' | ')" }
$expected = if ($Quick) { 20 } else { 1000 }
if (-not ($output -match "M3_SEED_VALIDATION layers=3 seeds_per_layer=$expected failures=0")) { throw 'M3 seed validation summary is missing or incomplete.' }
