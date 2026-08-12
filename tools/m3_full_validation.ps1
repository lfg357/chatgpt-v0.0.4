param([string]$GodotBin = $env:GODOT_BIN)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($GodotBin)) { $GodotBin = 'C:\Users\AdminLFG\AppData\Local\Programs\Godot\Godot_v4.7-stable_win64_console.exe' }
$scriptRoot = Split-Path -Parent $PSCommandPath
$workspace = (Resolve-Path (Join-Path $scriptRoot '..')).Path
$reportDir = Join-Path $workspace 'reports'
$statusPath = Join-Path $reportDir 'm3_full_validation_status.json'
$logPath = Join-Path $reportDir 'm3_full_validation.log'
New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
$started = [DateTimeOffset]::UtcNow
$head = (& git -C $workspace rev-parse HEAD).Trim()

function Write-Status([string]$State, [string]$Message = '') {
    $status = [ordered]@{
        state = $State
        commit_sha = $head
        started_utc = $started.ToString('o')
        finished_utc = if ($State -eq 'running') { $null } else { [DateTimeOffset]::UtcNow.ToString('o') }
        log_path = 'reports/m3_full_validation.log'
        message = $Message
    }
    $status | ConvertTo-Json | Set-Content -LiteralPath $statusPath -Encoding UTF8
}

Write-Status 'running'
try {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & powershell -ExecutionPolicy Bypass -File (Join-Path $scriptRoot 'verify.ps1') -GodotBin $GodotBin *> $logPath
        $verifyExitCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    if ($verifyExitCode -ne 0) { throw "verify.ps1 exited $verifyExitCode" }
    Write-Status 'passed' 'Full unified verification passed.'
    exit 0
} catch {
    Add-Content -LiteralPath $logPath -Value ("FULL_VALIDATION_FAILURE: " + $_.Exception.Message)
    Write-Status 'failed' $_.Exception.Message
    exit 1
}
