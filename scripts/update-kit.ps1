<#
.SYNOPSIS
    One-command kit update for an adopted project: copies changed verbatim files,
    reports surgical-class upstream changes, never clobbers local edits.

.DESCRIPTION
    Runs FROM the kit clone against -Target (an adopted project root). Resolves every
    kit-shipped file's update class via kit-manifest.json (most-specific match wins —
    same resolution scripts/doc-lint.ps1 uses to gate the kit's own CI), applies the
    three-way merge-avoidance rule to verbatim files (data-model.md), and reports
    surgical files' upstream commits between the target's recorded kit commit and the
    kit's HEAD — never writing to surgical-class paths.

    Preflight refuses (exit 1) when: -Kit is not a git repo with kit-manifest.json;
    -Target resolves to -Kit; -Target is missing kit-integrity essentials (partial
    install); -Target's git working tree is dirty. -DryRun prints the full report with
    zero writes. -Force <path[]> takes the kit version of specific conflicted verbatim
    paths; forcing a surgical-class path is refused.

    All content comparisons are CRLF-normalized (research D4) — Windows line-ending
    differences never count as a change. A file that fails to read as text falls back
    to a raw-byte comparison.

    Exit codes: 0 clean · 2 attention needed (conflicts and/or pending surgical work) ·
    1 execution error / preflight refusal.

    Contract: specs/004-kit-update-channel/contracts/update-kit-cli.md

.EXAMPLE
    pwsh -File scripts/update-kit.ps1 -Target ../my-project
    pwsh -File scripts/update-kit.ps1 -Target ../my-project -DryRun
    pwsh -File scripts/update-kit.ps1 -Target ../my-project -Force docs/sdlc/flow.md
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Target,
    [string]$Kit = (Split-Path -Parent $PSScriptRoot),
    [switch]$DryRun,
    [string[]]$Force = @(),
    [switch]$Json
)

$ErrorActionPreference = 'Stop'

function Write-Fail {
    param([string]$Message)
    if ($Json) { [PSCustomObject]@{ error = $Message } | ConvertTo-Json -Compress }
    else { Write-Host "ERROR: $Message" }
    exit 1
}

# --- Preflight: kit root ------------------------------------------------------------
if (-not (Test-Path $Kit)) { Write-Fail "Kit root not found: $Kit" }
$Kit = (Resolve-Path $Kit).Path
if (-not (Test-Path (Join-Path $Kit '.git'))) { Write-Fail "-Kit ($Kit) is not a git repository." }
$manifestPath = Join-Path $Kit 'kit-manifest.json'
if (-not (Test-Path $manifestPath)) { Write-Fail "kit-manifest.json not found at kit root ($Kit)." }

# --- Preflight: target ----------------------------------------------------------------
if (-not (Test-Path $Target)) { Write-Fail "Target not found: $Target" }
$Target = (Resolve-Path $Target).Path
if ($Target -ieq $Kit) { Write-Fail '-Target resolves to the kit itself — refusing to self-update.' }

# Kit-integrity essentials — must match scripts/doc-lint.ps1's $requiredKitPaths.
$requiredKitPaths = @(
    'CLAUDE.md'
    'AGENTS.md'
    '.specify/memory/constitution.md'
    '.specify/templates'
    '.specify/scripts'
    '.claude/commands'
    'docs/sdlc/definition-of-done.md'
    'docs/sdlc/flow.md'
    'docs/sdlc/gate-command.md'
    'docs/sdlc/review-process.md'
    'docs/rulebooks'
    'specs/_templates'
    'scripts/claim-feature.ps1'
    'scripts/territory-check.ps1'
)
$missingTarget = $requiredKitPaths | Where-Object { -not (Test-Path (Join-Path $Target $_)) }
if ($missingTarget.Count -gt 0) {
    Write-Fail "Target is missing kit-integrity essentials (partial install?): $($missingTarget -join ', ')"
}

$targetStatus = git -C $Target status --porcelain 2>$null
if ($LASTEXITCODE -ne 0) { Write-Fail "Target ($Target) is not a git repository." }
if ($targetStatus) { Write-Fail 'Target working tree is dirty — updates must land reviewable. Commit or stash first.' }

# --- Manifest resolution (must match scripts/doc-lint.ps1's glob/specificity rules) ----
function ConvertTo-GlobRegex {
    param([string]$Pattern)
    $e = [regex]::Escape($Pattern)
    $e = $e -replace '\\\*\\\*', '@@DBLSTAR@@'
    $e = $e -replace '\\\*', '[^/]*'
    $e = $e -replace '@@DBLSTAR@@', '.*'
    return "^$e`$"
}

function Get-PatternSpecificity {
    param([string]$Pattern)
    $starIdx = $Pattern.IndexOf('*')
    if ($starIdx -lt 0) { return 1000000 + $Pattern.Length }
    return $starIdx
}

