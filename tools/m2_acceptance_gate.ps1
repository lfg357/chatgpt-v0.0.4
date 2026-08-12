param([string]$RecordPath = "tools/m2_playtest_record.md")

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $RecordPath)) { throw "M2 acceptance record is missing: $RecordPath" }
$record = Get-Content -LiteralPath $RecordPath -Raw

function Require-Record([string]$Key, [string]$Pattern) {
	$match = [regex]::Match($record, "(?m)^$([regex]::Escape($Key))=($Pattern)$")
	if (-not $match.Success) { throw "M2 acceptance gate failed: missing or invalid $Key" }
	return $match.Groups[1].Value
}

Require-Record 'M2_ACCEPTANCE_STATUS' 'ACCEPTED' | Out-Null
$acceptedBuild = Require-Record 'M2_ACCEPTED_BUILD' '[0-9a-f]{40}'
Require-Record 'M2_UNMODERATED_SESSIONS' '([5-9]|[1-9][0-9]+)' | Out-Null
Require-Record 'M2_UNIQUE_PLAYERS' '([3-9]|[1-9][0-9]+)' | Out-Null
Require-Record 'M2_INPUT_COVERAGE' 'keyboard_mouse,gamepad' | Out-Null
Require-Record 'M2_UNDERSTOOD_WITHIN_3_MINUTES' '5/5' | Out-Null
Require-Record 'M2_AVERAGE_DRILL_FEEL_AT_LEAST' '([4-9](\.\d+)?)' | Out-Null
Require-Record 'M2_SECOND_DIVE_SESSIONS_AT_LEAST' '([3-9]|[1-9][0-9]+)' | Out-Null
Require-Record 'M2_BLOCKING_DEFECTS' '0' | Out-Null
Require-Record 'M2_DUAL_INPUT_10_MINUTE_RUNS' 'PASS' | Out-Null

# Fresh archives intentionally contain no .git. A checkout must additionally
# prove that the accepted build remains part of the current history.
if (Test-Path -LiteralPath '.git') {
	git cat-file -e "$acceptedBuild^{commit}"
	if ($LASTEXITCODE -ne 0) { throw "M2 acceptance gate failed: accepted build is unavailable: $acceptedBuild" }
	git merge-base --is-ancestor $acceptedBuild HEAD
	if ($LASTEXITCODE -ne 0) { throw "M2 acceptance gate failed: accepted build is not an ancestor of HEAD" }
}

Write-Host "M2_ACCEPTANCE_GATE passed build=$acceptedBuild"
