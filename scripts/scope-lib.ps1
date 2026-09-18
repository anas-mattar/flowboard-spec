<#
.SYNOPSIS
    Shared scope-check semantics: territory parsing, glob matching, commit path extraction.

.DESCRIPTION
    Dot-sourced by scripts/scope-check.ps1 (this repository's commits) and
    scripts/scope-check-repos.ps1 (the nested code repositories' commits — feature 012,
    GAP-016). One implementation, so the two graders cannot drift: the Micro lane, the
    rename handling and the literal-bracket matching each arrived as a separate fix, and
    a copied helper set would need every one of them applied twice.

    Contracts: specs/006-verification-pack/contracts/scope-check-cli.md and
    specs/012-cross-repo-scope-check/contracts/scope-check-repos-cli.md.

    Every function here is pure with respect to the working directory EXCEPT
    Get-CommitPaths, which shells out to git and therefore reads the caller's current
    location (or an explicit -GitDir/-C by the caller). Callers set their own location.

.NOTES
    Not a runnable script — dot-source it:
        . (Join-Path $PSScriptRoot 'scope-lib.ps1')
#>

# Paths a commit touches: renames contribute both sides, deletes the deleted path.
# quotepath=off so non-ASCII paths arrive verbatim, not quoted-octal (006 review F3).
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

# Declarations are parsed from VISIBLE text only: a '**Delivery Level**: Micro' decoy
# inside an HTML comment block must never win first-match over the rendered one (same
# rule as enforcement-pack's Get-VisiblePlanLines — 008 phase 2 review, F1 precedent).
function Get-VisibleLines {
    param([string[]]$Lines)
    $raw = ($Lines -join "`n")
    return ([regex]::Replace($raw, '(?s)<!--.*?-->', '')) -split "`r?`n"
}

# Micro detection (constitution X, Micro lane): the first visible '**Delivery Level**:'
# line of the given spec.md blob has the value Micro. Absent blob, absent field, or any
# other value means NOT Micro — zero new behavior (006 contract M1).
function Test-IsMicro {
    param([string[]]$SpecLines)
    if (-not $SpecLines) { return $false }
    $line = Get-VisibleLines -Lines $SpecLines |
        Where-Object { $_ -match '^\*\*Delivery Level\*\*:' } | Select-Object -First 1
    return [bool]($line -and $line -match '^\*\*Delivery Level\*\*:\s*Micro\b')
}

# Territory list for phase N, from a specific blob of tasks.md.
# Entries MUST be backtick-wrapped list items (`- `path``); collection starts at the first
# entry after the marker and ends at the first blank line or non-entry line once entries
# have begun — so a following task checklist can never be swallowed as territory (006 review F1).
# Returns @{ Found = bool; Duplicate = bool; Entries = string[]; Invalid = string[] }
# -Global (Micro lane): the block is feature-global in spec.md, not under a phase heading —
# the first '**Territory**:' marker anywhere counts, and a second one anywhere is a
# duplicate. Lines are pre-stripped of HTML comments by the caller (Get-VisibleLines).
function Get-Territory {
    param([string[]]$TasksLines, [int]$PhaseNumber, [switch]$Global)
    $result = @{ Found = $false; Duplicate = $false; Entries = @(); Invalid = @() }
    $inPhase = [bool]$Global
    $collecting = $false
    $started = $false
    foreach ($line in $TasksLines) {
        if (-not $Global -and $line -match '^##\s+Phase\s+(\d+)\b') {
            $inPhase = ([int]$matches[1] -eq $PhaseNumber)
            $collecting = $false
            continue
        }
        if (-not $inPhase) { continue }
        if ($line -match '^\*\*Territory\*\*:') {
            if ($result.Found) { $result.Duplicate = $true }         # exactly one marker per phase (006 review F8)
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
        # D1 promises globs, not -like character classes: match [, ], ? literally (006 review F7).
        $pattern = $pattern.Replace('[', '`[').Replace(']', '`]').Replace('?', '`?')
        if ($pattern.EndsWith('/')) { $pattern += '*' }              # trailing slash = whole subtree
        if ($Path -like $pattern) { return $true }
    }
    return $false
}
