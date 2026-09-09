<#
.SYNOPSIS
    Law digests: deterministically assembles per-pack one-page digests from curated
    in-document markers; -Check fails on any drift between the law and its digest.

.DESCRIPTION
    Contract: specs/010-law-digests/contracts/digest-checks.md.

    Source documents carry standalone marker lines authored beside their binding rules:

        <!-- digest: <one-line rule statement, at most 120 chars> -->

    Generate mode (default) assembles docs/digests/<pack>-digest.md for every pack in
    docs/digests/digest-packs.json whose documents carry at least one marker: a fixed
    header plus one bullet per marker in document order (document order = manifest
    member order), LF line endings, byte-deterministic (same inputs, same bytes). A
    pack with zero markers produces no file and none is demanded. The generator never
    writes source documents — markers are authored by humans/agents in ordinary edits.

    -Check regenerates in memory and compares (line-ending-normalized, so a CRLF
    checkout never counts as drift) against the committed digests. Stale or hand-edited
    digest, missing digest for a marked pack, orphan *-digest.md, empty marker text,
    manifest document missing on disk, or a bound exceeded: each FAILs (exit 1) naming
    the file (and line where applicable), the violated condition, and the fix. When no
    manifest document carries a marker AND docs/digests/ holds no *-digest.md, the
    check is n/a (exit 0): the machinery ships inert and arms itself the moment a
    project marks its own law (010 SC-004). Wired as ritual-checks member 'digests'.

    Markers inside multi-line HTML comment blocks are ignored — a commented-out
    section's markers vanish with it (010 research D6) — and so are markers inside
    fenced code blocks, so documentation may show the syntax literally (phase 1 review
    F3). Only standalone marker lines count (nothing but whitespace around the
    comment), the grammar is exact and lowercase, and a near-miss line that starts
    like a marker but breaks the grammar (wrong case, missing colon, '-->' inside the
    text, unclosed comment) FAILs rather than vanishing silently (review F6/F7).

    Digests are orientation aids only: never a source-of-truth rung, never a substitute
    for reading the full document before acting on its area (constitution II unchanged).

    Bounds (010 owner-ratified constants): MaxDigestContentLines = 40 bullets per
    digest, MaxDigestLineLength = 120 chars of marker content.

.EXAMPLE
    pwsh -File scripts/build-digests.ps1              # (re)generate the digests
    pwsh -File scripts/build-digests.ps1 -Check       # freshness verdict (CI member)
    pwsh -File scripts/build-digests.ps1 -Check -Root ../my-project
#>
[CmdletBinding()]
param(
    [switch]$Check,
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path $Root).Path

$MaxDigestContentLines = 40
$MaxDigestLineLength   = 120

$manifestRel  = 'docs/digests/digest-packs.json'
$manifestPath = Join-Path $Root $manifestRel
$digestsDir   = Join-Path $Root 'docs/digests'
$regenCmd     = 'regenerate: pwsh -File scripts/build-digests.ps1'

$issues = @()

