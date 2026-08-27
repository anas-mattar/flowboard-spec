<#
.SYNOPSIS
    Doc-lint: asserts every repository path referenced by the governance docs resolves.

.DESCRIPTION
    Drift between the rules and reality is what kills rule-based frameworks (README,
    "Conventions this kit fixes at birth"). This script scans the kit-owned governance
    documents for path references — backtick spans like `docs/sdlc/gate-command.md` and
    markdown link targets — and fails (exit 1) if any referenced path does not exist.

    Skipped on purpose:
      - unfilled slots            {{DOMAIN_INVARIANTS_PATH}}
      - per-feature patterns      specs/[feature]/spec.md, specs/NNN-name/, globs (*)
      - slash commands            /speckit.*, anything starting with "/"
      - bare filenames            spec.md (no directory separator — per-feature files)
      - single-segment dirs       contracts/ (per-feature relative directories)
      - URLs and @-includes

    Authoring convention this enforces: backticked paths MUST resolve in the kit; paths
    that exist only after adoption (files the adopter creates, e.g. docs/roadmap.md) are
    written in **bold** or wrapped in [brackets] so they are not linted.

    Unfilled {{SLOT}}s and TODO(...) markers are counted and reported as information.
    Pass -FailOnSlots to make them errors — adopting projects should turn this on once
    the constitution is ratified.

.EXAMPLE
    pwsh -File scripts/doc-lint.ps1
    pwsh -File scripts/doc-lint.ps1 -FailOnSlots   # after ratification
#>
[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [switch]$FailOnSlots
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path $Root).Path

# --- Kit integrity: a partial install (dot-directories skipped during copy) makes the
# agent lose the /speckit.* commands and improvise its own structure. Fail fast.
$requiredKitPaths = @(
    'CLAUDE.md'
    'AGENTS.md'
    '.specify/memory/constitution.md'
    '.specify/templates'
    '.specify/scripts'
    '.claude/commands'
    'docs/sdlc/definition-of-done.md'
    'docs/sdlc/gate-command.md'
    'docs/sdlc/review-process.md'
    'docs/rulebooks'
    'specs/_templates'
)
$missingKit = $requiredKitPaths | Where-Object { -not (Test-Path (Join-Path $Root $_)) }

# Kit-owned governance docs. Stock Spec Kit files (.claude/commands, .specify/templates,
# .specify/scripts) are excluded — they contain illustrative example paths by design.
$docFiles = @(
    @('CLAUDE.md', 'AGENTS.md', 'README.md', '.specify/memory/constitution.md') |
        ForEach-Object { Join-Path $Root $_ } | Where-Object { Test-Path $_ }
    foreach ($dir in 'docs', 'adoption', 'modules', 'specs/_templates') {
        $p = Join-Path $Root $dir
        if (Test-Path $p) { Get-ChildItem $p -Recurse -Filter *.md -File | ForEach-Object FullName }
    }
)

$skipPatterns = @(
    '\{\{'          # unfilled slot
    '[\[\]<>*]'     # per-feature pattern, placeholder, or glob
    '://'           # URL
    '^/'            # slash command or site-absolute path
    'NNN'           # NNN-name convention placeholder
    '^@'            # @-include (AGENTS.md)
    '^[^/]+/$'      # single-segment directory — per-feature relative (contracts/, docs/)
)

function Get-PathRefs {
    param([string]$Line)
    $refs = @()
    # Backtick spans; keep only the first whitespace token (handles `script.ps1 -Json`)
    foreach ($m in [regex]::Matches($Line, '`([^`]+)`')) {
        $refs += ($m.Groups[1].Value.Trim() -split '\s+')[0]
    }
    # Markdown link targets, minus any #anchor
    foreach ($m in [regex]::Matches($Line, '\]\(([^)#\s]+)[^)]*\)')) {
        $refs += $m.Groups[1].Value.Trim()
    }
    $refs | Where-Object {
        $ref = $_
        # Positively path-shaped: path charset with at least one '/', and either a file
        # extension in the last segment or a trailing '/'. Rejects branch-name examples
        # (fix/aging-rounding) and fragments from backtick spans that wrap across lines.
        $ref -match '^[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)+/?$' -and
        ($ref.EndsWith('/') -or ($ref -split '/')[-1] -match '\.') -and
        -not ($skipPatterns | Where-Object { $ref -match $_ })
    }
}

$broken = @()
$slotCount = 0

foreach ($file in $docFiles) {
    $relFile = [IO.Path]::GetRelativePath($Root, $file) -replace '\\', '/'
    $docDir = Split-Path -Parent $file
    $lineNo = 0
    foreach ($line in [IO.File]::ReadAllLines($file)) {
        $lineNo++
        $slotCount += [regex]::Matches($line, '\{\{[A-Z_]+\}\}|TODO\(').Count
        foreach ($ref in Get-PathRefs $line) {
            $wantDir = $ref.EndsWith('/')
            $resolved = $false
            foreach ($base in $Root, $docDir) {
                $candidate = Join-Path $base $ref.TrimEnd('/')
                if ($wantDir ? (Test-Path $candidate -PathType Container) : (Test-Path $candidate)) {
                    $resolved = $true; break
                }
            }
            if (-not $resolved) {
                $broken += [pscustomobject]@{ File = $relFile; Line = $lineNo; Ref = $ref }
            }
        }
    }
}

Write-Host "doc-lint: scanned $($docFiles.Count) governance docs under $Root"

if ($missingKit.Count -gt 0) {
    Write-Host "ERROR: kit incomplete — $($missingKit.Count) required path(s) missing (dot-directories skipped during copy?):"
    foreach ($m in $missingKit) { Write-Host "  $m" }
}

if ($slotCount -gt 0) {
    $level = $FailOnSlots ? 'ERROR' : 'INFO'
    Write-Host "${level}: $slotCount unfilled {{SLOT}} / TODO(...) markers remain (expected in the kit template; must be 0 after ratification)"
}

if ($broken.Count -gt 0) {
    Write-Host "ERROR: $($broken.Count) referenced path(s) do not resolve:"
    foreach ($b in $broken) { Write-Host ("  {0}:{1}  {2}" -f $b.File, $b.Line, $b.Ref) }
}

if ($missingKit.Count -gt 0 -or $broken.Count -gt 0 -or ($FailOnSlots -and $slotCount -gt 0)) { exit 1 }
Write-Host 'doc-lint: OK — kit complete, every referenced path resolves'
exit 0
