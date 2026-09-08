<#
.SYNOPSIS
    Adoption doctor: read-only audit of an adopted project's kit integrity.

.DESCRIPTION
    Contract: specs/007-adoption-doctor/contracts/verify-kit-cli.md.

    Audits five dimensions, never short-circuiting — one run reports every problem, each
    finding carrying a fix pointer to the owning adoption step:

      1. Structure essentials — the kit-integrity required paths. This list MUST stay in
         sync with $requiredKitPaths in scripts/doc-lint.ps1 (research D2: same paths,
         different fix pointers — doc-lint says "the kit ships these", the doctor says
         "your adoption lost these").
      2. Slot completeness — no unfilled {{SLOT}} / TODO(...) in project-owned files
         (manifest class 'surgical'); the constitution is dimension 3's job.
      3. Constitution ratification — no template TODO/slot markers remain.
      4. Adoption record — kit-adoption.json parses (data-model.md shape), every declared
         tier has its instantiated rulebook, at least one exit-0 gate proof. Record absent
         entirely = WARN with creation instructions (pre-007 grandfathering).
      5. .kit-version sanity — present and plausible; absent = WARN with instructions.

    Declines to audit the kit template itself (no .kit-version AND the kit's own roadmap
    header) — a kit full of unfilled slots is the product, not a broken adoption.

    Read-only by contract: reports, never repairs. Exit 0 iff zero FAILs (warnings never
    fail — grandfather posture, research D8).

.EXAMPLE
    pwsh -File scripts/verify-kit.ps1
    pwsh -File scripts/verify-kit.ps1 -Root ../my-project    # e.g. from the kit clone
    pwsh -File scripts/verify-kit.ps1 -Json
#>
[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch {}

$findings = [System.Collections.Generic.List[object]]::new()
function Add-Finding {
    param([ValidateSet('FAIL', 'WARN', 'ok')] [string]$Level, [string]$Dimension, [string]$Message, [string]$Fix)
    $findings.Add([pscustomobject]@{ level = $Level; dimension = $Dimension; message = $Message; fix = $Fix })
}

# Keep in sync with scripts/doc-lint.ps1 $requiredKitPaths (research D2).
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
    'scripts/update-kit.ps1'
    'kit-manifest.json'
    'adoption/updating.md'
)

# Same glob resolution as doc-lint.ps1 / update-kit.ps1 (kit-manifest classes).
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
function Get-ManifestClass {
    param([string]$RelPath, [object[]]$Entries)
    $hits = @($Entries | Where-Object { $RelPath -match (ConvertTo-GlobRegex $_.path) })
    if ($hits.Count -eq 0) { return $null }
    $maxSpec = ($hits | ForEach-Object { Get-PatternSpecificity $_.path } | Measure-Object -Maximum).Maximum
    $winners = @($hits | Where-Object { (Get-PatternSpecificity $_.path) -eq $maxSpec })
    $classes = @($winners.class | Select-Object -Unique)
    if ($classes.Count -ne 1) { return $null }   # conflicts are doc-lint's finding, not ours
    return $classes[0]
}