# --- Marker extraction (research D6: line scan with in-comment state) ------------------
# A digest marker counts only when it is a standalone line NOT inside a multi-line HTML
# comment block opened on an earlier line. Extraction order is document order; the same
# document is scanned once even if several packs list it (cache below).
$docCache = @{}
function Get-DocMarkers {
    param([string]$RelPath)
    if ($docCache.ContainsKey($RelPath)) { return $docCache[$RelPath] }
    $abs = Join-Path $Root $RelPath
    if (-not (Test-Path $abs -PathType Leaf)) {
        $script:issues += "missing document: $RelPath is named by $manifestRel but does not exist on disk — fix the manifest or restore the file"
        $docCache[$RelPath] = @()
        return @()
    }
    $markers = @()
    $inComment = $false
    $fenceClose = $null
    $lineNo = 0
    foreach ($rawLine in [IO.File]::ReadAllLines($abs)) {
        $lineNo++
        $line = $rawLine
        if ($fenceClose) {
            # Inside a fenced code block nothing counts (review F3): a literal marker
            # example in documentation prose must never be harvested into a digest.
            if ($line -match $fenceClose) { $fenceClose = $null }
            continue
        }
        if ($inComment) {
            $close = $line.IndexOf('-->')
            if ($close -lt 0) { continue }
            $inComment = $false
            # The remainder after the close may reopen a comment; a digest marker in it
            # is not a standalone line and therefore never counts.
            $line = $line.Substring($close + 3)
        } elseif ($rawLine -match '^\s{0,3}(`{3,}|~{3,})') {
            $f = $Matches[1]
            $fenceClose = '^\s{0,3}' + [regex]::Escape($f.Substring(0, 1)) + '{' + $f.Length + ',}\s*$'
            continue
        } elseif ($rawLine -cmatch '^\s*<!--\s*digest:(.*)-->\s*$' -and $Matches[1] -notmatch '-->') {
            $text = $Matches[1].Trim()
            if (-not $text) {
                $script:issues += "empty digest marker: ${RelPath}:${lineNo} — write the one-line rule statement or remove the marker"
            } elseif ($text.Length -gt $MaxDigestLineLength) {
                $script:issues += "digest line too long: ${RelPath}:${lineNo} is $($text.Length) chars (bound: MaxDigestLineLength = $MaxDigestLineLength) — tighten the one-liner"
            } else {
                $markers += [PSCustomObject]@{ Text = $text; Source = $RelPath }
            }
            continue
        } elseif ($rawLine -match '^\s*<!--\s*digest\b') {
            # Near-miss fail-closed (review F6/F7): a line that starts like a marker but
            # breaks the exact grammar would otherwise vanish silently — and the check
            # would then enforce the absence of a rule its author believed was marked.
            $script:issues += "malformed digest marker: ${RelPath}:${lineNo} — exact grammar is '<!-- digest: <text> -->' (lowercase, one line, closed, no '-->' inside the text)"
            # Fall through to the comment-state update so an unclosed '<!-- digest:'
            # still opens a comment block and the rest of the file parses sanely.
        }
        $lastOpen = $line.LastIndexOf('<!--')
        if ($lastOpen -ge 0 -and $line.IndexOf('-->', $lastOpen) -lt 0) { $inComment = $true }
    }
    $docCache[$RelPath] = $markers
    return $markers
}

# --- Deterministic assembly (data-model.md: header + bullets, LF) -----------------------
function Get-PackDigestContent {
    param([string]$PackName, [object[]]$Markers)
    $lines = @(
        "# $PackName pack — law digest (GENERATED)"
        ''
        '<!-- GENERATED FILE — do not edit. Regenerate: pwsh -File scripts/build-digests.ps1'
        '     Non-authoritative: for orientation only. The source documents prevail (constitution'
        '     II is unchanged); read the full document before acting on its area. -->'
        ''
    )
    foreach ($m in $Markers) {
        $lines += "- $($m.Text) (``$($m.Source)``)"
    }
    return ($lines -join "`n") + "`n"
}

function Get-NormalizedText {
    param([string]$Path)
    return ([IO.File]::ReadAllText($Path)) -replace "`r`n", "`n"
}

# --- Manifest -----------------------------------------------------------------------------
# Recursive, exact-name scan (review F8): a rogue digest in a subdirectory, or one whose
# name differs only by case, must not evade the orphan check.
$existingDigests = @(
    if (Test-Path $digestsDir) {
        Get-ChildItem $digestsDir -Recurse -File |
            Where-Object { $_.Name -like '*-digest.md' } |
            ForEach-Object { ([IO.Path]::GetRelativePath($digestsDir, $_.FullName)) -replace '\\', '/' }
    }
)

if (-not (Test-Path $manifestPath)) {
    if ($Check) {
        if ($existingDigests.Count -eq 0) {
            Write-Host 'digests: n/a (no digest manifest)'
            exit 0
        }
        Write-Host "digests: FAIL — $manifestRel not found but $($existingDigests.Count) *-digest.md file(s) exist — restore the pack manifest (it ships verbatim with the kit) or delete the digest files"
        exit 1
    }
    Write-Host "build-digests: FAIL — $manifestRel not found — restore the pack manifest (it ships verbatim with the kit)"
    exit 1
}
$packs = @((Get-Content $manifestPath -Raw | ConvertFrom-Json).packs)

