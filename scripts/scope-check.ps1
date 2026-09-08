<#
.SYNOPSIS
    Machine scope check: verifies a phase commit's diff stays inside the territory the
    feature's tasks.md declared for that phase (Definition of Done gate 4).

.DESCRIPTION
    Contract: specs/006-verification-pack/contracts/scope-check-cli.md.

    Lane classification:
      - fix/*, chore/*, docs/* branches: not applicable (exit 0) — the Lite lane's defense
        is enforcement-pack's prohibited-category and abuse-guard checks.
      - NNN-* branches: every phase commit is checked against the **Territory** list under
        its phase heading in specs/NNN-name/tasks.md.

    Phase attribution: the commit subject must carry a 'phase N' token (research D2);
    -Phase overrides. A commit with no parseable phase token is not a phase commit
    (claim/specify/review commits) and gets 'not applicable'. A phase with no territory
    declaration produces a NON-BLOCKING warning (compatibility with features specified
    before the verification pack); a declared-but-empty or duplicated declaration FAILs.

    Anti-retroactivity (research D3, review F2): the declaration is read from the commit's
    PARENT (<commit>^:tasks.md), falling back to the commit's own blob only when the parent
    lacks the entire specs/NNN-name/ directory (a true claim commit). A phase commit that
    deletes tasks.md FAILs, and a parent missing tasks.md while the feature directory
    exists FAILs — so a territory amendment only ever takes effect for commits made after
    it lands.

    Matching: PowerShell -like semantics; '*' (and the conventional '**') matches across
    path separators; '[', ']' and '?' are matched literally; a trailing '/' means the whole
    subtree; matching is case-insensitive by design. The feature's own spec directory
    (specs/NNN-name/**) is always implicitly in territory. Renames touch both paths;
    deletes touch the deleted path. Territory entries must be backtick-wrapped list items.

    Verdicts and exit codes (data-model.md):
      PASS / not-applicable / WARN  -> exit 0
      FAIL (any undeclared path)    -> exit 1

.EXAMPLE
    pwsh -File scripts/scope-check.ps1                    # check HEAD
    pwsh -File scripts/scope-check.ps1 -Commit abc1234 -Phase 2
    pwsh -File scripts/scope-check.ps1 -All               # every phase commit since merge-base (CI mode)
#>
[CmdletBinding()]
param(
    [string]$Commit = 'HEAD',
    [int]$Phase = 0,
    [string]$Branch,
    [switch]$All,
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path $Root).Path
Push-Location $Root
try {

function Get-CurrentBranch {
    param([string]$Override)
    if ($Override) { return $Override }
    $b = git rev-parse --abbrev-ref HEAD 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $b) { return '' }
    return "$b".Trim()
}

function Get-DiffBase {
    foreach ($c in @('origin/main', 'main')) {
        git rev-parse --verify --quiet $c *> $null
        if ($LASTEXITCODE -eq 0) {
            $base = git merge-base HEAD $c 2>$null
            if ($LASTEXITCODE -eq 0 -and $base) { return "$base".Trim() }
        }
    }
    return $null
}

# Paths a commit touches: renames contribute both sides, deletes the deleted path.
# quotepath=off so non-ASCII paths arrive verbatim, not quoted-octal (review F3).
function Get-CommitPaths {
    param([string]$Sha)
    $paths = @()
    $rows = git -c core.quotepath=off show --name-status --format='' -M $Sha 2>$null
    foreach ($row in $rows) {
        if (-not $row) { continue }
        $parts = $row -split "`t"
        if ($parts.Count -lt 2) { continue }
        if ($parts[0] -match '^[RC]') {
            if ($parts.Count -ge 3) { $paths += $parts[1]; $paths += $parts[2] }
        } else {
            $paths += $parts[1]
        }
    }
    $paths | Where-Object { $_ } | Select-Object -Unique
}

# Territory list for phase N, from a specific blob of tasks.md.
# Entries MUST be backtick-wrapped list items (`- `path``); collection starts at the first
# entry after the marker and ends at the first blank line or non-entry line once entries
# have begun — so a following task checklist can never be swallowed as territory (review F1).
# Returns @{ Found = bool; Duplicate = bool; Entries = string[]; Invalid = string[] }
function Get-Territory {
    param([string[]]$TasksLines, [int]$PhaseNumber)
    $result = @{ Found = $false; Duplicate = $false; Entries = @(); Invalid = @() }
    $inPhase = $false
    $collecting = $false
    $started = $false
    foreach ($line in $TasksLines) {
        if ($line -match '^##\s+Phase\s+(\d+)\b') {
            $inPhase = ([int]$matches[1] -eq $PhaseNumber)
            $collecting = $false
            continue
        }
        if (-not $inPhase) { continue }
        if ($line -match '^\*\*Territory\*\*:') {
            if ($result.Found) { $result.Duplicate = $true }         # exactly one marker per phase (review F8)
            $result.Found = $true; $collecting = $true; $started = $false
            continue
        }
        if (-not $collecting) { continue }
        if ($line -match '^\s*$') {
            if ($started) { $collecting = $false }                   # blank line after entries ends the list
            continue                                                 # blank line(s) between marker and list are fine
        }
        if ($line -match '^\s*[-*]\s+`([^`]+)`\s*$') {               # backtick-wrapped bare path/glob only
            $started = $true
            $entry = $matches[1].Trim()
            if ($entry -match '^([A-Za-z]:|[/\\])' -or $entry -match '(^|[/\\])\.\.([/\\]|$)') {
                $result.Invalid += $entry
            } else {
                $result.Entries += $entry
            }
            continue
        }
        $collecting = $false                                         # anything else (incl. task checkboxes) ends the list
    }
    return $result
}

function Test-InTerritory {
    param([string]$Path, [string[]]$Globs)
    foreach ($g in $Globs) {
        $pattern = $g -replace '\*\*', '*'
        # D1 promises globs, not -like character classes: match [, ], ? literally (review F7).
        $pattern = $pattern.Replace('[', '`[').Replace(']', '`]').Replace('?', '`?')
        if ($pattern.EndsWith('/')) { $pattern += '*' }              # trailing slash = whole subtree
        if ($Path -like $pattern) { return $true }
    }
    return $false
}

# Check one commit; returns $true when the verdict is not FAIL.
function Invoke-ScopeCheck {
    param([string]$Sha, [string]$FeatureBranch, [int]$PhaseOverride)

    $sha7raw = git rev-parse --short $Sha 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $sha7raw) {
        Write-Host "scope-check: ERROR '$Sha' does not resolve to a commit"
        return $false
    }
    $sha7 = "$sha7raw".Trim()

    # Merge commits are not phase commits.
    $parents = ((git rev-list --parents -n 1 $Sha 2>$null) -split '\s+')
    if ($parents.Count -gt 2) {
        Write-Host "scope-check: not applicable (commit $sha7 is a merge commit)"
        return $true
    }

    $tasksRel = "specs/$FeatureBranch/tasks.md"

    # No commit on a feature branch may delete tasks.md — that is the F2 bypass's first
    # move, and hiding it in a token-less commit must not help, so this check runs BEFORE
    # phase attribution.
    $statusRows = git -c core.quotepath=off show --name-status --format='' $Sha 2>$null
    foreach ($row in $statusRows) {
        if ($row -match "^D`t" -and ($row -split "`t")[1] -eq $tasksRel) {
            Write-Host "scope-check: FAIL commit ${sha7}: the commit deletes $tasksRel — the territory declaration must never be deleted on a feature branch (review F2)"
            return $false
        }
    }

    # Phase attribution (research D2). A commit without a phase token is not a phase
    # commit — claim/specify/review commits are legal and get not-applicable (review F8).
    $phaseN = $PhaseOverride
    if ($phaseN -le 0) {
        $subject = (git log -1 --format=%s $Sha 2>$null)
        if ($subject -match '(?i)\bphase\s+(\d+)\b') { $phaseN = [int]$matches[1] }
    }
    if ($phaseN -le 0) {
        Write-Host "scope-check: not applicable (commit $sha7 carries no 'phase N' token — not a phase commit)"
        return $true
    }

    # Declaration as of the parent (research D3). Fall back to the commit's own blob ONLY
    # when the parent lacks the entire feature directory (a true claim commit); a parent
    # that has the directory but no tasks.md means a prior commit deleted it — FAIL, not
    # fallback, or the anti-retroactivity rule is bypassable (review F2).
    $tasksBlob = git show "${Sha}^:$tasksRel" 2>$null
    if ($LASTEXITCODE -ne 0) {
        git rev-parse --verify --quiet "${Sha}^:specs/$FeatureBranch" *> $null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "scope-check: FAIL phase $phaseN commit ${sha7}: $tasksRel is missing at the parent while specs/$FeatureBranch/ exists — a prior commit deleted the territory declaration; restore tasks.md in its own commit before any phase commit"
            return $false
        }
        $tasksBlob = git show "${Sha}:$tasksRel" 2>$null
    }
    if ($LASTEXITCODE -ne 0 -or -not $tasksBlob) {
        Write-Host "scope-check: WARN commit ${sha7}: $tasksRel not found at the commit or its parent (declare territory in tasks.md — non-blocking, pre-006 compatibility)"
        return $true
    }

    $territory = Get-Territory -TasksLines @($tasksBlob) -PhaseNumber $phaseN
    if ($territory.Duplicate) {
        Write-Host "scope-check: FAIL phase $phaseN commit ${sha7}: more than one **Territory** marker for phase $phaseN in $tasksRel (exactly one per phase)"
        return $false
    }
    if ($territory.Invalid.Count -gt 0) {
        foreach ($bad in $territory.Invalid) {
            Write-Host "scope-check: FAIL phase $phaseN commit ${sha7}: invalid territory entry '$bad' (entries must be repo-relative, no '..')"
        }
        return $false
    }
    if ($territory.Found -and $territory.Entries.Count -eq 0) {
        Write-Host "scope-check: FAIL phase $phaseN commit ${sha7}: **Territory** declared for phase $phaseN in $tasksRel but the entry list is empty (declare the paths, or remove the marker)"
        return $false
    }
    if (-not $territory.Found) {
        Write-Host "scope-check: WARN commit ${sha7}: no territory declared for phase $phaseN in $tasksRel (declare territory in tasks.md — non-blocking, pre-006 compatibility)"
        return $true
    }

    $globs = @("specs/$FeatureBranch/**") + $territory.Entries      # implicit spec-dir entry
    $paths = @(Get-CommitPaths -Sha $Sha)
    $strays = @($paths | Where-Object { -not (Test-InTerritory -Path $_ -Globs $globs) })

    if ($strays.Count -eq 0) {
        Write-Host "scope-check: PASS phase $phaseN commit $sha7 ($($paths.Count) file(s))"
        return $true
    }
    foreach ($s in $strays) {
        Write-Host "scope-check: FAIL phase $phaseN commit ${sha7}: $s not in territory"
    }
    Write-Host "scope-check: remediation — revert the undeclared change, or amend the phase's **Territory** in $tasksRel (owner approval) in a commit made BEFORE the phase commit, then re-commit the phase"
    return $false
}

# --- Dispatch ---
$Branch = Get-CurrentBranch -Override $Branch

if (-not $Branch) {
    Write-Host "scope-check: ERROR cannot determine the current branch (pass -Branch <NNN-name>)"
    exit 1
}
if ($Branch -eq 'HEAD') {
    Write-Host "scope-check: WARN detached HEAD — pass -Branch <NNN-name> to classify the lane (CI wrappers must do this explicitly)"
    exit 0
}
if ($Branch -match '^(fix|chore|docs)/') {
    Write-Host "scope-check: not applicable ($($matches[1])/ lane — enforcement-pack's Lite-lane checks apply instead)"
    exit 0
}
if ($Branch -in @('main', 'master')) {
    Write-Host "scope-check: not applicable ('$Branch' is the trunk)"
    exit 0
}
if ($Branch -notmatch '^\d{3}-') {
    Write-Host "scope-check: not applicable ('$Branch' is not a numbered feature branch)"
    exit 0
}

$ok = $true
if ($All) {
    $base = Get-DiffBase
    if (-not $base) {
        Write-Host 'scope-check: WARN could not resolve a merge base with main — nothing checked'
        exit 0
    }
    $commits = @((git rev-list --reverse --no-merges "$base..HEAD" 2>$null) | Where-Object { $_ })
    if ($commits.Count -eq 0) {
        Write-Host 'scope-check: PASS (no commits since merge base)'
        exit 0
    }
    foreach ($c in $commits) {
        if (-not (Invoke-ScopeCheck -Sha $c -FeatureBranch $Branch -PhaseOverride 0)) { $ok = $false }
    }
} else {
    $ok = Invoke-ScopeCheck -Sha $Commit -FeatureBranch $Branch -PhaseOverride $Phase
}

if (-not $ok) { exit 1 }
exit 0

} finally {
    Pop-Location
}
