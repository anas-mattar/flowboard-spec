<#
.SYNOPSIS
    Enforcement pack: mechanically checks the kit's delivery-level non-negotiables.

.DESCRIPTION
    Converts previously-prose rules into CI-agnostic checks, run against the current
    branch's diff versus main:

      - Structure       (NNN-* branches): spec.md/plan.md/tasks.md exist; Delivery Level
                         header, when present, is filled with Lite, Micro, Standard, or
                         Critical (not the template placeholder), read from VISIBLE text
                         (a commented-out decoy never sets the lane). A Micro feature
                         requires spec.md only (constitution X, Micro lane — the
                         mini-spec is the lane's whole specification).
      - MicroLane       (NNN-* branches declared Micro): exactly one phase (distinct
                         'phase N' numbers on the branch), no plan.md/tasks.md in the
                         tree (promotion is all-or-nothing), a **Territory** block of at
                         most $Config.MicroTerritoryMaxFiles literal file entries (no
                         globs — a glob defeats the cap), at most
                         $Config.MicroPhaseMaxLines changed lines in TOTAL across the
                         phase's commits (a hard failure where other lanes get a
                         per-commit PhaseSizeWarning — summed so remediation commits
                         cannot split the bound), and no '**Gate Batching**'
                         declaration (one phase — nothing to batch). Every failure names
                         the promotion remediation (constitution X, Micro lane).
      - LiteAndAbuse     (fix/*, chore/* branches): no changed file matches a prohibited
                         category (dependency manifest, auth, schema/migration, contracts,
                         domain invariants); migrations are always prohibited on this lane
                         regardless of file count; more than $Config.AbuseGuardFileCount
                         changed files fails as well, suggesting promotion to a feature.
      - CriticalEvidence (NNN-* branches declared Critical): second-model-review.md exists
                         and was first committed at least $Config.CoolingOffHours ago.
      - PhaseSizeWarning (NNN-* branches): non-blocking warning when a single commit's
                         diff exceeds the configured line/file thresholds.
      - GateCertification (NNN-* branches): the '**Gate Certification**' declaration —
                         read from plan.md, or from spec.md when the feature is Micro
                         (the lane has no plan.md; constitution X, Micro lane) — when
                         present, must be 'user-run' or 'ci-held', and 'ci-held' is
                         prohibited on Critical features (constitution X, CI-held
                         certification; docs/sdlc/critical-delivery.md item 4). An
                         absent line means 'user-run' — plans from before the clause
                         remain valid.
      - ReviewProvenance (all recognized lanes): every specs/**/ai-code-review*.md ADDED
                         (or arriving as a rename target) in the branch's diff must carry
                         a '## Reviewer Provenance' section whose OWN Reviewer line is
                         filled and is neither the implementer nor an unfilled
                         placeholder, plus the verbatim non-implementer attestation
                         (DoD gate 5, feature 006). Pre-existing reviews at their
                         historical paths are grandfathered by construction.
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
# git emits UTF-8 paths (quotepath is disabled where needed); align pwsh's native-output
# decoding so non-ASCII filenames round-trip on Windows consoles too (phase 2 review, F2).
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch {}
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
    # Micro-lane bounds — constitutional constants (constitution X, Micro lane; sync-listed
    # in the constitution's mirror list — change only in lockstep with an amendment).
    MicroTerritoryMaxFiles  = 5
    MicroPhaseMaxLines      = 400
    MicroMaxPhases          = 1
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

# Plan-header declarations must be parsed from VISIBLE text only: a declaration hidden in
# an HTML comment block must never win first-match over the rendered one (008 phase 2
# review, F1 — a commented-out decoy could otherwise defeat the Critical exclusions of
# both Gate Batching and Gate Certification). Closed comment blocks are removed wholesale;
# the per-line trailing strip in each parser still handles the template's own same-line
# comment openings.
function Get-VisiblePlanLines {
    param([string]$PlanPath)
    $raw = "$(Get-Content -LiteralPath $PlanPath -Raw)"
    return ([regex]::Replace($raw, '(?s)<!--.*?-->', '')) -split "`r?`n"
}

# Delivery Level of a numbered feature, from spec.md's first VISIBLE '**Delivery Level**:'
# line — comment-stripped, so a commented-out 'Micro' (or 'Critical') decoy never sets the
# lane (contract M13; same rule as the plan-header parsers above). Returns the trimmed
# value string, '' when the file or the line is absent.
function Get-DeliveryLevel {
    param([string]$SpecPath)
    if (-not (Test-Path -LiteralPath $SpecPath)) { return '' }
    $line = (Get-VisiblePlanLines -PlanPath $SpecPath | Where-Object { $_ -match '^\*\*Delivery Level\*\*:' } | Select-Object -First 1)
    if (-not $line) { return '' }
    return ($line -replace '^\*\*Delivery Level\*\*:\s*', '' -replace '<!--.*$', '').Trim()
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
    $specPath = Join-Path $dir 'spec.md'
    $level = Get-DeliveryLevel -SpecPath $specPath
    # A Micro feature's whole specification is the mini-spec: spec.md alone is required
    # here; MicroLane separately fails plan.md/tasks.md PRESENCE on the lane (contract M7).
    $required = if ($level -match '^Micro\b') { @('spec.md') } else { @('spec.md', 'plan.md', 'tasks.md') }
    foreach ($f in $required) {
        $p = Join-Path $dir $f
        if (-not (Test-Path $p)) {
            $script:failures += "Structure: $dir/$f is missing (every NNN-* branch requires spec.md, plan.md, and tasks.md — or spec.md alone when declared Micro; CLAUDE.md Feature Structure)"
        }
    }
    if (Test-Path $specPath) {
        $line = (Get-VisiblePlanLines -PlanPath $specPath | Where-Object { $_ -match '^\*\*Delivery Level\*\*:' } | Select-Object -First 1)
        if (-not $line) {
            $script:failures += "Structure: $dir/spec.md has no **Delivery Level** header"
        } elseif ($level -notmatch '^(Lite|Micro|Standard|Critical)\b') {
            $script:failures += "Structure: $dir/spec.md's **Delivery Level** header is unfilled or invalid: '$level' (legal values: Lite, Micro, Standard, Critical — constitution X)"
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
    if ((Get-DeliveryLevel -SpecPath $specPath) -notmatch '^Critical\b') { return }

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

    $line = (Get-VisiblePlanLines -PlanPath $planPath | Where-Object { $_ -match '^\*\*Gate Batching\*\*:' } | Select-Object -First 1)
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

    if ((Get-DeliveryLevel -SpecPath (Join-Path $dir 'spec.md')) -match '^Critical\b') {
        $script:failures += "GateBatching: $dir declares a gate batch on a Critical feature — Critical features never batch; every phase keeps its own human-executed gate (docs/sdlc/critical-delivery.md item 4)"
    }
}

# --- Gate-certification check (008: constitution X, CI-held certification) ---
# Legal values are constitutional constants (sync-listed): 'user-run' | 'ci-held'.
# Absent line means 'user-run' (plans from before the clause remain valid). Critical
# features MUST NOT declare ci-held (constitution X; docs/sdlc/critical-delivery.md item 4).
function Invoke-GateCertificationCheck {
    param([string]$Branch)
    if ($Branch -notmatch '^\d{3}-') { return }
    $dir = "specs/$Branch"
    $specPath = Join-Path $dir 'spec.md'
    $level = Get-DeliveryLevel -SpecPath $specPath
    # On a Micro feature the mini-spec is the declaration's home — the lane has no plan.md
    # (constitution X, Micro lane; contract M9).
    $declPath = if ($level -match '^Micro\b') { $specPath } else { Join-Path $dir 'plan.md' }
    $declName = "$dir/$(Split-Path -Leaf $declPath)"
    if (-not (Test-Path $declPath)) { return }   # a missing declaration file is StructureCheck's failure

    $line = (Get-VisiblePlanLines -PlanPath $declPath | Where-Object { $_ -match '^\*\*Gate Certification\*\*:' } | Select-Object -First 1)
    if (-not $line) { return }                   # absent line means 'user-run' (backward compatible)

    # Strip any trailing HTML comment (the template ships one) before parsing the value.
    $value = ($line -replace '^\*\*Gate Certification\*\*:\s*', '' -replace '<!--.*$', '').Trim()
    if ($value -eq '' -or $value -eq 'user-run') { return }

    if ($value -ne 'ci-held') {
        $script:failures += "GateCertification: $declName declares '**Gate Certification**: $value' — must be 'user-run' or 'ci-held' (constitution X, CI-held certification)"
        return
    }

    if ($level -match '^Critical\b') {
        $script:failures += "GateCertification: $dir declares '**Gate Certification**: ci-held' on a Critical feature — Critical features MUST NOT use CI-held certification; every certifying gate stays human-executed, locally (constitution X, CI-held certification; docs/sdlc/critical-delivery.md item 4)"
    }
}

# --- Micro-lane check (009: constitution X, Micro lane) ---
# Applies only when spec.md's VISIBLE Delivery Level is Micro (a commented-out decoy never
# sets the lane — contract M13). The bounds are constitutional constants ($Config above);
# every failure names the promotion remediation. Reads the branch's CURRENT tree state, so
# a promoted branch (level re-declared Standard) exits these rules from the promotion
# commit onward (contract M11) — scope-check separately attributes each historical commit
# against its parent's declaration.
function Invoke-MicroLaneCheck {
    param([string]$Branch, [string]$Base)
    if ($Branch -notmatch '^\d{3}-') { return }
    $dir = "specs/$Branch"
    $specPath = Join-Path $dir 'spec.md'
    if ((Get-DeliveryLevel -SpecPath $specPath) -notmatch '^Micro\b') { return }
    $promote = 'promote to Standard — expand spec.md to the full template (level re-declared Standard), add plan.md + tasks.md (Territory moves there), in a commit before the next phase commit (constitution X, Micro lane)'

    # Halfway promotion is illegal: the full set arrives together or not at all (M7).
    foreach ($f in @('plan.md', 'tasks.md')) {
        if (Test-Path (Join-Path $dir $f)) {
            $script:failures += "MicroLane: $dir/$f exists while spec.md still declares Micro — promotion is all-or-nothing; $promote"
        }
    }

    # One phase means nothing to batch (M8).
    $batchLine = (Get-VisiblePlanLines -PlanPath $specPath | Where-Object { $_ -match '^\*\*Gate Batching\*\*:' } | Select-Object -First 1)
    if ($batchLine) {
        $script:failures += "MicroLane: $dir/spec.md declares '**Gate Batching**' — a Micro feature is exactly one phase; there is nothing to batch (constitution X, Micro lane); delete the line, or $promote"
    }

    # Territory cap (M5). Same block grammar scope-check parses; entries must be literal
    # file paths — one glob or subtree entry would defeat the file cap outright.
    $tEntries = @()
    $tMarkers = 0
    $collecting = $false; $started = $false
    foreach ($line in (Get-VisiblePlanLines -PlanPath $specPath)) {
        if ($line -match '^\*\*Territory\*\*:') { $tMarkers++; $collecting = $true; $started = $false; continue }
        if (-not $collecting) { continue }
        if ($line -match '^\s*$') { if ($started) { $collecting = $false }; continue }
        if ($line -match '^\s*[-*]\s+`([^`]+)`\s*$') { $started = $true; $tEntries += $matches[1].Trim(); continue }
        $collecting = $false
    }
    if ($tMarkers -gt 1) {
        # scope-check FAILs duplicates too — kept aligned so the two scripts never diverge
        # on the same spec (phase 2 review, F7).
        $script:failures += "MicroLane: $dir/spec.md carries $tMarkers **Territory** markers — a Micro feature declares exactly one feature-global block; merge them, or $promote"
    }
    if ($tEntries.Count -gt $Config.MicroTerritoryMaxFiles) {
        $script:failures += "MicroLane: $dir/spec.md declares $($tEntries.Count) territory entries — a Micro feature's Territory covers at most $($Config.MicroTerritoryMaxFiles) files (constitution X, Micro lane); shrink the territory, or $promote"
    }
    foreach ($e in $tEntries) {
        if ($e -match '\*' -or $e -match '/\s*$') {
            $script:failures += "MicroLane: territory entry '$e' in $dir/spec.md is a glob or subtree — Micro territory entries must be literal file paths, or the $($Config.MicroTerritoryMaxFiles)-file cap is unenforceable; list the files, or $promote"
        }
    }

    # Exactly one phase (M6) + the hard size bound (M12 — PhaseSizeWarning stays a
    # non-blocking per-commit warning on every other lane). Distinct phase NUMBERS are
    # counted, not commits, so in-phase remediation commits ('phase 1 fixes: …') stay
    # legal exactly as they are on Standard features — but their lines COUNT: the bound
    # is the phase's TOTAL across every commit carrying its token, so splitting a change
    # over remediation commits cannot defeat it (phase 2 review, F1 — owner-resolved
    # 2026-09-09; constitution X wording matches).
    if (-not $Base) { return }
    $phaseNums = @{}
    $phaseTotal = 0
    $phaseCommitCount = 0
    $commits = (git rev-list --no-merges "$Base..HEAD" 2>$null) | Where-Object { $_ }
    foreach ($commit in $commits) {
        $subject = (git log -1 --format=%s $commit 2>$null)
        if ($subject -notmatch '(?i)\bphase\s+(\d+)\b') { continue }
        $phaseNums[[int]$matches[1]] = $true
        $phaseCommitCount++
        $numstat = git show --numstat --format='' $commit 2>$null
        foreach ($row in $numstat) {
            if (-not $row) { continue }
            $parts = $row -split "`t"
            if ($parts.Count -lt 3) { continue }
            if ($parts[0] -match '^\d+$') { $phaseTotal += [int]$parts[0] }
            if ($parts[1] -match '^\d+$') { $phaseTotal += [int]$parts[1] }
        }
    }
    if ($phaseTotal -gt $Config.MicroPhaseMaxLines) {
        $script:failures += "MicroLane: the phase's $phaseCommitCount commit(s) change $phaseTotal line(s) in total — a Micro phase changes at most $($Config.MicroPhaseMaxLines) lines across all its commits, a hard bound on this lane (constitution X, Micro lane); shrink the change, or $promote"
    }
    if ($phaseNums.Keys.Count -gt $Config.MicroMaxPhases) {
        $nums = ($phaseNums.Keys | Sort-Object) -join ', '
        $script:failures += "MicroLane: the branch carries commits for phases $nums — a Micro feature has exactly $($Config.MicroMaxPhases) phase; $promote"
    }
}

# --- Review-provenance check (006 FR-006: DoD gate 5, reviewer separation) ---
# Inspects only AI-review files ADDED in the branch's diff vs base (--diff-filter=A), so
# reviews shipped before the verification pack — and every adopted project's history —
# are grandfathered automatically (006 research D4). Templates are exempt.
function Invoke-ReviewProvenanceCheck {
    param([string]$Branch, [string]$Base)
    if (-not $Base) { return }
    # Runs on every recognized lane (self-scoping via the diff filter) so a review file
    # cannot be smuggled in through fix/chore/docs branches (phase 2 review, F7).
    # AR filter: rename TARGETS are inspected like additions — moving a grandfathered
    # review into the feature is not legitimate grandfathering (phase 2 review, F3).
    # quotepath=off so non-ASCII filenames cannot dodge the pattern (phase 2 review, F2).
    $rows = git -c core.quotepath=off diff --name-status --diff-filter=AR $Base HEAD 2>$null
    $candidates = @()
    foreach ($row in $rows) {
        if (-not $row) { continue }
        $parts = $row -split "`t"
        if ($parts.Count -lt 2) { continue }
        $target = if ($parts[0] -match '^R' -and $parts.Count -ge 3) { $parts[2] } else { $parts[1] }
        if ($target -match '^specs/' -and $target -notmatch '^specs/_templates/' -and $target -match 'ai-code-review[^/]*\.md$') {
            $candidates += $target
        }
    }
    $attestation = 'This reviewer did not produce the diff under review.'
    foreach ($file in $candidates) {
        if (-not (Test-Path -LiteralPath $file)) {
            $script:failures += "ReviewProvenance: $file is in the branch diff but missing from the working tree — cannot verify provenance (fail-closed)"
            continue
        }
        $content = Get-Content -LiteralPath $file -Raw
        if ($content -notmatch '(?m)^##\s+Reviewer Provenance') {
            $script:failures += "ReviewProvenance: $file has no '## Reviewer Provenance' section — the AI review must be produced by a fresh-context agent or second model and say so (DoD gate 5; specs/_templates/ai-code-review-template.md)"
            continue
        }
        # Inspect ONLY the provenance section: the template's document header also carries
        # a '**Reviewer**:' field, which must never shadow the block's (phase 2 review, F1).
        $slice = if ($content -match '(?ms)^##\s+Reviewer Provenance\s*$(.*?)(?=^##\s|\z)') { $matches[1] } else { '' }
        $reviewerLine = $slice -split "`n" | Where-Object { $_ -match '^\s*[-*]?\s*\*\*Reviewer\*\*:\s*(\S.*)$' } | Select-Object -First 1
        $reviewerValue = if ($reviewerLine -match '\*\*Reviewer\*\*:\s*(.+)$') { $matches[1].Trim() } else { '' }
        if (-not $reviewerValue) {
            $script:failures += "ReviewProvenance: $file has no filled '**Reviewer**:' line inside its Reviewer Provenance section"
        } elseif ($reviewerValue -match '^(?i)implementer\b' -or $reviewerValue -match '^\[') {
            $script:failures += "ReviewProvenance: $file attests '$reviewerValue' as reviewer — the implementing agent must not review its own diff, and template placeholders must be filled (DoD gate 5)"
        }
        if ($content -notmatch [regex]::Escape($attestation)) {
            $script:failures += "ReviewProvenance: $file is missing the verbatim attestation sentence '$attestation'"
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
    Invoke-MicroLaneCheck -Branch $Branch -Base $diffBase
    Invoke-CriticalEvidenceCheck -Branch $Branch
    Invoke-GateBatchingCheck -Branch $Branch
    Invoke-GateCertificationCheck -Branch $Branch
    Invoke-ReviewProvenanceCheck -Branch $Branch -Base $diffBase
    Invoke-PhaseSizeWarningCheck -Branch $Branch -Base $diffBase
} elseif ($Branch -match '^(fix|chore)/') {
    Invoke-LiteAndAbuseCheck -Branch $Branch -ChangedFiles $changedFiles
    Invoke-ReviewProvenanceCheck -Branch $Branch -Base $diffBase
} elseif ($Branch -match '^docs/') {
    Invoke-ReviewProvenanceCheck -Branch $Branch -Base $diffBase
    Write-Host "enforcement-pack: '$Branch' is the lightweight docs/ lane — review-provenance is the only scripted check that applies"
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