# --- Expected state: per-pack markers and digest content ---------------------------------
$expected = [ordered]@{}   # digest file name -> content
$overBound = @()           # over-bound packs' digest names, kept out of the orphan scan (review F1)
$seenNames = @{}
$totalMarkers = 0
foreach ($pack in $packs) {
    $packName = [string]$pack.name
    # Fail-closed manifest validation (review F4): a bad name must never route a write
    # outside docs/digests/, and a duplicate must never silently swallow a pack's law.
    if ($packName -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
        $issues += "invalid pack name: '$packName' in $manifestRel — pack names must match ^[A-Za-z0-9][A-Za-z0-9._-]*$ (fix the manifest)"
        continue
    }
    if ($seenNames.ContainsKey($packName.ToLowerInvariant())) {
        $issues += "duplicate pack name: '$packName' in $manifestRel collides with '$($seenNames[$packName.ToLowerInvariant()])' — merge the packs or rename one (fix the manifest)"
        continue
    }
    $seenNames[$packName.ToLowerInvariant()] = $packName
    $markers = @(foreach ($doc in $pack.docs) { Get-DocMarkers $doc })
    $totalMarkers += $markers.Count
    if ($markers.Count -eq 0) { continue }
    if ($markers.Count -gt $MaxDigestContentLines) {
        $issues += "digest too long: pack '$packName' has $($markers.Count) content lines (bound: MaxDigestContentLines = $MaxDigestContentLines) — tighten or drop markers until the digest is one page"
        $overBound += "$packName-digest.md"
        continue
    }
    $expected["$packName-digest.md"] = Get-PackDigestContent $packName $markers
}

# Orphans: a *-digest.md present for a pack with zero markers, or not named by the
# manifest. Exact (case-sensitive) name match; an over-bound pack's digest is NOT an
# orphan — the fix there is trimming markers, not deleting the digest (review F1).
$orphans = @($existingDigests | Where-Object { ($expected.Keys -cnotcontains $_) -and ($overBound -cnotcontains $_) })

if ($Check) {
    # --- Check mode -----------------------------------------------------------------------
    if ($totalMarkers -eq 0 -and $existingDigests.Count -eq 0 -and $issues.Count -eq 0) {
        Write-Host 'digests: n/a (no digest markers)'
        exit 0
    }
    foreach ($name in $expected.Keys) {
        $abs = Join-Path $digestsDir $name
        if (-not (Test-Path $abs)) {
            $issues += "missing digest: docs/digests/$name — its pack's documents carry markers; $regenCmd"
        } elseif ((Get-NormalizedText $abs) -ne $expected[$name]) {
            $issues += "stale or hand-edited digest: docs/digests/$name does not match its sources — $regenCmd"
        }
    }
    foreach ($o in $orphans) {
        $issues += "orphan digest: docs/digests/$o — no manifest pack with markers produces it; delete it or add markers to its pack's documents"
    }
    if ($issues.Count -gt 0) {
        foreach ($i in $issues) { Write-Host "digests: FAIL — $i" }
        Write-Host "digests: RESULT FAIL ($($issues.Count) issue(s))"
        exit 1
    }
    Write-Host "digests: OK ($($expected.Count) digest(s) fresh, $totalMarkers marker(s))"
    exit 0
}

# --- Generate mode ---------------------------------------------------------------------
if ($issues.Count -gt 0) {
    foreach ($i in $issues) { Write-Host "build-digests: FAIL — $i" }
    Write-Host "build-digests: RESULT FAIL ($($issues.Count) issue(s)) — nothing written"
    exit 1
}
if ($expected.Count -eq 0) {
    Write-Host 'build-digests: no digest markers found — nothing to generate'
    exit 0
}
if (-not (Test-Path $digestsDir)) { New-Item -ItemType Directory -Path $digestsDir -Force | Out-Null }
foreach ($name in $expected.Keys) {
    [IO.File]::WriteAllText((Join-Path $digestsDir $name), $expected[$name])
    Write-Host "build-digests: wrote docs/digests/$name"
}
foreach ($o in $orphans) {
    Write-Host "build-digests: NOTE — orphan docs/digests/$o (no pack with markers produces it; -Check will FAIL until it is deleted or its pack gains markers)"
}
Write-Host "build-digests: OK ($($expected.Count) digest(s), $totalMarkers marker(s))"
exit 0
