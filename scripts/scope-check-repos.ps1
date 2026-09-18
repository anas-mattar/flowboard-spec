<#
.SYNOPSIS
    Cross-repo scope check: grades the nested code repositories' phase commits against the
    Territory this (governance) repository declares for that phase — Definition of Done
    gate 4, reaching the code (feature 012, GAP-016).

.DESCRIPTION
    Contract: specs/012-cross-repo-scope-check/contracts/scope-check-repos-cli.md.
    Semantics are shared with scripts/scope-check.ps1 via scripts/scope-lib.ps1 (D6), so
    phase attribution, Micro-lane handling, glob matching and rename/delete handling are
    the same rules in both places.

    In the nested layout (docs/sdlc/repository-strategy.md) the code lives in independent
    repositories cloned inside the governance repository, which is where the Territory
    declaration lives. This script runs from the governance root and reads those code
    repositories as sibling working trees:

      - Which repositories: the 'codeRepos' array in kit-adoption.json (D2). Absent or
        empty -> n/a, exit 0. The kit repository and single-repo adoptions declare none,
        so nothing changes for them.
      - Which paths: each code repository's touched paths are prefixed with its directory
        name, so territory entries are written governance-root-relative and repo-prefixed:
        `fitforge-api/src/Training/**` (D3).
      - Which declaration: the one that stood WHEN THE CODE WAS COMMITTED — the newest
        governance commit whose committer date is not after the code commit's (D4). A
        declaration widened afterwards is invisible to an earlier commit's verdict, which
        is the cross-repository analogue of the in-repo parent-read rule.

    Verdicts and exit codes:
      PASS / not applicable / n/a / WARN -> 0
      FAIL (any undeclared path, or a malformed declaration) -> 1
    Overall exit is 1 iff at least one repository FAILs. Read-only: never writes, fetches
    or checks out.

.EXAMPLE
    pwsh -File scripts/scope-check-repos.ps1                     # each declared repo's branch tip
    pwsh -File scripts/scope-check-repos.ps1 -All                # every phase commit since merge-base
    pwsh -File scripts/scope-check-repos.ps1 -Repo fitforge-api -Branch 014-plans -All
#>
[CmdletBinding()]
param(
    [string]$Commit = 'HEAD',
    [int]$Phase = 0,
    [string]$Branch,
    [string]$Repo,
    [string]$BaseRef,
    [switch]$All,
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path $Root).Path
$explicitCommit = $PSBoundParameters.ContainsKey('Commit')

. (Join-Path $PSScriptRoot 'scope-lib.ps1')   # shared territory parsing / matching (D6)

$name = 'scope-repos'   # matches the ritual-checks member name (build-digests -> 'digests' precedent)

function Write-Line { param([string]$Text) Write-Host "${name}: $Text" }

# --- Declared code repositories (D2) -------------------------------------------------------
function Get-DeclaredRepos {
    param([string]$GovRoot)
    $recordPath = Join-Path $GovRoot 'kit-adoption.json'
    if (-not (Test-Path $recordPath)) { return @() }
    try {
        $record = Get-Content -Raw -Path $recordPath | ConvertFrom-Json
    } catch {
        Write-Line "WARN kit-adoption.json is not valid JSON — no code repositories read (fix the record; scripts/verify-kit.ps1 explains the shape)"
        return @()
    }
    if ($null -ne $record.codeRepos -and $record.codeRepos -isnot [Array]) {
        Write-Line "WARN kit-adoption.json codeRepos is not an array — ignoring it (shape: adoption/updating.md)"
        return @()
    }
    $entries = @($record.codeRepos | Where-Object { $_ })
    # Entries are single directory names (D2). A path, a traversal or a drive prefix would
    # address a directory outside the governance root — read-only here, but it grades the
    # wrong tree. The doctor FAILs these (feature 012 phase 2); the grader refuses them too,
    # because a code repository's CI may never run the doctor (phase 1 review, F7).
    $clean = @()
    foreach ($e in $entries) {
        if ("$e" -notmatch '^(?!\.+$)[A-Za-z0-9._-]+$') {
            Write-Line "WARN ignoring codeRepos entry '$e' — entries are plain directory names under this repository, not paths (scripts/verify-kit.ps1 explains the shape)"
            continue
        }
        $clean += "$e"
    }
    return $clean
}

