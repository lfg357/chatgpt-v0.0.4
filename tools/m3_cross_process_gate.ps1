param([string]$GodotBin = $env:GODOT_BIN)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($GodotBin)) { $GodotBin = 'C:\Users\AdminLFG\AppData\Local\Programs\Godot\Godot_v4.7-stable_win64_console.exe' }
$scriptRoot = Split-Path -Parent $PSCommandPath
$workspace = (Resolve-Path (Join-Path $scriptRoot '..')).Path

function Invoke-HashProbe([string]$ProjectPath) {
    $previous = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { $output = @(& $GodotBin --headless --path $ProjectPath --script res://tools/m3_hash_probe.gd 2>&1) }
    finally { $ErrorActionPreference = $previous }
    if ($LASTEXITCODE -ne 0) { throw "M3 hash probe failed in $ProjectPath" }
    $errors = @($output | Where-Object { "$_" -match '(^|\s)(SCRIPT ERROR:|Parse Error:|ERROR:)' })
    if ($errors.Count -gt 0) { throw "M3 hash probe printed engine errors: $($errors -join ' | ')" }
    $line = @($output | Where-Object { "$_" -match '^M3_HASH_PROBE ' })
    if ($line.Count -ne 1) { throw 'M3 hash probe summary missing.' }
    return "$($line[0])".Substring('M3_HASH_PROBE '.Length)
}

$first = Invoke-HashProbe $workspace
$second = Invoke-HashProbe $workspace
if ($first -ne $second) { throw 'Cross-process topology hashes differ.' }

$coldRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("m3-cold-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $coldRoot | Out-Null
try {
    & git -C $workspace archive HEAD -o (Join-Path $coldRoot 'snapshot.tar')
    if ($LASTEXITCODE -ne 0) { throw 'Unable to create cold Git snapshot.' }
    tar -xf (Join-Path $coldRoot 'snapshot.tar') -C $coldRoot
    $cold = Invoke-HashProbe $coldRoot
    if ($first -ne $cold) { throw 'Cold-snapshot topology hashes differ.' }
} finally {
    Remove-Item -LiteralPath $coldRoot -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host 'M3_CROSS_PROCESS_GATE passed processes=2 cold_snapshot=true layers=3'
