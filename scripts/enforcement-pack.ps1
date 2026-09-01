<#
.SYNOPSIS
    Enforcement pack: mechanically checks the kit's delivery-level non-negotiables.

.DESCRIPTION
    Converts five previously-prose rules into CI-agnostic checks, run against the current
    branch's diff versus main:

      - Structure       (NNN-* branches): spec.md/plan.md/tasks.md exist; Delivery Level
                         header is filled with Lite, Standard, or Critical (not the
                         template placeholder).
      - LiteAndAbuse     (fix/*, chore/* branches): no changed file matches a prohibited
                         category (dependency manifest, auth, schema/migration, contracts,
                         domain invariants); migrations are always prohibited on this lane
                         regardless of file count; more than $Config.AbuseGuardFileCount
                         changed files fails as well, suggesting promotion to a feature.
      - CriticalEvidence (NNN-* branches declared Critical): second-model-review.md exists
                         and was first committed at least $Config.CoolingOffHours ago.
      - PhaseSizeWarning (NNN-* branches): non-blocking warning when a single commit's
                         diff exceeds the configured line/file thresholds.
      - GateBatching     (NNN-* branches): the plan.md '**Gate Batching**' declaration,
                         when present, must be 'none' or 'phases N-M' spanning at most
                         $Config.MaxBatchPhases consecutive phases, and is prohibited
                         outright on Critical features (constitution X, Batched gates;
                         docs/sdlc/critical-delivery.md item 4). An absent line means
                         'none' — plans from before the clause remain valid.

    See specs/002-enforcement-pack/research.md for the rationale behind every default below.

.EXAMPLE
    pwsh -File scripts/enforcement-pack.ps1
    pwsh -File scripts/enforcement-pack.ps1 -Branch fix/my-branch
#>
[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [string]$Branch
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path $Root).Path
Push-Location $Root
try {

$Config = @{
    DependencyManifestGlobs = @('package.json', 'package-lock.json', '*.csproj', 'requirements*.txt', 'Pipfile*', 'go.mod', 'go.sum', 'Gemfile*')
    AuthPathGlobs           = @('*auth*')
    SchemaMigrationGlobs    = @('*migrations*', '*migration*.sql', '*migration*.ps1', '*migration*.py')
    ContractsGlob           = '*contracts*'
    DomainInvariantsPath    = '{{DOMAIN_INVARIANTS_PATH}}'
    AbuseGuardFileCount     = 25
    CoolingOffHours         = 24
    PhaseWarnLines          = 400
    PhaseWarnFiles          = 15
    MaxBatchPhases          = 3
}

$failures = @()
$warnings = @()

function Get-CurrentBranch {
    param([string]$Override)
    if ($Override) { return $Override }
    (git rev-parse --abbrev-ref HEAD 2>$null).Trim()
}

function Get-DiffBase {
    $candidates = @('origin/main', 'main')
    foreach ($c in $candidates) {
        git rev-parse --verify --quiet $c *> $null
        if ($LASTEXITCODE -eq 0) {
            $base = (git merge-base HEAD $c 2>$null).Trim()
            if ($LASTEXITCODE -eq 0 -and $base) { return $base }
        }
    }
    return $null
}

function Get-ChangedFiles {
    param([string]$Base)
    if (-not $Base) { return @() }
    (git diff --name-only $Base HEAD 2>$null) | Where-Object { $_ }
}

function Test-GlobAny {
    param([string]$Path, [string[]]$Globs)
    foreach ($g in $Globs) {
        if ($Path -like $g) { return $true }
        if (($Path -split '/') -contains ($g -replace '\*', '')) { return $true }
    }
    return $false
}

# --- Structure check (FR-002) ---
function Invoke-StructureCheck {
    param([string]$Branch)
    if ($Branch -notmatch '^\d{3}-') { return }
    $dir = "specs/$Branch"
    foreach ($required in @('spec.md', 'plan.md', 'tasks.md')) {
        $p = Join-Path $dir $required
        if (-not (Test-Path $p)) {
            $script:failures += "Structure: $dir/$required is missing (every NNN-* branch requires spec.md, plan.md, and tasks.md — CLAUDE.md Feature Structure)"
        }
    }
    $specPath = Join-Path $dir 'spec.md'
    if (Test-Path $specPath) {
        $line = (Get-Content $specPath | Where-Object { $_ -match '^\*\*Delivery Level\*\*:' } | Select-Object -First 1)
        if (-not $line) {
            $script:failures += "Structure: $dir/spec.md has no **Delivery Level** header"
        } elseif ($line -notmatch '^\*\*Delivery Level\*\*:\s*(Lite|Standard|Critical)\b') {
            $script:failures += "Structure: $dir/spec.md's **Delivery Level** header is unfilled or invalid: '$($line.Trim())' (must be Lite, Standard, or Critical)"
        }
    }
}

# --- Lite-lane prohibition + abuse guard (FR-003, FR-004) ---
function Invoke-LiteAndAbuseCheck {
    param([string]$Branch, [string[]]$ChangedFiles)
    if ($Branch -notmatch '^(fix|chore)/') { return }

    $categories = [ordered]@{
        'dependency manifest' = $Config.DependencyManifestGlobs
        'auth code'           = $Config.AuthPathGlobs
        'schema/migration'    = $Config.SchemaMigrationGlobs
        'contracts'           = @($Config.ContractsGlob)
    }
    if ($Config.DomainInvariantsPath -and $Config.DomainInvariantsPath -notmatch '^\{\{') {
        $categories['domain invariants'] = @($Config.DomainInvariantsPath)
    }

    $migrationHit = $false
    foreach ($file in $ChangedFiles) {
        foreach ($cat in $categories.Keys) {
            if (Test-GlobAny -Path $file -Globs $categories[$cat]) {
                $script:failures += "LiteAndAbuse: $Branch touches '$file', a prohibited category for the Lite lane ($cat) — promote to a numbered feature (docs/sdlc/critical-delivery.md)"
            }
        }
        if (Test-GlobAny -Path $file -Globs $Config.SchemaMigrationGlobs) { $migrationHit = $true }
    }

    if ($ChangedFiles.Count -gt $Config.AbuseGuardFileCount) {
        $script:failures += "LiteAndAbuse: $Branch changes $($ChangedFiles.Count) files, exceeding the Lite-lane abuse guard ($($Config.AbuseGuardFileCount)) — promote to a numbered feature"
    }
    if ($migrationHit) {
        $script:failures += "LiteAndAbuse: $Branch touches a migration path — migrations are always prohibited on the Lite lane regardless of file count"
    }
}

# --- Critical-evidence check (FR-005) ---
function Invoke-CriticalEvidenceCheck {
    param([string]$Branch)
    if ($Branch -notmatch '^\d{3}-') { return }
    $dir = "specs/$Branch"
    $specPath = Join-Path $dir 'spec.md'
    if (-not (Test-Path $specPath)) { return }
    $line = (Get-Content $specPath | Where-Object { $_ -match '^\*\*Delivery Level\*\*:' } | Select-Object -First 1)
    if (-not $line -or $line -notmatch '^\*\*Delivery Level\*\*:\s*Critical\b') { return }

    $reviewPath = Join-Path $dir 'second-model-review.md'
    if (-not (Test-Path $reviewPath)) {
        $script:failures += "CriticalEvidence: $dir/second-model-review.md is missing (required for Critical features — docs/sdlc/critical-delivery.md item 5)"
        return
    }
    $recorded = (git log --follow --format=%aI -- $reviewPath 2>$null) | Select-Object -Last 1
    if (-not $recorded) {
        $script:failures += "CriticalEvidence: $dir/second-model-review.md has no git history — cannot verify the cooling-off period (commit it to start the clock)"
        return
    }
    $recordedTime = [DateTimeOffset]::Parse($recorded)
    $elapsedHours = ([DateTimeOffset]::UtcNow - $recordedTime).TotalHours
    if ($elapsedHours -lt $Config.CoolingOffHours) {
        $remaining = [math]::Ceiling($Config.CoolingOffHours - $elapsedHours)
        $script:failures += "CriticalEvidence: $dir/second-model-review.md was recorded $([math]::Round($elapsedHours, 1))h ago — cooling-off requires $($Config.CoolingOffHours)h ($remaining h remaining, docs/sdlc/critical-delivery.md item 5)"
    }
}

# --- Gate-batching check (003 FR-008/FR-009: constitution X, Batched gates) ---
function Invoke-GateBatchingCheck {
    param([string]$Branch)
    if ($Branch -notmatch '^\d{3}-') { return }
    $dir = "specs/$Branch"
    $planPath = Join-Path $dir 'plan.md'
    if (-not (Test-Path $planPath)) { return }   # missing plan.md is StructureCheck's failure

    $line = (Get-Content $planPath | Where-Object { $_ -match '^\*\*Gate Batching\*\*:' } | Select-Object -First 1)
    if (-not $line) { return }                   # absent line means 'none' (backward compatible)

    # Strip any trailing HTML comment (the template ships one) before parsing the value.
    $value = ($line -replace '^\*\*Gate Batching\*\*:\s*', '' -replace '<!--.*$', '').Trim()
    if ($value -eq '' -or $value -eq 'none') { return }

    if ($value -notmatch '^phases\s+(\d+)\s*[-–]\s*(\d+)$') {
        $script:failures += "GateBatching: $dir/plan.md declares '**Gate Batching**: $value' — must be 'none' or 'phases N-M' (constitution X, Batched gates)"
        return
    }
    $from = [int]$matches[1]; $to = [int]$matches[2]
    if ($to -lt $from) {
        $script:failures += "GateBatching: $dir/plan.md declares 'phases $from-$to' — the span is reversed (N must not exceed M)"
        return
    }
    $span = $to - $from + 1
    if ($span -gt $Config.MaxBatchPhases) {
        $script:failures += "GateBatching: $dir/plan.md declares 'phases $from-$to' ($span phases) — a batch covers at most $($Config.MaxBatchPhases) consecutive phases (constitution X, Batched gates)"
    }

    $specPath = Join-Path $dir 'spec.md'
    if (Test-Path $specPath) {
        $level = (Get-Content $specPath | Where-Object { $_ -match '^\*\*Delivery Level\*\*:' } | Select-Object -First 1)
        if ($level -match '^\*\*Delivery Level\*\*:\s*Critical\b') {
            $script:failures += "GateBatching: $dir declares a gate batch on a Critical feature — Critical features never batch; every phase keeps its own human-executed gate (docs/sdlc/critical-delivery.md item 4)"
        }
    }
}

# --- Phase-commit diff-size warning (FR-006, non-blocking) ---
function Invoke-PhaseSizeWarningCheck {
    param([string]$Branch, [string]$Base)
    if ($Branch -notmatch '^\d{3}-') { return }
    if (-not $Base) { return }
    $commits = (git rev-list "$Base..HEAD" 2>$null) | Where-Object { $_ }
    foreach ($commit in $commits) {
        $numstat = git show --numstat --format='' $commit 2>$null
        $fileCount = 0
        $lineCount = 0
        foreach ($row in $numstat) {
            if (-not $row) { continue }
            $parts = $row -split "`t"
            if ($parts.Count -lt 3) { continue }
            $fileCount++
            if ($parts[0] -match '^\d+$') { $lineCount += [int]$parts[0] }
            if ($parts[1] -match '^\d+$') { $lineCount += [int]$parts[1] }
        }
        if ($lineCount -gt $Config.PhaseWarnLines -or $fileCount -gt $Config.PhaseWarnFiles) {
            $short = $commit.Substring(0, 7)
            $script:warnings += "PhaseSizeWarning: commit $short changes $lineCount line(s) across $fileCount file(s) — exceeds the phase-size guideline ($($Config.PhaseWarnLines) lines / $($Config.PhaseWarnFiles) files, constitution X). Non-blocking; consider whether this is one coherent slice."
        }
    }
}

# --- Dispatch ---
$Branch = Get-CurrentBranch -Override $Branch
$diffBase = Get-DiffBase
$changedFiles = Get-ChangedFiles -Base $diffBase

Write-Host "enforcement-pack: branch '$Branch', diff base '$diffBase', $($changedFiles.Count) changed file(s)"

if ($Branch -in @('main', 'master')) {
    Write-Host "enforcement-pack: '$Branch' is the trunk, not a feature/fix/chore/docs branch — no scripted checks apply"
} elseif ($Branch -match '^\d{3}-') {
    Invoke-StructureCheck -Branch $Branch
    Invoke-CriticalEvidenceCheck -Branch $Branch
    Invoke-GateBatchingCheck -Branch $Branch
    Invoke-PhaseSizeWarningCheck -Branch $Branch -Base $diffBase
} elseif ($Branch -match '^(fix|chore)/') {
    Invoke-LiteAndAbuseCheck -Branch $Branch -ChangedFiles $changedFiles
} elseif ($Branch -match '^docs/') {
    Write-Host "enforcement-pack: '$Branch' is the lightweight docs/ lane — no scripted checks apply"
} else {
    $script:failures += "Branch naming: '$Branch' does not match a known taxonomy (NNN-*, fix/*, chore/*, docs/*) — see docs/sdlc/branch-strategy.md"
}

foreach ($w in $warnings) { Write-Host "WARNING: $w" }
if ($failures.Count -gt 0) {
    Write-Host "enforcement-pack: FAIL ($($failures.Count) issue(s)):"
    foreach ($f in $failures) { Write-Host "  - $f" }
    exit 1
}
Write-Host 'enforcement-pack: OK'
exit 0

} finally {
    Pop-Location
}