# The governance ref whose history carries the declaration. A CI job that clones the
# governance repository gets its DEFAULT branch, where an in-flight feature's declaration
# does not exist as a local head — only as refs/remotes/origin/<branch>. Falling straight
# through to HEAD there reads main, finds no declaration, and degrades a real FAIL into a
# non-blocking WARN: green, and blind (phases 2-3 review, F1).
function Get-GovernanceRef {
    param([string]$FeatureBranch)
    foreach ($candidate in @("refs/heads/$FeatureBranch", "refs/remotes/origin/$FeatureBranch")) {
        git -C $Root rev-parse --verify --quiet $candidate *> $null
        if ($LASTEXITCODE -eq 0) { return $candidate }
    }
    return 'HEAD'
}

# The declaration as it stood at $When (D4): blob text of $RelPath from the newest
# governance commit not after that instant THAT TOUCHED THAT PATH. The path filter is not an
# optimization — without it rev-list answers with the newest commit anywhere in the reachable
# graph, so merging main into the governance branch (or a pull_request merge HEAD) returns a
# commit that never carried the declaration, and a real FAIL silently becomes a WARN
# (phase 1 review, F1). The blob only changes at commits that touch the path, so the newest
# such commit at or before the date IS the state as of that date.
# Returns $null when no such commit exists (the file never existed yet, or the newest
# touching commit deleted it) — the caller's WARN path.
function Get-BlobAsOf {
    param([string]$GovRef, [string]$When, [string]$RelPath)
    $sha = git -C $Root rev-list -1 --before="$When" $GovRef -- $RelPath 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $sha) { return $null }
    $blob = git -C $Root show "$("$sha".Trim()):$RelPath" 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return $blob
}

# The declaration as it stands NOW at the governance ref — used only to tell the two
# no-declaration cases apart (FR-004): a declaration that exists today but not as of the code
# commit POST-DATES that commit and must FAIL, while one that exists nowhere is a genuine
# pre-feature history and stays a non-blocking WARN.
function Get-BlobAtRef {
    param([string]$GovRef, [string]$RelPath)
    $blob = git -C $Root show "${GovRef}:$RelPath" 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return $blob
}

# Is there a usable territory declaration for this phase at the governance ref tip?
function Test-DeclaredAtTip {
    param([string]$GovRef, [string]$FeatureBranch, [int]$PhaseNumber)
    $tipSpec = Get-BlobAtRef -GovRef $GovRef -RelPath "specs/$FeatureBranch/spec.md"
    if (Test-IsMicro -SpecLines @($tipSpec)) {
        $t = Get-Territory -TasksLines (Get-VisibleLines -Lines @($tipSpec)) -Global
        return @{ Found = ($t.Found -and $t.Entries.Count -gt 0); Source = "specs/$FeatureBranch/spec.md" }
    }
    $tipTasks = Get-BlobAtRef -GovRef $GovRef -RelPath "specs/$FeatureBranch/tasks.md"
    if (-not $tipTasks) { return @{ Found = $false; Source = "specs/$FeatureBranch/tasks.md" } }
    $t = Get-Territory -TasksLines @($tipTasks) -PhaseNumber $PhaseNumber
    return @{ Found = ($t.Found -and $t.Entries.Count -gt 0); Source = "specs/$FeatureBranch/tasks.md" }
}

# Entries whose first segment names neither a declared repository nor anything that exists
# in the governance root are probable typos (`fitforge_api/...`) — report, never silently
# match nothing (C10).
$script:warnedEntries = @{}
function Write-PrefixWarnings {
    param([string[]]$Entries, [string[]]$Declared, [string]$Source)
    foreach ($e in $Entries) {
        $first = ($e -split '[\\/]')[0]
        if ($first -in $Declared) { continue }
        if (Test-Path (Join-Path $Root $first)) { continue }        # a governance-side path
        if ($script:warnedEntries.ContainsKey($e)) { continue }     # once per run, not per commit
        $script:warnedEntries[$e] = $true
        Write-Line "WARN territory entry '$e' in $Source names '$first', which is neither a declared code repository nor a path in the governance repository (typo? kit-adoption.json declares: $($Declared -join ', '))"
    }
}

