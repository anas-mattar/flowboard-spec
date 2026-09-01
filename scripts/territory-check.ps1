<#
.SYNOPSIS
    One-command territory check: reports file overlap between the current feature branch
    and every open remote NNN-* feature branch.

.DESCRIPTION
    Automates docs/sdlc/team-workflow.md rule 5 — the stance is unchanged: overlap is
    SEQUENCED, not forbidden. On any live overlap the owners must agree merge order and
    record it in both features' plan.md.

    The touched set of each branch is its committed diff versus the base branch (the
    claim lives in git, not in plan.md prose); for the branch under check, tracked
    uncommitted changes are included too.

    Exit codes: 0 clean (no live overlap) · 2 live overlap found · 1 execution error.
    Overlaps with stale claims (no commits for -StaleDays) are reported as reclaimable
    per team-workflow rule 3 and do not by themselves cause exit 2.

    Contract: specs/003-flow-efficiency-pack/contracts/territory-check-cli.md

.EXAMPLE
    pwsh -File scripts/territory-check.ps1
    pwsh -File scripts/territory-check.ps1 -Branch 011-reports -Json
#>
[CmdletBinding()]
param(
    [string]$Branch,
    [string]$BaseBranch = 'main',
    [int]$StaleDays = 14,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'

$repoRoot = git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0) { Write-Error 'Not inside a git repository.'; exit 1 }
Push-Location $repoRoot
try {

$checkingCurrent = $false
if (-not $Branch) {
    $Branch = git branch --show-current
    $checkingCurrent = $true
}
if ($Branch -notmatch '^\d{3,}-') {
    Write-Error "Branch '$Branch' is not a numbered feature branch (NNN-name) — the territory check applies to the feature lane only."
    exit 1
}

git remote get-url origin 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    if ($Json) { [PSCustomObject]@{ BRANCH = $Branch; CLEAN = $true; OVERLAPS = @() } | ConvertTo-Json -Compress }
    else { Write-Host 'no remote — nothing to check against' }
    exit 0
}
git fetch origin --prune 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Error 'git fetch origin failed.'; exit 1 }

# --- Touched set of the branch under check ---------------------------------------------
$ownRef = if ($checkingCurrent) { 'HEAD' } else {
    if (git branch --list $Branch) { $Branch } else { "origin/$Branch" }
}
$ownFiles = @(git diff --name-only "$BaseBranch...$ownRef" 2>$null)
if ($LASTEXITCODE -ne 0) { Write-Error "Cannot diff $BaseBranch...$ownRef — does '$BaseBranch' exist?"; exit 1 }
if ($checkingCurrent) {
    $ownFiles += @(git diff --name-only HEAD 2>$null)   # tracked, uncommitted
}
$ownFiles = @($ownFiles | Sort-Object -Unique)

# --- Compare against every other open remote feature branch ----------------------------
$openBranches = @()
foreach ($line in (git ls-remote --heads origin 2>$null)) {
    if ($line -match 'refs/heads/(\d{3,}-\S+)$' -and $matches[1] -ne $Branch) { $openBranches += $matches[1] }
}

$overlaps = @()
$liveOverlap = $false
$nowEpoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
foreach ($other in $openBranches) {
    $commitCount = [int](git rev-list --count "$BaseBranch..origin/$other" 2>$null)
    if ($LASTEXITCODE -ne 0) { Write-Warning "Skipping origin/${other}: cannot compare with $BaseBranch."; continue }

    if ($commitCount -eq 0) {
        $status = 'claimed, no work yet'   # freshly claimed — no plan.md is fine (never an error)
        $shared = @()
    } else {
        $lastCommitEpoch = [long](git log -1 --format=%ct "origin/$other" 2>$null)
        $ageDays = [int](($nowEpoch - $lastCommitEpoch) / 86400)
        $status = if ($ageDays -ge $StaleDays) { 'stale — reclaimable' } else { 'live' }
        $otherFiles = @(git diff --name-only "$BaseBranch...origin/$other" 2>$null)
        $shared = @($ownFiles | Where-Object { $otherFiles -contains $_ })
    }
    if ($shared.Count -gt 0) {
        $overlaps += [PSCustomObject]@{ branch = $other; status = $status; files = $shared }
        if ($status -eq 'live') { $liveOverlap = $true }
    }
}

# --- Report -----------------------------------------------------------------------------
if ($Json) {
    [PSCustomObject]@{ BRANCH = $Branch; CLEAN = (-not $liveOverlap); OVERLAPS = $overlaps } |
        ConvertTo-Json -Compress -Depth 4
} else {
    if ($overlaps.Count -eq 0) {
        Write-Host "CLEAN — '$Branch' shares no files with any open feature branch."
    } else {
        foreach ($o in $overlaps) {
            Write-Host "OVERLAP with $($o.branch) [$($o.status)]:"
            $o.files | ForEach-Object { Write-Host "  $_" }
        }
        if ($liveOverlap) {
            Write-Host ''
            Write-Host 'Overlap is sequenced, not forbidden (docs/sdlc/team-workflow.md, rule 5):'
            Write-Host 'agree merge order with the other owner NOW and record it in BOTH features'' plan.md.'
        } else {
            Write-Host ''
            Write-Host 'Only stale claims overlap — consider adopting them per team-workflow rule 3.'
        }
    }
}
if ($liveOverlap) { exit 2 } else { exit 0 }

} finally { Pop-Location }
