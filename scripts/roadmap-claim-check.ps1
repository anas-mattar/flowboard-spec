<#
.SYNOPSIS
    Roadmap-claim visibility check: every NNN-* claim on origin must have a non-idea
    roadmap row, so main's roadmap never lies about in-flight work (GAP-017).

.DESCRIPTION
    The remote NNN-* branch IS the claim (docs/sdlc/branch-strategy.md, Number
    Allocation; scripts/claim-feature.ps1). But the roadmap status flip used to live on
    the feature branch, invisible from main until merge: in the first post-010 field use
    a feature sat 13 days with an approved spec and a gated phase while main's row still
    read idea — an agent orienting from main would have re-specced it.

    This check makes that lie fail the gate. For every NNN-name branch on origin, the
    roadmap table in docs/roadmap.md (any table under a Status-bearing header) must hold
    a row mentioning NNN-name whose Status is not 'idea'. The remedy is the ritual this
    enforces: flip the row (Status, Owner, Spec path) in a MAIN-SIDE docs commit at
    claim time — never only on the feature branch.

    Deliberate n/a states (exit 0, never synthetic failures — verify-kit precedent):
      - no origin remote, or the ledger unreachable (offline)
      - no docs/roadmap.md, or no table with a Status column (adopter roadmaps are
        adopter-authored and may not follow the kit's shape)

    The branch currently being checked is exempt for its OWN number, so a fresh claim's
    first CI run cannot deadlock on its not-yet-flipped row. Cell parsing counts only
    unescaped pipes (the GAP-015 lesson). Read-only.

.EXAMPLE
    pwsh -File scripts/roadmap-claim-check.ps1
    pwsh -File scripts/roadmap-claim-check.ps1 -Branch 011-roadmap-claim-check
#>
[CmdletBinding()]
param(
    [string]$Branch,
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path $Root).Path

function Get-Cells {
    # GAP-015: an escaped \| is cell content, not a boundary. Shield it before splitting.
    param([string]$Line)
    $shield = [string][char]1
    $cells = $Line.Trim().Trim('|').Replace('\|', $shield) -split '\|'
    return @($cells | ForEach-Object { $_.Replace($shield, '\|').Trim() })
}

# --- 1. The claim ledger ----------------------------------------------------------------
git -C $Root remote get-url origin 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host 'roadmap-claims: n/a (no origin remote — no claim ledger to check against)'
    exit 0
}
$heads = git -C $Root ls-remote --heads origin 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host 'roadmap-claims: n/a (origin unreachable — cannot read the claim ledger)'
    exit 0
}
$claims = @()
foreach ($line in $heads) {
    # Same shape claim-feature.ps1 allocates; datestamped Spec Kit branches are not claims.
    if ($line -match 'refs/heads/(\d{3,}-\S+)$' -and $matches[1] -notmatch '^\d{8}-\d{6}-') {
        $claims += $matches[1]
    }
}
if ($claims.Count -eq 0) {
    Write-Host 'roadmap-claims: OK (no NNN-* claims on origin)'
    exit 0
}

# --- 2. Own-number exemption -------------------------------------------------------------
if (-not $Branch) { $Branch = (git -C $Root rev-parse --abbrev-ref HEAD 2>$null).Trim() }
$ownNumber = $null
if ($Branch -match '^(\d{3,})-') { $ownNumber = $matches[1] }

# --- 3. The roadmap table(s) --------------------------------------------------------------
$roadmapPath = Join-Path $Root 'docs/roadmap.md'
if (-not (Test-Path $roadmapPath)) {
    Write-Host 'roadmap-claims: n/a (no docs/roadmap.md in this tree)'
    exit 0
}
$lines = Get-Content $roadmapPath

# Collect data rows from every table whose header carries a Status column.
$rows = @()   # each: @{ Text = raw line; Status = trimmed status cell or $null }
$statusIdx = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line -notmatch '^\s*\|') { $statusIdx = -1; continue }
    if ($line -match '^\s*\|[\s:|-]+\|?\s*$') { continue }   # separator row
    $cells = Get-Cells $line
    $next = if ($i + 1 -lt $lines.Count) { $lines[$i + 1] } else { '' }
    if ($next -match '^\s*\|[\s:|-]+\|?\s*$') {
        # Header row: remember where Status sits (or mark the table as not ours).
        $statusIdx = [array]::IndexOf(@($cells | ForEach-Object { "$_" }), 'Status')
        continue
    }
    if ($statusIdx -lt 0) { continue }
    $status = if ($statusIdx -lt $cells.Count) { $cells[$statusIdx] } else { $null }
    $rows += @{ Text = $line; Status = $status }
}
if ($rows.Count -eq 0) {
    Write-Host 'roadmap-claims: n/a (docs/roadmap.md has no table with a Status column)'
    exit 0
}

# --- 4. Every claim must be visible ------------------------------------------------------
$failures = @()
$checked = 0
foreach ($claim in $claims) {
    if ($ownNumber -and $claim -match "^$ownNumber-") { continue }   # own claim: flip may ride this very change
    $checked++
    $matching = @($rows | Where-Object { $_.Text -like "*$claim*" })
    if ($matching.Count -eq 0) {
        $failures += "roadmap-claims: claim '$claim' is on origin but no roadmap row mentions it — flip the row (Status, Owner, Spec ``specs/$claim/``) in a main-side docs commit at claim time (GAP-017)"
    } elseif (-not ($matching | Where-Object { $_.Status -and $_.Status -ne 'idea' })) {
        $failures += "roadmap-claims: claim '$claim' is on origin but its roadmap row still reads 'idea' — flip the row (Status, Owner, Spec path) in a main-side docs commit at claim time (GAP-017)"
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Host $_ }
    Write-Host "roadmap-claims: FAIL ($($failures.Count) of $checked claim(s) invisible or stale on this tree's roadmap)"
    exit 1
}
Write-Host "roadmap-claims: OK ($checked claim(s) visible with non-idea rows$(if ($ownNumber) { ", own claim $ownNumber exempt" }))"
exit 0