# Grade one commit of one code repository. Returns 'PASS' | 'FAIL' | 'SKIP'.
function Invoke-RepoScopeCheck {
    param(
        [string]$RepoName, [string]$RepoPath, [string]$Sha,
        [string]$FeatureBranch, [int]$PhaseOverride, [string[]]$Declared
    )

    # Plain `rev-parse --short` echoes an unknown sha back, unvalidated — ask for a commit.
    $sha7 = (git -C $RepoPath rev-parse --verify --quiet --short "$Sha^{commit}" 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $sha7) {
        Write-Line "${RepoName}: ERROR '$Sha' does not resolve to a commit"
        return 'FAIL'
    }
    $sha7 = "$sha7".Trim()

    $parents = ((git -C $RepoPath rev-list --parents -n 1 $Sha 2>$null) -split '\s+')
    if ($parents.Count -gt 2) {
        Write-Line "${RepoName}: not applicable (commit $sha7 is a merge commit)"
        return 'SKIP'
    }

    $phaseN = $PhaseOverride
    if ($phaseN -le 0) {
        $subject = (git -C $RepoPath log -1 --format=%s $Sha 2>$null)
        if ($subject -match '(?i)\bphase\s+(\d+)\b') { $phaseN = [int]$matches[1] }
    }
    if ($phaseN -le 0) {
        Write-Line "${RepoName}: not applicable (commit $sha7 carries no 'phase N' token — not a phase commit)"
        return 'SKIP'
    }

    # --- the declaration as of this commit (D4) ---
    $when = (git -C $RepoPath show -s --format=%cI $Sha 2>$null)
    if (-not $when) {
        Write-Line "${RepoName}: ERROR cannot read the committer date of $sha7"
        return 'FAIL'
    }
    $when = "$when".Trim()
    $govRef = Get-GovernanceRef -FeatureBranch $FeatureBranch
    $specRel = "specs/$FeatureBranch/spec.md"
    $tasksRel = "specs/$FeatureBranch/tasks.md"

    $specBlob = Get-BlobAsOf -GovRef $govRef -When $when -RelPath $specRel
    $isMicro = Test-IsMicro -SpecLines @($specBlob)
    $source = $isMicro ? $specRel : $tasksRel

    if ($isMicro) {
        $territory = Get-Territory -TasksLines (Get-VisibleLines -Lines @($specBlob)) -Global
        # Same rule as the in-repo grader: the mini-spec template requires a Territory block
        # and the lane has no pre-existing features to grandfather, so its absence is a FAIL,
        # not the Standard lane's compatibility WARN (phase 1 review, F3).
        if (-not $territory.Found -or $territory.Entries.Count -eq 0) {
            Write-Line "${RepoName}: FAIL phase $phaseN commit ${sha7}: this Micro feature declares no usable **Territory** block in $specRel — fix the declaration in a governance commit made BEFORE the code phase commit, or promote to Standard: expand spec.md to the full template, add plan.md + tasks.md (Territory moves there), before the next phase commit (constitution X, Micro lane)"
            return 'FAIL'
        }
    } else {
        $tasksBlob = Get-BlobAsOf -GovRef $govRef -When $when -RelPath $tasksRel
        $territory = $tasksBlob `
            ? (Get-Territory -TasksLines @($tasksBlob) -PhaseNumber $phaseN) `
            : @{ Found = $false; Duplicate = $false; Entries = @(); Invalid = @() }
    }

    $remediation = "revert the undeclared change, or amend the phase's **Territory** in $source (owner approval) in a governance commit made BEFORE the code phase commit, then re-commit the phase"

    if ($territory.Duplicate) {
        Write-Line "${RepoName}: FAIL phase $phaseN commit ${sha7}: more than one **Territory** marker for phase $phaseN in $source (exactly one per phase)"
        return 'FAIL'
    }
    if ($territory.Invalid.Count -gt 0) {
        foreach ($bad in $territory.Invalid) {
            Write-Line "${RepoName}: FAIL phase $phaseN commit ${sha7}: invalid territory entry '$bad' (entries must be repo-relative, no '..')"
        }
        return 'FAIL'
    }
    if ($territory.Found -and $territory.Entries.Count -eq 0) {
        Write-Line "${RepoName}: FAIL phase $phaseN commit ${sha7}: **Territory** declared for phase $phaseN in $source but the entry list is empty (declare the paths, or remove the marker)"
        return 'FAIL'
    }
    if (-not $territory.Found) {
        # FR-004: a declaration only governs code committed after it lands. If one exists now
        # but did not when this commit was made, the ordering itself is the violation — FAILing
        # it is what stops "commit the code, declare the territory afterwards" from being a
        # permanently green gate (phase 1 review, F2; owner adjudication 2026-09-09).
        $tip = Test-DeclaredAtTip -GovRef $govRef -FeatureBranch $FeatureBranch -PhaseNumber $phaseN
        if ($tip.Found) {
            Write-Line "${RepoName}: FAIL phase $phaseN commit ${sha7}: the phase $phaseN **Territory** in $($tip.Source) POST-DATES this commit ($when) — a declaration only governs code committed after it lands; re-commit the phase on top of the declaration (or declare the territory first, then re-commit)"
            return 'FAIL'
        }
        Write-Line "${RepoName}: WARN phase $phaseN commit ${sha7}: no territory declared for phase $phaseN in $source, at this commit's date or since (non-blocking — a history predating the declaration)"
        return 'SKIP'
    }

    Write-PrefixWarnings -Entries $territory.Entries -Declared $Declared -Source $source

    Push-Location $RepoPath
    try { $paths = @(Get-CommitPaths -Sha $Sha) } finally { Pop-Location }
    $prefixed = @($paths | ForEach-Object { "$RepoName/$_" })
    $strays = @($prefixed | Where-Object { -not (Test-InTerritory -Path $_ -Globs $territory.Entries) })

    if ($strays.Count -eq 0) {
        $micro = $isMicro ? ', Micro territory from spec.md' : ''
        Write-Line "${RepoName}: PASS phase $phaseN commit $sha7 ($($paths.Count) file(s)$micro)"
        return 'PASS'
    }
    foreach ($s in $strays) {
        Write-Line "${RepoName}: FAIL phase $phaseN commit ${sha7}: $s not in territory"
    }
    Write-Line "${RepoName}: remediation — $remediation"
    return 'FAIL'
}