$exitCode = 0
try {
    if (-not (Test-Path $Root)) { Write-Host "verify-kit: ERROR root not found: $Root"; exit 1 }
    $Root = (Resolve-Path $Root).Path

    $hasKitVersion = Test-Path (Join-Path $Root '.kit-version')

    # --- Decline: the kit template itself (research D5.1) ---
    # An adoption record VETOES the decline (research D5.3, review F2): a project that
    # wrote kit-adoption.json is an adoption no matter what its roadmap header says.
    if (-not $hasKitVersion) {
        $roadmapPath = Join-Path $Root 'docs/roadmap.md'
        $isKit = (Test-Path (Join-Path $Root 'kit-manifest.json')) -and
                 (-not (Test-Path (Join-Path $Root 'kit-adoption.json'))) -and
                 (Test-Path $roadmapPath) -and
                 ("$(Get-Content $roadmapPath -TotalCount 1)" -match '^#\s*Roadmap\s+—\s+Agentic SDLC Kit')
        if ($isKit) {
            Write-Host 'verify-kit: not applicable (this is the kit template, not an adoption)'
            if ($Json) { [pscustomobject]@{ verdict = 'not-applicable'; findings = @() } | ConvertTo-Json | Write-Host }
            exit 0
        }
    }

    # --- Dimension 1: structure essentials ---
    $missing = @($requiredKitPaths | Where-Object { -not (Test-Path (Join-Path $Root $_)) })
    if ($missing.Count -gt 0) {
        foreach ($m in $missing) {
            Add-Finding FAIL 'structure' "required kit path missing: $m" 're-copy the kit including dot-directories (adoption step 0 — adoption/greenfield.md / adoption/existing-system.md)'
        }
    } else {
        Add-Finding ok 'structure' 'all kit-integrity essentials present' ''
    }

    # --- Dimension 2: slot completeness in project-owned (surgical) files ---
    $manifestPath = Join-Path $Root 'kit-manifest.json'
    if (Test-Path $manifestPath) {
        $entries = @((Get-Content $manifestPath -Raw | ConvertFrom-Json).entries)
        $surfaces = [System.Collections.Generic.List[string]]::new()
        foreach ($f in 'CLAUDE.md', 'AGENTS.md', 'README.md') {
            if (Test-Path (Join-Path $Root $f)) { $surfaces.Add($f) }
        }
        foreach ($dir in 'docs', 'adoption', 'modules', 'specs/_templates') {
            $p = Join-Path $Root $dir
            if (Test-Path $p) {
                Get-ChildItem $p -Recurse -Filter *.md -File | ForEach-Object {
                    $surfaces.Add((([IO.Path]::GetRelativePath($Root, $_.FullName)) -replace '\\', '/'))
                }
            }
        }
        $slotHits = 0
        foreach ($rel in $surfaces) {
            if ((Get-ManifestClass -RelPath $rel -Entries $entries) -ne 'surgical') { continue }
            # Kit-shipped example/menu prose is kept, not filled (review F1; research D3):
            # tier/stack templates and the tier menu carry instructional markers forever,
            # and modules/** are worked examples a project replaces (its real invariants
            # live at the CLAUDE.md-declared path). Instantiated rulebooks stay scanned.
            if ($rel -match '(^|/)[^/]*-template\.md$' -or
                $rel -eq 'docs/rulebooks/README.md' -or
                $rel -match '^modules/') { continue }
            $content = "$(Get-Content -LiteralPath (Join-Path $Root $rel) -Raw)"
            $m = [regex]::Matches($content, '\{\{[A-Z_]+\}\}|TODO\(')
            if ($m.Count -gt 0) {
                $slotHits++
                Add-Finding FAIL 'slots' "$rel has $($m.Count) unfilled marker(s), first: $($m[0].Value)" 'fill the judgment slots this file owns (init-kit prints them; adoption steps 1-3)'
            }
        }
        if ($slotHits -eq 0) { Add-Finding ok 'slots' 'no unfilled slots in project-owned files' '' }
    } else {
        Add-Finding FAIL 'slots' 'kit-manifest.json missing — cannot resolve project-owned files' 're-copy the kit (adoption step 0)'
    }

    # --- Dimension 3: constitution ratification ---
    $constPath = Join-Path $Root '.specify/memory/constitution.md'
    if (Test-Path $constPath) {
        $const = "$(Get-Content -LiteralPath $constPath -Raw)"
        # Generic TODO( — speckit.constitution writes deferred fields as TODO(<FIELD>) (review F5).
        $marks = [regex]::Matches($const, 'TODO\(|\{\{[A-Z_]+\}\}')
        if ($marks.Count -gt 0) {
            Add-Finding FAIL 'constitution' "constitution still carries $($marks.Count) template marker(s), first: $($marks[0].Value)" 'ratify the constitution: fill every slot, set the version and ratification date (adoption step 1/2)'
        } else {
            Add-Finding ok 'constitution' 'constitution ratified (no template markers remain)' ''
        }
    }   # missing constitution is a dimension-1 finding already

    # --- Dimension 4: adoption record, declared tiers, gate proof ---
    $recordPath = Join-Path $Root 'kit-adoption.json'
    $knownTiers = 'backend', 'frontend', 'mobile', 'database', 'integration'
    if (-not (Test-Path $recordPath)) {
        Add-Finding WARN 'record' 'kit-adoption.json not found (adoption predates the doctor?)' 'create it per adoption/updating.md so declared tiers and the gate proof (adoption step 3) become checkable'
    } else {
        $record = $null
        try { $record = Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json } catch {}
        if (-not $record) {
            Add-Finding FAIL 'record' 'kit-adoption.json does not parse as JSON' 'repair it against the documented shape (adoption/updating.md)'
        } else {
            if ($record.schemaVersion -ne 1) {
                Add-Finding FAIL 'record' "kit-adoption.json schemaVersion '$($record.schemaVersion)' is not 1 (newer record than this doctor?)" 'update the kit, or set schemaVersion per the documented shape'
            }
            if (-not $record.projectName) {
                Add-Finding FAIL 'record' 'kit-adoption.json has no projectName' 'fill the record per the documented shape'
            }
            if ($record.topology -notin @('single', 'multi')) {
                Add-Finding FAIL 'record' "kit-adoption.json topology '$($record.topology)' is not single|multi" 'fix the record per the documented shape'
            }
            $tierFail = $false
            $declaredTiers = @($record.tiers) | Where-Object { $_ }
            if ($declaredTiers.Count -eq 0) {
                Add-Finding FAIL 'record' 'kit-adoption.json declares no tiers' 'declare the project''s tiers in the record (review F6; shape: adoption/updating.md)'
                $tierFail = $true
            }
            # Custom tiers are first-class (docs/rulebooks/README.md; phase 4 review F3,
            # option a — owner-ratified): ANY declared tier passes iff its instantiated
            # rulebook exists; the menu is a hint, not a wall.
            foreach ($tier in $declaredTiers) {
                if ("$tier" -notmatch '^[a-z][a-z0-9-]*$') {
                    Add-Finding FAIL 'record' "declared tier '$tier' is not a valid tier name (lowercase letters/digits/hyphens)" 'fix the tiers list in kit-adoption.json'
                    $tierFail = $true
                    continue
                }
                $rulebook = "docs/rulebooks/$tier-rules.md"
                if (-not (Test-Path (Join-Path $Root $rulebook))) {
                    $hint = ($tier -in $knownTiers) `
                        ? 'instantiate it from the tier template (docs/rulebooks/README.md), or remove the tier from kit-adoption.json' `
                        : 'author it from the custom-tier skeleton (docs/rulebooks/README.md — custom tiers are first-class), or remove the tier from kit-adoption.json'
                    Add-Finding FAIL 'record' "declared tier '$tier' has no instantiated rulebook at $rulebook" $hint
                    $tierFail = $true
                }
            }
            $proofOk = @($record.gateProof) | Where-Object { $_.exitCode -eq 0 }
            if (-not $proofOk) {
                Add-Finding FAIL 'record' 'no gate proof with exit code 0 recorded in kit-adoption.json' 'prove the gate green and record command/exitCode/date/recordedBy (adoption step 3 — "a gate that has never been green is not a gate")'
            }
            if (-not $tierFail -and $proofOk -and $record.projectName -and $record.schemaVersion -eq 1 -and $record.topology -in @('single', 'multi')) {
                Add-Finding ok 'record' "adoption record valid — tiers: $(@($record.tiers) -join ', '); gate proven" ''
            }
        }
    }

    # --- Dimension 5: .kit-version sanity ---
    if ($hasKitVersion) {
        $kv = "$(Get-Content -LiteralPath (Join-Path $Root '.kit-version') -Raw)".Trim()
        # update-kit.ps1 writes JSON: { kitVersion, kitCommit, updatedOn } — kitCommit is
        # the kit HEAD sha. Healthy = that JSON with a 7-40-hex kitCommit; a bare hex
        # token is accepted for hand-created files (adoption/updating.md instructions).
        # Anything else FAILs (review F4 strict rule, corrected to the REAL file shape —
        # phase 1 round 1/2 validated against a bare-sha fixture that update-kit never
        # writes).
        $kvCommit = $null
        try { $kvCommit = ("$kv" | ConvertFrom-Json).kitCommit } catch {}
        if ("$kvCommit" -match '^[0-9a-f]{7,40}$') {
            Add-Finding ok 'kit-version' ".kit-version present (kit commit $("$kvCommit".Substring(0, [Math]::Min(12, "$kvCommit".Length)))…)" ''
        } elseif ($kv -match '^[0-9a-f]{7,40}$') {
            Add-Finding ok 'kit-version' ".kit-version present (bare commit token $($kv.Substring(0, [Math]::Min(12, $kv.Length)))…)" ''
        } else {
            Add-Finding FAIL 'kit-version' '.kit-version is neither update-kit''s JSON record nor a bare commit sha (hand-edited or empty?)' 're-run scripts/update-kit.ps1 from a kit clone to rewrite it (adoption/updating.md)'
        }
    } else {
        Add-Finding WARN 'kit-version' '.kit-version not found (adopted by copy, never updated?)' 'create it per adoption/updating.md so update-kit and the manifest sweep can classify this project'
    }
} catch {
    Write-Host "verify-kit: ERROR $($_.Exception.Message)"
    exit 1
}

# --- Report ---
foreach ($f in $findings) {
    switch ($f.level) {
        'ok'   { Write-Host "verify-kit: ok $($f.dimension) — $($f.message)" }
        'WARN' { Write-Host "verify-kit: WARN $($f.dimension): $($f.message) — fix: $($f.fix)" }
        'FAIL' { Write-Host "verify-kit: FAIL $($f.dimension): $($f.message) — fix: $($f.fix)" }
    }
}
$failCount = @($findings | Where-Object level -eq 'FAIL').Count
$warnCount = @($findings | Where-Object level -eq 'WARN').Count
if ($failCount -gt 0) {
    Write-Host "verify-kit: FAIL ($failCount failure(s), $warnCount warning(s))"
    $exitCode = 1
} else {
    $suffix = $warnCount -gt 0 ? " ($warnCount warning(s))" : ''
    Write-Host "verify-kit: OK — adoption integrity verified$suffix"
}
if ($Json) {
    [pscustomobject]@{
        verdict  = $failCount -gt 0 ? 'FAIL' : 'OK'
        failures = $failCount
        warnings = $warnCount
        findings = $findings
    } | ConvertTo-Json -Depth 4 | Write-Host
}
exit $exitCode
