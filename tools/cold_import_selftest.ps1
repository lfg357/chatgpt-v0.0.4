param([string]$GodotBin = $env:GODOT_BIN)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($GodotBin)) { $GodotBin = 'C:\Users\AdminLFG\AppData\Local\Programs\Godot\Godot_v4.7-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $GodotBin)) { throw "Godot binary not found: $GodotBin" }

$workspace = (Resolve-Path '.').Path
$scratch = Join-Path ([System.IO.Path]::GetTempPath()) ("m2-cold-import-" + [guid]::NewGuid().ToString('N'))
$archive = Join-Path $scratch 'snapshot.zip'
$snapshot = Join-Path $scratch 'project'

try {
    New-Item -ItemType Directory -Path $scratch | Out-Null
    & git -C $workspace archive --format=zip --output=$archive HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Unable to create a tracked-file snapshot for cold import.' }
    Expand-Archive -LiteralPath $archive -DestinationPath $snapshot -Force
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $output = @(& $GodotBin --headless --editor --path $snapshot --quit-after 120 2>&1) }
    finally { $ErrorActionPreference = $previousPreference }
    $output | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) { throw "Cold snapshot import failed with exit code $LASTEXITCODE." }
    $engineErrors = @($output | Where-Object { "$_" -match '(^|\s)(SCRIPT ERROR:|Parse Error:|ERROR:)' })
    if ($engineErrors.Count -gt 0) { throw "Cold snapshot import printed engine errors: $($engineErrors -join ' | ')" }
    Write-Host 'Cold snapshot import passed.'
}
finally {
    if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force }
}
