param([string]$GodotBin = $env:GODOT_BIN)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($GodotBin)) { $GodotBin = 'C:\Users\AdminLFG\AppData\Local\Programs\Godot\Godot_v4.7-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $GodotBin)) { throw "Godot binary not found: $GodotBin" }

$scriptRoot = Split-Path -Parent $PSCommandPath
$workspace = (Resolve-Path (Join-Path $scriptRoot '..')).Path
$scratch = $null
$snapshot = $workspace
$requiredSnapshotPaths = @(
    'project.godot',
    'tests/test_runner.gd',
    'tests/unit/test_terrain.gd',
    'tests/unit/test_terrain_world.gd',
    'tools/terrain_endurance.gd'
)

try {
    # QA invokes this script both from a Git checkout and from a previously
    # extracted git archive.  The latter deliberately has no .git directory;
    # it is already the cache-free snapshot and must not try to archive again.
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $isGitCheckout = ((& git -C $workspace rev-parse --is-inside-work-tree 2>$null) -eq 'true') }
    finally { $ErrorActionPreference = $previousPreference }
    if ($isGitCheckout) {
        $scratch = Join-Path ([System.IO.Path]::GetTempPath()) ("m2-cold-import-" + [guid]::NewGuid().ToString('N'))
        $archive = Join-Path $scratch 'snapshot.zip'
        $snapshot = Join-Path $scratch 'project'
        New-Item -ItemType Directory -Path $scratch | Out-Null
        & git -C $workspace archive --format=zip --output=$archive HEAD
        if ($LASTEXITCODE -ne 0) { throw 'Unable to create a tracked-file snapshot for cold import.' }
        Expand-Archive -LiteralPath $archive -DestinationPath $snapshot -Force
    }
    foreach ($relativePath in $requiredSnapshotPaths) {
        $snapshotPath = Join-Path $snapshot $relativePath
        if (-not (Test-Path -LiteralPath $snapshotPath)) {
            throw "Cold snapshot archive is missing required tracked path: $relativePath"
        }
    }
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $importOutput = @(& $GodotBin --headless --editor --path $snapshot --quit-after 120 2>&1) }
    finally { $ErrorActionPreference = $previousPreference }
    $importOutput | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) { throw "Cold snapshot import failed with exit code $LASTEXITCODE." }
    $importErrors = @($importOutput | Where-Object { "$_" -match '(^|\s)(SCRIPT ERROR:|Parse Error:|ERROR:)' })
    if ($importErrors.Count -gt 0) { throw "Cold snapshot import printed engine errors: $($importErrors -join ' | ')" }

    $ErrorActionPreference = 'Continue'
    try { $testOutput = @(& $GodotBin --headless --path $snapshot --script res://tests/test_runner.gd 2>&1) }
    finally { $ErrorActionPreference = $previousPreference }
    $testOutput | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) { throw "Cold snapshot test suite failed with exit code $LASTEXITCODE." }
    $testErrors = @($testOutput | Where-Object { "$_" -match '(^|\s)(SCRIPT ERROR:|Parse Error:|ERROR:)' })
    if ($testErrors.Count -gt 0) { throw "Cold snapshot test suite printed engine errors: $($testErrors -join ' | ')" }
    Write-Host 'Cold snapshot tests and import passed.'
}
finally {
    if ($null -ne $scratch -and (Test-Path -LiteralPath $scratch)) { Remove-Item -LiteralPath $scratch -Recurse -Force }
}