$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
$manifestEntries = @($manifest.entries)

function Resolve-Class {
    param([string]$RelPath)
    $hits = @($manifestEntries | Where-Object { $RelPath -match (ConvertTo-GlobRegex $_.path) })
    if ($hits.Count -eq 0) { return $null }
    $maxSpec = ($hits | ForEach-Object { Get-PatternSpecificity $_.path } | Measure-Object -Maximum).Maximum
    $winners = @($hits | Where-Object { (Get-PatternSpecificity $_.path) -eq $maxSpec })
    $classes = @($winners.class | Select-Object -Unique)
    if ($classes.Count -gt 1) { return $null }
    return $classes[0]
}

# Shipped surfaces — must match scripts/doc-lint.ps1's enumeration (research D7).
$shipped = @()
foreach ($f in 'CLAUDE.md', 'AGENTS.md', 'README.md', '.specify/memory/constitution.md', 'kit-manifest.json') {
    if (Test-Path (Join-Path $Kit $f)) { $shipped += $f }
}
foreach ($dir in '.specify/templates', '.specify/scripts', '.claude/commands', 'docs', 'adoption', 'modules', 'specs/_templates', '.github') {
    $p = Join-Path $Kit $dir
    if (Test-Path $p) {
        $shipped += Get-ChildItem $p -Recurse -File | ForEach-Object {
            ([IO.Path]::GetRelativePath($Kit, $_.FullName)) -replace '\\', '/'
        }
    }
}
$scriptsDir = Join-Path $Kit 'scripts'
if (Test-Path $scriptsDir) {
    $shipped += Get-ChildItem $scriptsDir -Filter *.ps1 -File | ForEach-Object {
        ([IO.Path]::GetRelativePath($Kit, $_.FullName)) -replace '\\', '/'
    }
}
$shipped = $shipped | Where-Object { $_ -ne 'docs/roadmap.md' } | Select-Object -Unique

$classified = @(foreach ($f in $shipped) {
    $c = Resolve-Class $f
    if ($c) { [PSCustomObject]@{ Path = $f; Class = $c } }
})
$verbatimFiles = @($classified | Where-Object { $_.Class -eq 'verbatim' })
$surgicalFiles = @($classified | Where-Object { $_.Class -eq 'surgical' })

# --- -Force validation: only verbatim paths may be forced ------------------------------
$forceSet = @($Force | ForEach-Object { $_ -replace '\\', '/' })
foreach ($f in $forceSet) {
    $entry = $classified | Where-Object { $_.Path -eq $f }
    if (-not $entry) { Write-Fail "-Force path '$f' is not a manifest-classified kit file." }
    if ($entry.Class -ne 'verbatim') { Write-Fail "-Force path '$f' is class '$($entry.Class)' — only verbatim paths may be forced." }
}

# --- Version record ---------------------------------------------------------------------
$kitVersionPath = Join-Path $Target '.kit-version'
$recordedCommit = $null
if (Test-Path $kitVersionPath) {
    try { $recordedCommit = (Get-Content $kitVersionPath -Raw | ConvertFrom-Json).kitCommit } catch {}
}
$kitHeadSha = (git -C $Kit rev-parse HEAD).Trim()
$constitutionText = Get-Content (Join-Path $Kit '.specify/memory/constitution.md') -Raw
$kitVersionString = if ($constitutionText -match '\*\*Version\*\*:\s*([0-9]+\.[0-9]+\.[0-9]+)') { $Matches[1] } else { 'unknown' }

function Get-NormalizedText {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    try {
        return (Get-Content -LiteralPath $Path -Raw -ErrorAction Stop) -replace "`r`n", "`n"
    } catch {
        return [System.Convert]::ToBase64String([IO.File]::ReadAllBytes($Path))
    }
}