# --- Dispatch ------------------------------------------------------------------------------
$declared = @(Get-DeclaredRepos -GovRoot $Root)
if ($declared.Count -eq 0) {
    Write-Line 'n/a (no codeRepos declared in kit-adoption.json — single-repo project, the kit repository, or a record predating feature 012)'
    exit 0
}

# The full declared set stays intact for messages and prefix checking; -Repo only narrows
# which repositories are graded (a code repo's own CI grades itself).
$toGrade = $declared
if ($Repo) {
    if ($Repo -notin $declared) {
        Write-Line "ERROR '-Repo $Repo' is not declared in kit-adoption.json (declared: $($declared -join ', '))"
        exit 1
    }
    $toGrade = @($Repo)
}

if (-not $Branch) {
    $b = git -C $Root rev-parse --abbrev-ref HEAD 2>$null
    if ($LASTEXITCODE -eq 0 -and $b) { $Branch = "$b".Trim() }
}
if (-not $Branch) {
    Write-Line 'ERROR cannot determine the current branch (pass -Branch <NNN-name>)'
    exit 1
}
if ($Branch -eq 'HEAD') {
    Write-Line 'WARN detached HEAD — pass -Branch <NNN-name> to classify the lane (CI wrappers must do this explicitly)'
    exit 0
}
if ($Branch -match '^(fix|chore|docs)/') {
    Write-Line "not applicable ($($matches[1])/ lane — enforcement-pack's Lite-lane checks apply instead)"
    exit 0
}
if ($Branch -in @('main', 'master')) {
    Write-Line "not applicable ('$Branch' is the trunk)"
    exit 0
}
if ($Branch -notmatch '^\d{3}-') {
    Write-Line "not applicable ('$Branch' is not a numbered feature branch)"
    exit 0
}

