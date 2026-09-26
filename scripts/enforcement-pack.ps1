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
      - CriticalEvidence (NNN-* branches declared Critical): the independence evidence
                         docs/sdlc/critical-delivery.md item 5 requires, in one of two
                         MODES selected by the 'developers' array in kit-adoption.json.
                         SOLO (one developer declared, or nothing usable declared):
                         second-model-review.md exists and was first committed at least
                         $Config.CoolingOffHours ago — the solo substitute, unchanged.
                         TEAM (two or more declared): human-pr-review.md carries a filled
                         '## Review Provenance' block naming a Reviewer who is not the
                         Owner, plus the verbatim attestation; no cooling-off applies,
                         because the independence is real rather than substituted.
                         Absence of any kind selects SOLO — the stricter branch — so a
                         project that declares nothing keeps the behaviour it has today.
                         The team artifact is read from the COMMITTED blob, never the
                         working tree: uncommitted edits are not evidence.
                         How strong is TEAM? Two names written by the same team, in one
                         file: it converts a silent omission into a written claim a human
                         reviewer can falsify, and it is worth exactly that much — the
                         strength of the Reviewer Provenance block, no more (FR-007). The
                         declared roster is COUNTED to pick the mode and is never compared
                         against either name.
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

    THE UNGRADED STATE (feature 015, FR-009/FR-022). A check in this pack can RUN AND FORM NO
    OPINION: there is no integration branch to diff against (a shallow clone is the usual
    cause), or the commit range it was handed holds no commits. That is not a pass. It is not
    a failure either - but AmendmentAuthority, the one check that must never be silent about an
    amendment, FAILS rather than going ungraded on a missing base, on a shallow clone, and on
    commits it cannot read. Such a check adds a line to
    $ungraded, every one of those lines is printed as 'UNGRADED: <what>', and the run ends on
    'enforcement-pack: UNGRADED (N check(s) formed no opinion)' instead of 'OK'.

    It is a VERDICT change and not an exit-code change: the run still exits 0, deliberately and
    on the record (feature 015 plan D6, FR-011), because feature 014's FR-009 forbids a new hard
    failure on the Lite lane and that constraint stands. What changes is that nobody can read
    such a run as clean. Whether UNGRADED should ever block is a later feature's question, with
    its own evidence; it is not answered here by the back door.

    A run can be both FAIL and ungraded. The UNGRADED lines are printed before the verdict and
    independently of it, the way warnings are, because a reader needs to know that the failure
    count is not the whole story. The word for the whole vocabulary — OK, FAIL, WARN, N/A,
    UNGRADED, PENDING — is defined once, in scripts/ritual-checks.ps1.

    See specs/002-enforcement-pack/research.md for the rationale behind every default below.

.EXAMPLE
    pwsh -File scripts/enforcement-pack.ps1
    pwsh -File scripts/enforcement-pack.ps1 -Branch fix/my-branch
#>
[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [string]$Branch,
    # ANALYSIS ONLY (014 plan D2c): lift the amendment-authority boundary so the check grades
    # commits made before it existed. Used to replay the check over real history (SC-002).
    # No gate, no CI workflow and no ritual-checks invocation passes this — enforcement stays
    # bounded by D2b. Passing it in a gate would grade commits nobody could have complied with.
    [switch]$IgnoreAmendmentBoundary,
    # ANALYSIS ONLY (014 plan D2c), like -IgnoreAmendmentBoundary: grade an explicit commit
    # range instead of the branch's own. Used to replay the amendment check over history it
    # does not govern (SC-002, SC-004). No gate, CI workflow or ritual-checks invocation
    # passes these; with both empty the check reads the branch exactly as before.
    [string]$ReplayBase,
    [string]$ReplayTip
)

$ErrorActionPreference = 'Stop'
# git emits UTF-8 paths (quotepath is disabled where needed); align pwsh's native-output
# decoding so non-ASCII filenames round-trip on Windows consoles too (phase 2 review, F2).
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch {}
$Root = (Resolve-Path $Root).Path
. (Join-Path $PSScriptRoot 'adoption-lib.ps1')
# Territory parsing comes from the same file scope-check.ps1 uses (feature 015, T020a).
# It used to be a copy here, and phase 2 widened one and not the other: a decorated marker
# left the Micro file cap, the duplicate check and the glob check all passing vacuously
# while scope-check enforced the very same block. Nothing in this file may parse that
# marker again.
. (Join-Path $PSScriptRoot 'scope-lib.ps1')
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
# The third accumulator, and the one this feature exists to add. A member appends here when it
# RAN AND FORMED NO OPINION - not a pass, not a warning, and not 'does not apply'. See the
# verdict vocabulary in scripts/ritual-checks.ps1. It never changes the exit code (plan D6).
$ungraded = @()

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
            # No .Trim() on the bare call: `merge-base` prints nothing when the two histories
            # share no commit — a truncated clone that still carries origin/main — and the
            # method call on null killed the whole pack before any member ran.
            $base = @(git merge-base HEAD $c 2>$null | Where-Object { $_ })
            if ($LASTEXITCODE -eq 0 -and $base.Count -gt 0) { return $base[0].Trim() }
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

# The evidence mode comes from scripts/adoption-lib.ps1, dot-sourced above, so this check and
# the adoption doctor read the record through the SAME function. They were two copies until
# phase 5 and drifted twice inside one feature (013 phase 4 re-review, docs NEW-1).
function Get-EvidenceMode { return (Get-DeveloperMode -Root $Root) }

# --- Critical-evidence check (FR-005; modes added by 013) ---
function Invoke-CriticalEvidenceCheck {
    param([string]$Branch)
    if ($Branch -notmatch '^\d{3}-') { return }
    $dir = "specs/$Branch"
    $specPath = Join-Path $dir 'spec.md'
    if (-not (Test-Path $specPath)) { return }
    if ((Get-DeliveryLevel -SpecPath $specPath) -notmatch '^Critical\b') { return }

    $mode = Get-EvidenceMode
    if ($mode.Mode -eq 'team') {
        Invoke-CriticalTeamEvidence -Dir $dir -Why $mode.Why
    } else {
        Invoke-CriticalSoloEvidence -Dir $dir
    }
}