# --- Verbatim pass (data-model.md three-way table) --------------------------------------
$applied = @()
$conflicts = @()
foreach ($entry in $verbatimFiles) {
    $rel = $entry.Path
    $kitAbs = Join-Path $Kit $rel
    $targetAbs = Join-Path $Target $rel
    $kitText = Get-NormalizedText $kitAbs

    if (-not (Test-Path $targetAbs)) {
        if (-not $DryRun) {
            $destDir = Split-Path -Parent $targetAbs
            if ($destDir -and -not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
            Copy-Item $kitAbs $targetAbs -Force
        }
        $applied += [PSCustomObject]@{ Path = $rel; State = 'never installed -> copied' }
        continue
    }

    $targetText = Get-NormalizedText $targetAbs
    if ($targetText -eq $kitText) { continue }   # up to date

    $baselineText = $null
    if ($recordedCommit) {
        # Redirect straight to a file rather than capturing via the pipeline: PowerShell's
        # line-array capture of native stdout drops exact newline fidelity (notably a
        # trailing newline), which would make an untouched file compare unequal to its
        # own baseline. Reusing Get-NormalizedText keeps this comparison symmetric with
        # the kit/target reads above.
        $tmpFile = [IO.Path]::GetTempFileName()
        try {
            & git -C $Kit show "${recordedCommit}:$rel" > $tmpFile 2>$null
            if ($LASTEXITCODE -eq 0) { $baselineText = Get-NormalizedText $tmpFile }
        } finally {
            Remove-Item $tmpFile -ErrorAction SilentlyContinue
        }
    }

    $forced = $forceSet -contains $rel
    if ($forced -or ($null -ne $baselineText -and $baselineText -eq $targetText)) {
        if (-not $DryRun) { Copy-Item $kitAbs $targetAbs -Force }
        $applied += [PSCustomObject]@{ Path = $rel; State = if ($forced) { 'forced -> kit version' } else { 'clean update -> copied' } }
    } elseif ($recordedCommit -and $null -ne $baselineText) {
        $conflicts += [PSCustomObject]@{ Path = $rel; Reason = 'locally modified'; Resolution = "rerun with -Force $rel to take the kit version" }
    } else {
        $conflicts += [PSCustomObject]@{ Path = $rel; Reason = 'differs — no baseline (unknown provenance)'; Resolution = "review manually, or rerun with -Force $rel to take the kit version" }
    }
}

# --- Surgical pass (research D6) --------------------------------------------------------
$surgicalReport = @()
foreach ($entry in $surgicalFiles) {
    $rel = $entry.Path
    if (-not $recordedCommit) {
        $surgicalReport += [PSCustomObject]@{ Path = $rel; Commits = @(); Note = 'no baseline — review all' }
        continue
    }
    $log = @(git -C $Kit log "$recordedCommit..HEAD" --oneline -- $rel 2>$null)
    if ($log.Count -gt 0) {
        $surgicalReport += [PSCustomObject]@{ Path = $rel; Commits = $log; Note = 'upstream commits since your recorded kit version — see adoption/updating.md' }
    }
}

# --- Compute the recorded commit for this run's write + report ---------------------------
# It only advances to kit HEAD on a clean/resolved run (SC-002): while any conflict or
# surgical item is still outstanding against an EXISTING record, keep it pinned so a bare
# re-run reproduces the identical report — nothing gets silently acknowledged just by
# running the tool again. The very first write (no prior record) always advances, even
# amid a degraded-mode report full of "no baseline" entries — that transition is what
# gives the next run a precise baseline (research D5).
$hasPending = ($conflicts.Count -gt 0 -or $surgicalReport.Count -gt 0)
$newKitCommit = if ($recordedCommit -and $hasPending) { $recordedCommit } else { $kitHeadSha }

if (-not $DryRun) {
    $record = [PSCustomObject]@{
        kitVersion = $kitVersionString
        kitCommit  = $newKitCommit
        updatedOn  = (Get-Date -Format 'yyyy-MM-dd')
    }
    Set-Content -LiteralPath $kitVersionPath -Value ($record | ConvertTo-Json)
}

# --- Report -------------------------------------------------------------------------------
$upToDate = ($applied.Count -eq 0 -and $conflicts.Count -eq 0 -and $surgicalReport.Count -eq 0)

if ($Json) {
    [PSCustomObject]@{
        applied   = $applied
        surgical  = $surgicalReport
        conflicts = $conflicts
        dryRun    = [bool]$DryRun
        result    = if ($upToDate) { 'up to date' } else { [PSCustomObject]@{ kitVersion = $kitVersionString; kitCommit = $newKitCommit } }
    } | ConvertTo-Json -Depth 6
} else {
    Write-Host "update-kit: $Kit -> $Target$(if ($DryRun) { ' (dry run — zero writes)' })"
    if ($applied.Count -gt 0) {
        Write-Host "Applied ($($applied.Count)):"
        foreach ($a in $applied) { Write-Host "  $($a.Path)  [$($a.State)]" }
    }
    if ($surgicalReport.Count -gt 0) {
        Write-Host "Surgical - upstream changes, never applied ($($surgicalReport.Count)):"
        foreach ($s in $surgicalReport) {
            Write-Host "  $($s.Path)"
            foreach ($c in $s.Commits) { Write-Host "    $c" }
            Write-Host "    $($s.Note)"
        }
    }
    if ($conflicts.Count -gt 0) {
        Write-Host "Conflicts - locally modified, not applied ($($conflicts.Count)):"
        foreach ($c in $conflicts) { Write-Host "  $($c.Path)  [$($c.Reason)] -- $($c.Resolution)" }
    }
    if ($upToDate) {
        Write-Host 'Result: up to date'
    } else {
        Write-Host "Result: kit $kitVersionString @ $newKitCommit$(if ($DryRun) { ' (not written - dry run)' })"
    }
}

if ($conflicts.Count -gt 0 -or $surgicalReport.Count -gt 0) { exit 2 }
exit 0