$failed = $false
$graded = 0
foreach ($repoName in $toGrade) {
    $repoPath = Join-Path $Root $repoName
    if (-not (Test-Path $repoPath)) {
        Write-Line "${repoName}: n/a (declared but not present here — a governance-only checkout; the code repository's own CI runs this check for itself)"
        continue
    }
    # A plain directory inside the governance tree makes git walk UP and answer for the
    # governance repository — grading the wrong history. Require the declared directory to
    # be the root of its own repository.
    $top = git -C $repoPath rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $top) {
        Write-Line "${repoName}: n/a (present but not a git repository)"
        continue
    }
    $seps = [char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $topResolved = (Resolve-Path "$top".Trim()).Path.TrimEnd($seps)
    if ($topResolved -ne (Resolve-Path $repoPath).Path.TrimEnd($seps)) {
        Write-Line "${repoName}: n/a (present but not a repository of its own — it sits inside $topResolved)"
        continue
    }
    git -C $repoPath rev-parse --verify --quiet "refs/heads/$Branch" *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Line "${repoName}: not applicable (no '$Branch' branch here — this repository is not part of the feature)"
        continue
    }

    $commits = @()
    if ($All) {
        # Code repositories are pre-existing independent repositories: their trunk is often
        # master or develop, unlike the kit-created governance repo (phase 1 review, F5).
        $base = $null
        $candidates = @('origin/main', 'main', 'origin/master', 'master', 'origin/HEAD')
        if ($BaseRef) { $candidates = @($BaseRef) }
        foreach ($c in $candidates) {
            git -C $repoPath rev-parse --verify --quiet $c *> $null
            if ($LASTEXITCODE -eq 0) {
                $b = git -C $repoPath merge-base $Branch $c 2>$null
                if ($LASTEXITCODE -eq 0 -and $b) { $base = "$b".Trim(); break }
            }
        }
        if (-not $base) {
            Write-Line "${repoName}: WARN could not resolve a merge base with a trunk ($($candidates -join ', ')) — NOTHING WAS GRADED in this repository; pass -BaseRef <ref> naming its trunk"
            continue
        }
        $commits = @((git -C $repoPath rev-list --reverse --no-merges "$base..$Branch" 2>$null) | Where-Object { $_ })
        if ($commits.Count -eq 0) {
            Write-Line "${repoName}: PASS (no commits since merge base)"
            continue
        }
    } else {
        # HEAD may sit on an entirely different feature's branch — grading it produces a
        # verdict about work this feature never did (phase 1 review, F4). Default to the
        # feature branch's tip; honour -Commit only when the caller passed it.
        $commits = @($explicitCommit ? $Commit : $Branch)
    }

    foreach ($c in $commits) {
        $verdict = Invoke-RepoScopeCheck -RepoName $repoName -RepoPath $repoPath -Sha $c `
            -FeatureBranch $Branch -PhaseOverride $Phase -Declared $declared
        if ($verdict -in @('PASS', 'FAIL')) { $graded++ }   # SKIP graded nothing (re-review N3)
        if ($verdict -eq 'FAIL') { $failed = $true }
    }
}

# An n/a-shaped line so scripts/ritual-checks.ps1 lifts the reason into its summary instead
# of printing a bare OK for a run that graded nothing (phase 1 review, F6).
if ($graded -eq 0) { Write-Line "n/a (nothing was graded in the declared code repositories for '$Branch' — the reason is on the line(s) above)" }
if ($failed) { exit 1 }
exit 0