# SOLO: the substitute. Moved verbatim from the pre-013 check — same order, same
# conditions, same message strings, so a solo project cannot tell this feature happened.
function Invoke-CriticalSoloEvidence {
    param([string]$Dir)
    $reviewPath = Join-Path $Dir 'second-model-review.md'
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

# TEAM: the real thing rather than the substitute — item 5's actual requirement, that the
# human reviewer is not the feature's owner. No cooling-off: the period exists to give a
# solo developer distance from their own work, and a second person already is that.
#
# Three parsing rules, each of which a phase-3 fresh-context review demonstrated was needed:
#   1. The file must be COMMITTED. A Critical feature cannot use ci-held, so its authoritative
#      gate is a human's local run — precisely where an untracked file on one developer's disk
#      would otherwise satisfy the only machine enforcement of item 5. The solo arm has always
#      had this guard; the team arm shipped without it (logic review, BLOCKING 1).
#   2. HTML comments are stripped FIRST, including an unterminated one, because that is what a
#      renderer does. A provenance block wrapped in <!-- --> renders as nothing and used to
#      pass — contract M13's rule, which Get-VisiblePlanLines already states, applied here
#      (logic review, BLOCKING 2).
#   3. Both names AND the attestation are read from inside the section slice only. The document
#      header carries its own '**Reviewer**:' field (006 phase-2 F1), and matching the
#      attestation against the whole file let it be satisfied from an unrelated comment.
#
# The roster in kit-adoption.json is COUNTED and nothing more: it selects the mode, and is
# never compared against Reviewer or Owner. A review naming two people who are not in the
# roster passes. That limit is deliberate and recorded rather than hidden — cross-checking
# free-text names against a free-text roster would read as verification while providing none.
function Invoke-CriticalTeamEvidence {
    param([string]$Dir, [string]$Why)
    $attestation = 'This reviewer is not the owner of the feature under review.'
    $reviewPath = Join-Path $Dir 'human-pr-review.md'

    if (-not (Test-Path -LiteralPath $reviewPath)) {
        $script:failures += "CriticalEvidence: $Dir/human-pr-review.md is missing — team mode ($Why) requires the independent human review itself, not the solo substitute (docs/sdlc/critical-delivery.md item 5)"
        return
    }
    # Read the COMMITTED blob, not the working tree. A history check alone only proved the
    # PATH was committed: copy the template in early, fill it locally at review time, never
    # commit, and the check passed on content the branch does not carry (013 phase 4
    # re-review, N1). Critical forbids ci-held, so the authoritative gate is the human's
    # local run — the one place that hole mattered most.
    # $Dir is built with forward slashes ("specs/$Branch"), which is what git wants — no
    # separator translation, and therefore no regex to get wrong.
    # The './' matters. Without it git resolves HEAD:<path> against the REPOSITORY root, while
    # every other path here is relative to $Root — so a governance repo living in a
    # subdirectory reported a correctly committed review as uncommitted. With it, git resolves
    # against the current directory, which Push-Location $Root already set (013 phase 5
    # review, NEW-A). Exit code alone decides: a committed but EMPTY file yields $null and
    # must not be called uncommitted (NEW-C) — it fails the section check instead, correctly.
    $blob = (git show "HEAD:./$Dir/human-pr-review.md" 2>$null)
    if ($LASTEXITCODE -ne 0) {
        $script:failures += "CriticalEvidence: $Dir/human-pr-review.md is not committed — evidence that exists only in a working tree is not evidence (commit it; FR-006 requires the identities to be read from committed artifacts)"
        return
    }
    $content = ConvertTo-VisibleText -Text ($blob -join "`n")
    if ($content -notmatch '(?m)^##\s+Review Provenance') {
        $script:failures += "CriticalEvidence: $Dir/human-pr-review.md has no visible '## Review Provenance' section — team mode ($Why) needs the reviewer and owner named in the review itself (specs/_templates/human-pr-review-template.md). Content inside an HTML comment does not count, and an UNTERMINATED '<!--' anywhere earlier in the file hides everything after it — check for a comment missing its '-->'"
        return
    }
    $slice = if ($content -match '(?ms)^##\s+Review Provenance\s*$(.*?)(?=^##\s|\z)') { $matches[1] } else { '' }
    # Code inside the section is illustration, not a declaration — in every form it can take:
    # backtick fences, tilde fences, and 4-space-indented blocks (013 phase 3 review NIT 7,
    # phase 4 re-review N3, which found the first fix caught only the backtick form).
    $slice = [regex]::Replace($slice, '(?ms)^(?:```|~~~).*?(^(?:```|~~~)|\z)', '')
    # An indented code block requires a preceding blank line; 4 spaces INSIDE a list is a
    # nested item, not code, and dropping those lines hid legitimate values (013 phase 5
    # review, NEW-B). Only strip an indented run that opens after a blank line.
    $sliceLines = $slice -split "`n"
    $kept = [System.Collections.Generic.List[string]]::new()
    $inIndentedCode = $false
    for ($i = 0; $i -lt $sliceLines.Count; $i++) {
        $line = $sliceLines[$i]
        $isIndented = $line -match '^(?: {4,}|	)\S'
        if ($isIndented -and -not $inIndentedCode) {
            $prev = if ($i -gt 0) { $sliceLines[$i - 1] } else { '' }
            $inIndentedCode = [string]::IsNullOrWhiteSpace($prev)
        } elseif (-not $isIndented -and -not [string]::IsNullOrWhiteSpace($line)) {
            $inIndentedCode = $false
        }
        if (-not ($isIndented -and $inIndentedCode)) { $kept.Add($line) }
    }
    $slice = $kept -join "`n"

    $reviewer = Get-ProvenanceValue -Slice $slice -Field 'Reviewer'
    $owner = Get-ProvenanceValue -Slice $slice -Field 'Owner'

    # A bare [bracketed] value is the template placeholder; '[Name](mailto:...)' is a
    # perfectly ordinary markdown link and must not be mistaken for one (logic review, NIT 6).
    $placeholder = '^\[[^\]]*\]\s*$'
    foreach ($pair in @(@{ N = 'Reviewer'; V = $reviewer }, @{ N = 'Owner'; V = $owner })) {
        if (-not $pair.V) {
            $script:failures += "CriticalEvidence: $Dir/human-pr-review.md has no filled '**$($pair.N)**:' line inside its Review Provenance section (team mode — $Why)"
        } elseif ($pair.V -match $placeholder) {
            $script:failures += "CriticalEvidence: $Dir/human-pr-review.md leaves '**$($pair.N)**: $($pair.V)' as a template placeholder — team mode ($Why) needs the actual name"
        }
    }
    if ($reviewer -and $owner -and $reviewer -notmatch $placeholder -and $owner -notmatch $placeholder) {
        if ($reviewer -ieq $owner) {
            $script:failures += "CriticalEvidence: $Dir/human-pr-review.md names '$reviewer' as both reviewer and owner — the human reviewer of a Critical feature MUST NOT be its owner (docs/sdlc/critical-delivery.md item 5; docs/sdlc/team-workflow.md rule 4)"
        }
    }
    if ($slice -notmatch [regex]::Escape($attestation)) {
        $script:failures += "CriticalEvidence: $Dir/human-pr-review.md is missing the verbatim attestation sentence '$attestation' from its Review Provenance section (team mode — $Why)"
    }
}

# A file as a reader sees it: HTML comments removed, closed ones first and then an
# UNTERMINATED '<!--' through to end of file — a renderer swallows the rest of the document,
# so a check that keeps reading is reading text nobody can see. Get-VisiblePlanLines applies
# the same rule line-wise for plan headers (contract M13); this returns whole text because
# the provenance parser needs to slice sections out of it.
function ConvertTo-VisibleText {
    param([string]$Text)
    $stripped = [regex]::Replace($Text, '(?s)<!--.*?-->', '')
    # Ordinal: the culture-sensitive overload can match a marker a renderer never sees — a
    # soft hyphen inside '<!--' is enough (013 phase 4 re-review, N4).
    $dangling = $stripped.IndexOf('<!--', [StringComparison]::Ordinal)
    if ($dangling -ge 0) { $stripped = $stripped.Substring(0, $dangling) }
    return $stripped
}

function Get-ProvenanceValue {
    param([string]$Slice, [string]$Field)
    $line = $Slice -split "`n" | Where-Object { $_ -match "^\s*[-*]?\s*\*\*$Field\*\*:\s*(\S.*)$" } | Select-Object -First 1
    if ($line -match "\*\*$Field\*\*:\s*(.+)$") { return $matches[1].Trim() }
    return ''
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

    # Territory cap (M5). The block is parsed by scope-lib's Get-Territory — the SAME function
    # scope-check.ps1 uses — because this was a copy of that grammar until T020a, and a copy of a
    # parser is a parser that drifts: phase 2 widened the original to accept a decorated marker
    # and left this one strict, so a Micro spec could break the file cap while reporting OK.
    # Entries must still be literal file paths; one glob or subtree entry defeats the cap outright.
    $territory = Get-Territory -TasksLines (Get-VisiblePlanLines -PlanPath $specPath) -Global
    $tEntries = @($territory.Entries)
    $tMarkers = $territory.MarkerCount
    if ($territory.NearMiss.Count -gt 0) {
        # A line that starts like a declaration and breaks the grammar FAILs rather than vanishing
        # (feature 015, T019a in scope-check and T020a here — the two graders say the same thing
        # about the same malformed line).
        foreach ($nm in $territory.NearMiss) {
            $script:failures += "MicroLane: $dir/spec.md line $nm begins '**Territory**' but has no ':' on that line — an annotation that wraps declares nothing the parser can see; keep the marker and its colon on one line"
        }
    }
    if ($tMarkers -gt 1) {
        # scope-check FAILs duplicates too — kept aligned so the two scripts never diverge
        # on the same spec (phase 2 review, F7). They now share the parser, so they cannot.
        $script:failures += "MicroLane: $dir/spec.md carries $tMarkers **Territory** markers — a Micro feature declares exactly one feature-global block; merge them, or $promote"
    }
    foreach ($bad in @($territory.Invalid)) {
        # Get-Territory routes an absolute or '..' entry to Invalid, NOT to Entries. Sharing the
        # parser in T020a therefore did something the task did not intend: an escaping entry
        # stopped counting toward the file cap and was reported by nobody, while scope-check.ps1
        # — the same function, the same block — FAILs it. That is the divergence T020a exists to
        # remove, reappearing one field over, so the caller reads the field rather than the task
        # being called done. Reporting is enough: no spec carrying one can reach the cap check
        # green, so the under-count cannot be spent.
        $script:failures += "MicroLane: territory entry '$bad' in $dir/spec.md is not repo-relative — Micro territory entries must be repo-relative paths with no '..'; scope-check.ps1 FAILs the same entry in the same block; fix the entry, or $promote"
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
    if (-not $Base) {
        $script:ungraded += "MicroLane: no diff base, so the phase walk enforcing 'exactly one phase' and the line bound compared nothing on '$Branch'"
        return
    }
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
    # GAP-027, and the reason this feature has a phase 5. This used to be a bare `return`: the
    # machine half of gate 5 stopped before listing a single candidate, and the run still printed
    # OK. An AI review with no provenance section rode through on a depth-1 clone, the ordinary
    # actions/checkout shape. It still does not FAIL - FR-011 forbids a new hard failure on the
    # Lite lane - but the verdict can no longer be read as a graded pass.
    if (-not $Base) {
        $script:ungraded += "ReviewProvenance: no diff base, so no review file on '$Branch' was inspected - the machine half of DoD gate 5 formed no opinion. Fetch the full history ('fetch-depth: 0' on actions/checkout)"
        return
    }
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
    if (-not $Base) {
        $script:ungraded += "PhaseSizeWarning: no diff base, so no commit on '$Branch' was measured against the phase-size guideline"
        return
    }
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

# --- Amendment-authority check (014 FR-004; constitution I, Amendment authority) ---
# Grades commits, not the cumulative diff (plan D1): the record lives in a commit's diff AND
# its message, and a cumulative diff has no messages and cannot tell an amendment from a
# creation that was later edited.
#
# Bounded by plan D2b: a commit is graded only if THIS CHECK existed before that commit was
# made. Nothing earlier is graded, here or in an adopted project — so the update that delivers
# the check is silent, and no in-flight branch turns red at once. The boundary is not a
# convenience: D5 puts half of every record in an immutable commit message, so a retroactive
# rule would be one nobody could comply with.
$script:AmendmentRecordPattern = '^\*\*Amendment approved by\*\*:\s*(.+?)\s*,\s*(\d{4}-\d{2}-\d{2})\s*\.?\s*$'
$script:AmendmentRecordExample = '**Amendment approved by**: <name>, <YYYY-MM-DD>'

# --- Plumbing batches (phase 3, T024 / SC-006) --------------------------------------------
# The check's cost is dominated by CHILD PROCESSES, not by the work inside them. Measured on
# this branch, the per-commit shape of D1 asked git 66 questions — three quarters of every git
# call the whole pack made, and about a third of `ritual-checks`. Each batch below asks ONE
# question whose answer covers the range. None of them changes WHAT is graded: per-commit
# granularity is what makes D5's message test possible and it is untouched (plan, Complexity
# Tracking: "batch the plumbing calls, not the granularity").
$script:GitRS = [string][char]30   # ASCII record separator — line marker only, never a record split
$script:GitFS = [string][char]31   # ASCII unit separator

# sha -> @{ Parents; Day; Body; Trailers } for every commit in the range, in one git call.
# Replaces one `rev-list --parents -n 1` per commit plus three `show -s` calls per amendment.
#
# Records are separated by NUL (`-z`), not by a C0 byte picked for rarity. git REFUSES a NUL in
# a commit log message ("error: a NUL byte in commit log message not allowed") and carries 0x1E
# through untouched, so the old 0x1E split was injectable: one byte in a message deleted that
# commit from the graded set AND from the count's denominator, and a crafted record overwrote an
# earlier commit's parentage so it was skipped as a root (review B1).
#
# Field order is part of the fix. The two message-derived fields come LAST and the split is
# capped at five, so an injected 0x1F can only truncate them — never shift the sha, the parents
# or the date. Every corruption still reachable here loses message text, and losing message text
# can only make the D5 name test fail, never pass.
function Get-CommitMetaBatch {
    param([string]$Range)
    $fmt = "%H$script:GitFS%P$script:GitFS%ad$script:GitFS%B$script:GitFS%(trailers:only)"
    $raw = (@(git log -z --reverse --date=short --format=$fmt $Range 2>$null) -join "`n")
    $meta = [ordered]@{}
    foreach ($rec in ($raw -split "`0")) {
        if (-not $rec.Trim()) { continue }
        $f = $rec -split $script:GitFS, 5
        if ($f.Count -lt 5) { continue }
        $meta[$f[0].Trim()] = @{
            Parents  = @($f[1].Trim() -split '\s+' | Where-Object { $_ })
            Day      = $f[2].Trim()
            Body     = @($f[3] -split "`r?`n")
            Trailers = @($f[4] -split "`r?`n" | Where-Object { $_.Trim() })
        }
    }
    return $meta
}

# sha -> the commit's raw name-status rows, for every commit in the range, in one git call.
# Merge commits produce no rows here exactly as `git show --name-status` produced none; D7
# discards them before this is read, so the two agree by construction.
function Get-NameStatusBatch {
    param([string]$Range)
    $map = @{}
    $current = $null
    # quotepath=off so a non-ASCII path arrives verbatim rather than quoted-octal: quoted, it
    # fails the "$dir/*" filter and the document is never graded at all (review B2). The pack
    # already carries this at scripts/scope-lib.ps1 (006 F3) and at line 577 (phase 2 F2); this
    # reader was the one that did not.
    foreach ($line in @(git -c core.quotepath=off log --reverse --format="$script:GitRS%H" --name-status $Range 2>$null)) {
        # ORDINAL comparison, deliberately. String.StartsWith defaults to a CULTURE-SENSITIVE
        # comparison that treats a control character as ignorable, so every line — including
        # the empty ones — "starts with" the record separator and the parse collapses.
        if ($line.Length -gt 0 -and $line[0] -eq [char]30) {
            $current = $line.Substring(1).Trim()
            $map[$current] = @()
            continue
        }
        if (-not $current -or -not $line) { continue }
        $map[$current] += $line
    }
    return $map
}

# A ref is pre-boundary only if the check is provably absent from a tree we could actually read.
# `git grep` exits 1 both for "searched it, no match" and for "could not read the blob" — it
# prints the error to stderr and exits 1 either way — so B3's `>= 2` guard never fires for an
# unreadable object and absence from the presence set is not evidence of absence. Measured on a
# fixture whose blob was deleted: the check graded 0 of 2 commits, let an unapproved amendment
# through, and reported "made before the check existed" about a tree that contained it (T080).
function Test-CheckAbsentForReal {
    param([string]$Ref)
    git cat-file commit "${Ref}^{commit}" *> $null
    if ($LASTEXITCODE -ne 0) { return $false }                       # the commit itself is gone
    $entry = @(git ls-tree --name-only "$Ref" -- 'scripts/enforcement-pack.ps1' 2>$null)
    if ($LASTEXITCODE -ne 0) { return $false }
    if (@($entry | Where-Object { $_ }).Count -eq 0) { return $true } # the script did not exist yet
    # Read the whole object, because anything less answers a different question (review G1).
    # `-e` asks only whether the store names it: exit 0 on a corrupt blob and on a truncated
    # one. `-s` inflates the HEADER only: still exit 0 on an object truncated mid-body, where
    # `git grep` exits 128. Only inflating the body fails wherever a reader fails — measured
    # across all three damage modes (deleted / garbage / truncated) at no measurable cost.
    # Stdout is suppressed as well as stderr: the content would otherwise join this function's
    # output stream and return an array whose truthiness is not the boolean the caller tests.
    git cat-file blob "${Ref}:scripts/enforcement-pack.ps1" *> $null
    return ($LASTEXITCODE -eq 0)                                     # readable and without it
}

# The set of refs that already carry the check (D2b), in one git call. `git grep` searches many
# trees at once and prints '<rev>:<path>' per hit, so the boundary question that cost one 39 KB
# blob read per ungraded commit now costs one process for the whole branch. Self-bootstrapping,
# as the per-ref version was: the test is whether that tree's copy of THIS script defines the
# check function.
function Get-CheckPresenceSet {
    param([string[]]$Refs)
    $set = @{}
    $unique = @($Refs | Where-Object { $_ } | Sort-Object -Unique)
    if ($unique.Count -eq 0) { return $set }
    # Chunked and error-checked, because this batch had two ways to come back empty without
    # saying so, and an empty presence set grades NOTHING while printing exactly what a
    # legitimately pre-boundary branch prints — J2's fail-open shape with a new trigger
    # (review B3). (a) `git grep` aborts the WHOLE search on one unresolvable ref (exit >= 2:
    # a shallow or partial clone, a grafted history, a missing object); (b) ~41 bytes per sha
    # against a 32 767-byte Windows command line puts the ceiling near 700 refs in one call.
    # On an error exit the pre-batching per-ref probe runs for that chunk: slower, never silent.
    for ($i = 0; $i -lt $unique.Count; $i += 200) {
        $chunk = @($unique[$i..([Math]::Min($i + 199, $unique.Count - 1))])
        $hits = @(git grep -l -F -e 'function Invoke-AmendmentAuthorityCheck' @chunk -- 'scripts/enforcement-pack.ps1' 2>$null)
        if ($LASTEXITCODE -ge 2) {
            foreach ($ref in $chunk) {
                $blob = @(git show "${ref}:scripts/enforcement-pack.ps1" 2>$null)
                if ($LASTEXITCODE -eq 0 -and @($blob -match 'function Invoke-AmendmentAuthorityCheck').Count -gt 0) {
                    $set[$ref] = $true
                }
            }
            continue
        }
        foreach ($hit in $hits) {
            if ($hit -match '^(.+):scripts/enforcement-pack\.ps1$') { $set[$matches[1]] = $true }
        }
    }
    return $set
}

# One blob, read at most once per run. The visibility test, the occurrence count and the
# checkbox comparison all want the same two blobs of the same tasks.md; without this they read
# each of them twice.
$script:AmendmentBlobCache = @{}
function Get-BlobLines {
    param([string]$Ref, [string]$Path)
    if (-not $Ref) { return @() }
    $key = "${Ref}:${Path}"
    if ($script:AmendmentBlobCache.ContainsKey($key)) { return $script:AmendmentBlobCache[$key] }
    $lines = @(git show $key 2>$null)
    $script:AmendmentBlobCache[$key] = $lines
    return $lines
}

# The Markdown-visibility helpers moved to scripts/markdown-lib.ps1 (feature 015, phase 2):
# build-digests.ps1 needed the same rule for GAP-025, and a copy would have to relearn
# every fix this one took. Disable-CommentMarkers, Convert-CodeSpanMarkers and
# Get-FencedLineMap arrive from there, unchanged.
. (Join-Path $PSScriptRoot 'markdown-lib.ps1')

# Visible lines of a text blob — HTML comments stripped, same rule as Get-VisiblePlanLines
# (008 phase-2 F1). Commented-out text is not law and is not a record (H1).
function Get-VisibleFromText {
    param([string[]]$Lines)
    # Markdown renders code as literal text, so a '<!--' inside a fenced block or an inline code
    # span is NOT a comment opener. Neutralise the markers inside code BEFORE the rules below.
    # Without this, T060's own description — which quotes a backticked `<!--` — made the
    # unterminated-comment rule truncate tasks.md from that line on, hiding every approver
    # record added after it. The rule became impossible to comply with in any document that
    # mentions the syntax, this feature's own included (B7, found while remediating B1-B6).
    # It fails closed, so it never passed a silent amendment — it just could not be satisfied.
    #
    # The code regions are found STRUCTURALLY, line by line (K1). The first fix used
    # '(?s)```.*?```' over the whole blob, which pairs triple-backtick runs left to right with
    # no regard for line starts: one stray fence run in prose re-paired every fence after it,
    # put a REAL comment inside a region the check called code, and made a record no reader can
    # see count as a grant — H1, reopened by its own fix.
    $raw = ($Lines -join "`n")
    # No marker anywhere means no comment anywhere: nothing to neutralise and nothing to strip.
    if ($raw -notmatch '<!--') { return $raw -split "`r?`n" }
    $fenced = Get-FencedLineMap -Lines $Lines
    $processed = [System.Collections.Generic.List[string]]::new()
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($fenced[$i]) { $processed.Add((Disable-CommentMarkers -Text $Lines[$i])) }
        else             { $processed.Add((Convert-CodeSpanMarkers -Line $Lines[$i])) }
    }
    $raw = ($processed -join "`n")
    $stripped = [regex]::Replace($raw, '(?s)<!--.*?-->', '')
    # An UNTERMINATED '<!--' hides everything after it in every renderer, so it must hide it
    # here too (J5). The pack's CriticalEvidence check already warns about this exact trap.
    $stripped = [regex]::Replace($stripped, '(?s)<!--.*$', '')
    return $stripped -split "`r?`n"
}

# Lines a commit ADDED to the given paths that are also VISIBLE in the resulting file, and
# that did not already exist in the parent (H1, H5). A record hidden in a comment renders as
# nothing; a record merely moved from elsewhere in the same file was not granted by this
# commit.
function Get-AddedRecordLines {
    param([string]$Commit, [string]$Parent, [string[]]$Paths)
    if (-not $Paths -or $Paths.Count -eq 0) { return @() }
    $result = @()
    foreach ($path in ($Paths | Sort-Object -Unique)) {
        $added = @(git show -U0 --format='' $Commit -- $path 2>$null |
            Where-Object { $_ -match '^\+' -and $_ -notmatch '^\+\+\+' } |
            ForEach-Object { $_.Substring(1) })
        if ($added.Count -eq 0) { continue }
        # Only lines that LOOK like a record can be one. Filtering first keeps the expensive
        # visibility and occurrence work proportional to the number of candidate records
        # (normally one) instead of to the size of the commit — a 600-line commit was costing
        # seconds per file before this.
        $candidates = @($added | ForEach-Object { $_.Trim() } |
            Where-Object { $_ -match $script:AmendmentRecordPattern } | Sort-Object -Unique)
        if ($candidates.Count -eq 0) { continue }
        $visCount = @{}
        foreach ($l in (Get-VisibleFromText -Lines (Get-BlobLines -Ref $Commit -Path $path))) {
            $t = $l.Trim(); if ($t) { $visCount[$t] = 1 + [int]$visCount[$t] }
        }
        $beforeCount = @{}
        foreach ($l in (Get-VisibleFromText -Lines (Get-BlobLines -Ref $Parent -Path $path))) {
            $t = $l.Trim(); if ($t) { $beforeCount[$t] = 1 + [int]$beforeCount[$t] }
        }
        foreach ($line in $candidates) {
            # H1: a line added inside a comment renders as nothing, so it is not a record.
            if (-not $visCount.ContainsKey($line)) { continue }
            # H5/J1: a record counts when the file gained one. Counting occurrences separates a
            # RECYCLED record (moved within the file — count unchanged) from a legitimately
            # REPEATED one (a second amendment, same approver, same day — count increased).
            # The previous "absent from the parent" rule could not tell those apart and rejected
            # the honest case.
            if ([int]$visCount[$line] -le [int]$beforeCount[$line]) { continue }
            $result += $line
        }
    }
    return $result
}

# D3: a tasks.md change that alters nothing but checkbox state is progress, not amendment.
# Completion state moves in EITHER direction (constitution I; review finding F2). The test is
# the text: strip the marker from every added and removed line and compare the multisets.
# D3: progress, not amendment. Compares the WHOLE FILE with every checkbox marker neutralised,
# in order — not the diff hunks (H2, J6). A tick changes markers and nothing else, so the
# neutralised files are identical. Anything that moves, adds, removes or rewords a line changes
# the neutralised sequence and is an amendment. Reasoning about whole files rather than about
# paired hunks removes a class of bug rather than another special case: a line moved between
# phase blocks while being ticked defeated hunk pairing, and could not defeat this.
function Test-CheckboxOnlyChange {
    param([string]$Commit, [string]$Parent, [string]$Path, [string]$ParentPath)
    if (-not $ParentPath) { $ParentPath = $Path }
    $neutral = { param($lines)
        $out = [System.Collections.Generic.List[string]]::new()
        foreach ($l in $lines) { $out.Add(($l -replace '^(\s*(?:[-*]|\d+\.)\s*)\[[ xX]\]', '${1}[]').TrimEnd()) }
        return $out
    }
    $nowRaw  = Get-BlobLines -Ref $Commit -Path $Path
    $thenRaw = Get-BlobLines -Ref $Parent -Path $ParentPath
    # --name-status said this path was modified, so two empty reads are a FAILED read, not an
    # unchanged file. Returning $true there would call an unreadable amendment "checkbox-only"
    # and exempt it; return $false and it is graded like any other change (review B2, rider).
    if ($nowRaw.Count -eq 0 -and $thenRaw.Count -eq 0) { return $false }
    $now  = & $neutral $nowRaw
    $then = & $neutral $thenRaw
    if ($now.Count -ne $then.Count) { return $false }
    for ($i = 0; $i -lt $now.Count; $i++) { if ($now[$i] -ne $then[$i]) { return $false } }
    return $true
}

# D3d (owner decision 2026-09-16 on review finding B5): a diff whose only change is the
# **Status** line is the act of approval, not an amendment to an approved document. The
# constitution's own scope sentence — "once a feature's spec.md or plan.md has been APPROVED" —
# puts the approval act outside the rule it starts, and the kit's spec templates MANDATE the
# edit (Draft -> Approved before the phase begins). Without this the next feature's approval
# commit turned its own branch red, which the replay demonstrated forward, not just in history.
#
# Whole-file comparison — the same shape as the checkbox exemption, and for the same reason
# (H2, J6): reasoning about paired hunks let a line moved elsewhere in the file ride along on
# an exempt change. EXACTLY ONE line may differ, and it must be the approval transition itself.
#
# The first implementation neutralised everything after '**Status**:' on every line that began
# that way, which exempted far more than the approval act (K2): a payload appended to the status
# line rode in ('Approved 2026-09-16 (owner: ada). D2 is withdrawn; ...' compared equal to the
# line without it), any '**Status**:' line qualified including one inside a fenced block or on
# an ADR sub-section, and it fired in either direction at any time. So the new value is matched
# against a bounded approval vocabulary instead of being discarded, and only the document's
# FIRST status line outside code counts. That also puts the exemption inside the constitution's
# own scope sentence rather than beside it (K3): what is exempt is the Draft -> Approved
# transition, which is the act that STARTS the rule, not a later change to an approved document.
#
# The old side is required only to BE Draft; an annotation on it ('Draft — awaiting owner
# approval', the template's trailing guidance comment) may be dropped by the approval. New text
# cannot ride in, which is the direction a payload travels; a plan that puts normative text on
# its Draft status line is already misusing the line, and this is written into plan.md D3d
# rather than left for the next reviewer to discover.
$script:StatusDraftPattern = '^\s*\*\*Status\*\*:\s*Draft\b'
$script:StatusApprovedPattern =
    '^\s*\*\*Status\*\*:\s*Approved' +
    '(?:\s+\d{4}-\d{2}-\d{2})?' +
    '(?:\s+\(owner[:,]?\s*[A-Za-z0-9._@\- ]{1,40}(?:,\s*\d{4}-\d{2}-\d{2})?\))?' +
    '(?:\s*<!--[^\r\n]*-->)?\s*$'
function Test-StatusOnlyChange {
    param([string]$Commit, [string]$Parent, [string]$Path, [string]$ParentPath)
    if (-not $ParentPath) { $ParentPath = $Path }
    $nowRaw  = Get-BlobLines -Ref $Commit -Path $Path
    $thenRaw = Get-BlobLines -Ref $Parent -Path $ParentPath
    # Two empty reads are a failed read, not an unchanged file (the B2 rider, same reasoning).
    if ($nowRaw.Count -eq 0 -and $thenRaw.Count -eq 0) { return $false }
    if ($nowRaw.Count -ne $thenRaw.Count) { return $false }
    $diffAt = -1
    for ($i = 0; $i -lt $nowRaw.Count; $i++) {
        if ($nowRaw[$i].TrimEnd() -ne $thenRaw[$i].TrimEnd()) {
            if ($diffAt -ge 0) { return $false }
            $diffAt = $i
        }
    }
    if ($diffAt -lt 0) { return $false }
    # The status line of the document is the first one Markdown RENDERS — a '**Status**:' line
    # inside a fenced block is sample text, and an ADR's or a sub-section's status is prose that
    # gets graded like any other prose.
    $nowFence  = Get-FencedLineMap -Lines $nowRaw
    $thenFence = Get-FencedLineMap -Lines $thenRaw
    $nowFirst = -1; $thenFirst = -1
    for ($i = 0; $i -lt $nowRaw.Count; $i++) {
        if (-not $nowFence[$i] -and $nowRaw[$i] -match '^\s*\*\*Status\*\*:') { $nowFirst = $i; break }
    }
    for ($i = 0; $i -lt $thenRaw.Count; $i++) {
        if (-not $thenFence[$i] -and $thenRaw[$i] -match '^\s*\*\*Status\*\*:') { $thenFirst = $i; break }
    }
    if ($nowFirst -lt 0 -or $nowFirst -ne $thenFirst -or $diffAt -ne $nowFirst) { return $false }
    return ($thenRaw[$diffAt] -match $script:StatusDraftPattern) -and
           ($nowRaw[$diffAt]  -match $script:StatusApprovedPattern)
}

# D6: an unfilled or impossible record is no record.
function Get-ConformingRecord {
    param([string[]]$AddedLines, [string]$CommitDay)
    $result = @{ Name = $null; Malformed = @() }
    foreach ($line in $AddedLines) {
        if ($line -notmatch $script:AmendmentRecordPattern) { continue }
        $name = $matches[1].Trim()
        $dateText = $matches[2]
        if (-not $name -or $name -match '^\{\{.*\}\}$' -or $name -match '^TODO\(' -or
            $name -match '^\[.*\]$' -or $name -match '^<.*>$') {
            $result.Malformed += "approver name '$name' is a placeholder, not a name"
            continue
        }
        $parsed = [datetime]::MinValue
        if (-not [datetime]::TryParseExact($dateText, 'yyyy-MM-dd',
                [globalization.cultureinfo]::InvariantCulture,
                [globalization.datetimestyles]::None, [ref]$parsed)) {
            $result.Malformed += "date '$dateText' is not a real YYYY-MM-DD date"
            continue
        }
        # String comparison of two YYYY-MM-DD values taken in the AUTHOR's own timezone (H6).
        # [datetime]::Parse of an ISO offset converts to the runner's local time, which made the
        # same commit green locally and red in CI — the machine-dependence D6 exists to forbid.
        if ($dateText -gt $CommitDay) {
            $result.Malformed += "date '$dateText' is later than the commit's own author date ($CommitDay)"
            continue
        }
        $result.Name = $name
        return $result
    }
    return $result
}

function Invoke-AmendmentAuthorityCheck {
    param([string]$Branch, [string]$Base, [switch]$IgnoreAmendmentBoundary,
          [string]$ReplayBase, [string]$ReplayTip)
    if ($Branch -notmatch '^\d{3}-') { return }
    # Silence is not compliance (phase 4 review F1). Two conditions make the boundary
    # uncomputable, and both used to `return` bare — printing nothing, exiting 0, and looking
    # exactly like a branch that is legitimately pre-boundary. Ask git directly rather than
    # inferring: a shallow clone can still resolve origin/main, so a base that looks fine says
    # nothing about whether the history behind it is present.
    if ("$(git rev-parse --is-shallow-repository 2>$null)".Trim() -eq 'true') {
        $script:failures += "AmendmentAuthority: cannot grade '$Branch' — this is a shallow clone, so the boundary (plan D2b) would be computed from history that is not present, and every commit would report as predating the check. Fetch the full history: 'fetch-depth: 0' on actions/checkout, or 'git fetch --unshallow' on a build agent (constitution I, Amendment authority)"
        return
    }
    if (-not $Base) {
        $script:failures += "AmendmentAuthority: cannot grade '$Branch' — no integration branch to diff against. Either neither 'origin/main' nor 'main' resolves here, or one of them resolves but shares no commit with HEAD (a truncated clone, or unrelated histories) — this check does not distinguish them, and says so rather than naming a cause it did not test. Fetch the full history ('git fetch origin main', 'fetch-depth: 0' on actions/checkout), or run the check where it is reachable (constitution I, Amendment authority)"
        return
    }
    $dir = "specs/$Branch"
    $range = if ($ReplayTip) { "$ReplayBase..$ReplayTip" } else { "$Base..HEAD" }
    # Three git calls now answer everything the walk below used to ask commit by commit: the
    # commits and their parents, dates, messages and trailers; every commit's name-status; and
    # which parents already carried the check (T024 — the walk itself is unchanged).
    $meta = Get-CommitMetaBatch -Range $range
    # The commit SET comes from the object graph, never from the message stream. Taking it from
    # the parsed metadata let a commit delete itself by writing one byte into its own message
    # (review B1); rev-list reads commit objects and cannot be written to from a message.
    $commits = @(git rev-list --reverse $range 2>$null | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
    if ($commits.Count -eq 0) {
        # An empty range is a check that ran and graded nothing - GAP-027's shape, and until the
        # phase 6 review (F6) it ended the run on OK. It is named, not failed: a branch with no
        # commits of its own yet is lawful, it is only not evidence (FR-010, plan D6).
        $script:ungraded += "AmendmentAuthority: no commits in $range — nothing to grade, so no amendment on '$Branch' was checked for its approval record"
        return
    }
    # A commit git lists but the batch did not parse is a parse failure, not a commit to skip.
    # Skipping silently is the whole of B1; this is the assertion whose absence made it work.
    $missing = @($commits | Where-Object { -not $meta.Contains($_) })
    if ($missing.Count -gt 0) {
        $names = ($missing | ForEach-Object { $_.Substring(0, 7) }) -join ', '
        $script:failures += "AmendmentAuthority: could not parse commit metadata for $($missing.Count) commit(s) in $range ($names) — the check refuses to grade a range it cannot read in full, because a commit missing from the batch would otherwise be silently ungraded (review B1). Re-run; if it persists the repository or the range is unreadable and the branch must not be certified on this check"
        return
    }
    # Report what was actually graded. A run that grades nothing must not be output-identical
    # to a run that grades everything and finds it clean: that silence is what let a fail-open
    # boundary (J2) and two broken fixtures pass for green.
    $gradedCount = 0
    # Counted per reason, so the count line reports what actually happened instead of naming
    # causes it never established (review N3, and B1's action on the same string).
    $skipMerge = 0; $skipRoot = 0; $skipBoundary = 0

    # D2b. The boundary is evaluated PER COMMIT against that commit's own parent. An earlier
    # version short-circuited on HEAD^ alone to save blob reads (SC-006); that failed open,
    # silently, on every pull_request run, because GitHub checks out a merge preview whose first
    # parent is the base branch — so HEAD^ was `main`, which has no check, and the required CI
    # graded nothing while printing exactly what a clean branch prints (J2). Correctness over
    # the second: the sticky flag below still stops re-testing once the boundary is crossed.
    # -IgnoreAmendmentBoundary lifts the boundary for ANALYSIS ONLY (SC-002's replay over real
    # history); no gate, no ritual-checks and no CI workflow passes it.
    $graded = $IgnoreAmendmentBoundary.IsPresent

    $nameStatus = Get-NameStatusBatch -Range $range
    # Every first parent in the range, tested in one call. The sticky flag below still decides
    # PER COMMIT whether that commit is graded — the batch changes who is asked, not what for.
    $presence = @{}
    if (-not $graded) { $presence = Get-CheckPresenceSet -Refs @($commits | ForEach-Object { @($meta[$_].Parents)[0] }) }

    foreach ($commit in $commits) {
        $parents = @($meta[$commit].Parents)
        if ($parents.Count -gt 1) { $skipMerge++; continue }         # D7: merge commit authored nothing
        if ($parents.Count -eq 0) { $skipRoot++; continue }           # a root commit creates; D2
        $parent = $parents[0]
        if (-not $graded) {
            if (-not $presence.ContainsKey($parent)) {
                # Absence must be proven, not inferred (T080). An unreadable parent is unknown,
                # and "unknown" reported as "predates the check" is a wrong reason printed green.
                if (-not (Test-CheckAbsentForReal -Ref $parent)) {
                    $script:failures += "AmendmentAuthority: cannot grade '$Branch' — parent commit $($parent.Substring(0, 7)) of $($commit.Substring(0, 7)) is not readable in this clone, so whether it predates the check is unknown; treating it as pre-boundary would skip a commit on a wrong reason. Fetch the full history: 'fetch-depth: 0' on actions/checkout, or 'git fetch --unshallow' (constitution I, Amendment authority)"
                    return
                }
                $skipBoundary++; continue                             # D2b
            }
            $graded = $true                                          # monotonic: stop re-testing
        }
        $gradedCount++
        $short = $commit.Substring(0, 7)

        $amended = @()
        foreach ($row in @($nameStatus[$commit])) {
            if (-not $row) { continue }
            $parts = $row -split "`t"
            if ($parts.Count -lt 2) { continue }
            $status = $parts[0]
            $path = $parts[$parts.Count - 1]                          # renames: the NEW path
            $oldPath = if ($status -match '^[RC]' -and $parts.Count -ge 3) { $parts[1] } else { $path }
            if ($path -notlike "$dir/*") { continue }
            $leaf = $path.Substring($dir.Length + 1)
            if ($leaf -notin @('spec.md', 'plan.md', 'tasks.md') -and $leaf -notlike 'contracts/*') { continue }
            if ($status -match '^A') { continue }                     # D2: first appearance
            # A rename is creation at the new path when the CONTENT came across — decided by
            # comparing the blobs, not by git's similarity percentage (J3). A renumbered branch
            # whose spec.md also gained its mandated header edit is R080, not R100, and the
            # percentage rule graded it as an unapproved amendment with no legal path to green.
            if ($status -match '^[RC]') {
                # FR-010 and the spec's Edge Cases name ONE rename that must never be graded:
                # a branch renumbered by a lost claim race, where the whole specs/NNN-name
                # directory moves and every document is added at a new path — header edits
                # included, since claim-feature.ps1 mandates them. Detect exactly that: the
                # feature-directory segment changed (J3).
                $oldFeatureDir = if ($oldPath -match '^(specs/[^/]+)/') { $matches[1] } else { '' }
                if ($oldFeatureDir -and $oldFeatureDir -ne $dir) { continue }
                # A rename WITHIN the same feature directory is not renumbering. It is creation
                # only if the content came across intact; otherwise it is an amendment wearing a
                # new path (H3 — a contract renamed and reinterpreted in one commit).
                $sameContent = (git rev-parse "${commit}:${path}" 2>$null) -eq (git rev-parse "${parent}:${oldPath}" 2>$null)
                if ($sameContent) { continue }
            }
            if ($leaf -eq 'tasks.md' -and
                (Test-CheckboxOnlyChange -Commit $commit -Parent $parent -Path $path -ParentPath $oldPath)) { continue }
            if ($leaf -in @('spec.md', 'plan.md') -and
                (Test-StatusOnlyChange -Commit $commit -Parent $parent -Path $path -ParentPath $oldPath)) { continue }
            $amended += $path
        }
        if ($amended.Count -eq 0) { continue }

        $commitDay = $meta[$commit].Day
        if (-not $commitDay) { $commitDay = (Get-Date).ToString('yyyy-MM-dd') }
        # H4: the record must be added to a file this commit actually AMENDED — a record in
        # notes.md cannot approve a silent change to plan.md, and the failure message says
        # "on the amended section", which this now means.
        $recordLines = Get-AddedRecordLines -Commit $commit -Parent $parent -Paths $amended
        $record = Get-ConformingRecord -AddedLines $recordLines -CommitDay $commitDay
        $files = ($amended | Sort-Object -Unique) -join ', '

        if (-not $record.Name) {
            $why = if ($record.Malformed.Count -gt 0) { " Rejected record(s): $($record.Malformed -join '; ')." } else { '' }
            $script:failures += "AmendmentAuthority: commit $short amends $files after approval with no conforming approver record.$why Add '$script:AmendmentRecordExample' to the amended section and name the same approver in the commit message (constitution I, Amendment authority). Ticking a task off is exempt — in either direction — but rewriting a task's text while ticking it is not: record what was done in notes.md, and leave the task saying what was agreed (plan D3c)"
            continue
        }
        # Whole-word match over the message with git's OWN trailers removed — a mandated
        # 'Co-Authored-By: Claude' trailer must not auto-satisfy an approver named Claude, and
        # an unanchored search let 'Al' match the word 'Also'. Asking git which lines are
        # trailers, instead of dropping every 'Word: ' line, keeps the SUBJECT ('docs: …',
        # 'spec: …') and ordinary body lines ('Note: approved by bob') in the message (J4).
        $full = @($meta[$commit].Body)
        $trailers = @($meta[$commit].Trailers)
        $message = (@($full | Where-Object { $trailers -notcontains $_ })) -join "`n"
        if ($message -notmatch ('(?<![\w-])' + [regex]::Escape($record.Name) + '(?![\w-])')) {
            $script:failures += "AmendmentAuthority: commit $short records '$($record.Name)' as the approver of its change to $files, but its commit message does not name them — the message is fixed at commit time and is the half a later edit cannot fake (constitution I; plan D5)"
        }
    }
    $skipped = $commits.Count - $gradedCount
    $reasons = @()
    if ($skipMerge -gt 0)    { $reasons += "$skipMerge merge commit(s)" }
    if ($skipRoot -gt 0)     { $reasons += "$skipRoot root commit(s)" }
    if ($skipBoundary -gt 0) { $reasons += "$skipBoundary made before the check existed (plan D2b)" }
    $why = if ($skipped -gt 0) { " ($skipped not graded: $($reasons -join '; '))" } else { '' }
    Write-Host "AmendmentAuthority: graded $gradedCount of $($commits.Count) commit(s) in $range$why"
}

# --- Dispatch ---
$Branch = Get-CurrentBranch -Override $Branch
$diffBase = Get-DiffBase
$changedFiles = Get-ChangedFiles -Base $diffBase

Write-Host "enforcement-pack: branch '$Branch', diff base '$diffBase', $($changedFiles.Count) changed file(s)"

# Silence is not compliance in the other lanes either (review G2). With no computable base the
# pack still speaks, but nothing it says is a comparison, and the three dispositions differ by
# member: Get-ChangedFiles returns an empty list, so the Lite-lane check grades nothing; the
# members taking -Base (review-provenance, phase-size, the Micro phase walk) return without
# grading; AmendmentAuthority fails rather than grading. On a baseless clone a 'fix/' branch
# touching anything at all therefore went green. Where origin/main resolves but shares no
# commit, the phase 5 fix that replaced the Get-DiffBase crash is what made that state
# reachable rather than fatal; where neither ref resolves the loop was never entered and it was
# always this quiet (review H1). FR-009 forbids newly FAILING a Lite branch on a null base, so
# this names the condition instead of failing on it — the run reports itself as ungraded rather
# than as clean. An NNN-* branch still fails, in the check.
if (-not $diffBase -and $Branch -notin @('main', 'master')) {
    $script:warnings += "enforcement-pack: no integration branch to diff against, so nothing on '$Branch' was compared — each check that reads the diff either graded an empty file list, returned without grading, or failed for want of a base. This run is not evidence that the branch is clean — it is evidence that nothing was compared. Fetch the full history ('git fetch origin main', or 'fetch-depth: 0' on actions/checkout)."
}

if ($Branch -in @('main', 'master')) {
    Write-Host "enforcement-pack: '$Branch' is the trunk, not a feature/fix/chore/docs branch — no scripted checks apply"
} elseif ($Branch -match '^\d{3}-') {
    Invoke-StructureCheck -Branch $Branch
    Invoke-MicroLaneCheck -Branch $Branch -Base $diffBase
    Invoke-CriticalEvidenceCheck -Branch $Branch
    Invoke-GateBatchingCheck -Branch $Branch
    Invoke-GateCertificationCheck -Branch $Branch
    Invoke-ReviewProvenanceCheck -Branch $Branch -Base $diffBase
    Invoke-AmendmentAuthorityCheck -Branch $Branch -Base $diffBase -IgnoreAmendmentBoundary:$IgnoreAmendmentBoundary -ReplayBase $ReplayBase -ReplayTip $ReplayTip
    Invoke-PhaseSizeWarningCheck -Branch $Branch -Base $diffBase
} elseif ($Branch -match '^(fix|chore)/') {
    # The one member here that does not DECLINE on a null base - it grades, and grades an empty
    # list, which passes for the same reason an empty accusation is never proved. The comment
    # above says it plainly: a baseless 'fix/' branch touching anything at all went green. A
    # vacuous grade reaches the same wrong verdict as a skipped one, so it is named the same way.
    if (-not $diffBase) {
        $ungraded += "LiteAndAbuse: no diff base, so the prohibited-category and file-count guards graded an EMPTY file list on '$Branch' - every prohibited change this lane forbids would have passed"
    }
    Invoke-LiteAndAbuseCheck -Branch $Branch -ChangedFiles $changedFiles
    Invoke-ReviewProvenanceCheck -Branch $Branch -Base $diffBase
} elseif ($Branch -match '^docs/') {
    Invoke-ReviewProvenanceCheck -Branch $Branch -Base $diffBase
    Write-Host "enforcement-pack: '$Branch' is the lightweight docs/ lane — review-provenance is the only scripted check that applies"
} else {
    $script:failures += "Branch naming: '$Branch' does not match a known taxonomy (NNN-*, fix/*, chore/*, docs/*) — see docs/sdlc/branch-strategy.md"
}

foreach ($w in $warnings) { Write-Host "WARNING: $w" }
# Listed before the verdict and independently of it, the way warnings are: a run can both fail
# and have graded nothing, and the reader needs to know that the FAIL count is not the whole
# story. What the verdict word does is stop 'OK' being printed over the top of it.
foreach ($u in $ungraded) { Write-Host "UNGRADED: $u" }
if ($failures.Count -gt 0) {
    Write-Host "enforcement-pack: FAIL ($($failures.Count) issue(s)):"
    foreach ($f in $failures) { Write-Host "  - $f" }
    exit 1
}
if ($ungraded.Count -gt 0) {
    # Exit 0, deliberately and on the record (plan D6, FR-011). Feature 014's FR-009 forbids a
    # new hard failure on the Lite lane, and that constraint stands. What changes is that no one
    # can read this run as clean. Whether UNGRADED should ever block is a later feature's
    # question with its own evidence; it is not answered here by the back door.
    Write-Host "enforcement-pack: UNGRADED ($($ungraded.Count) check(s) formed no opinion)"
    exit 0
}
Write-Host 'enforcement-pack: OK'
exit 0

} finally {
    Pop-Location
}
