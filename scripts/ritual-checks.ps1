<#
.SYNOPSIS
    Ritual checks wrapper: one entry point running every ritual machine check with
    identical verdicts locally and in CI.

.DESCRIPTION
    Contract: specs/006-verification-pack/contracts/ritual-checks-ci.md.

    Runs, in order, never short-circuiting (one run reports every problem):
      1. scripts/doc-lint.ps1
      2. scripts/enforcement-pack.ps1   (includes the ReviewProvenance check)
      3. scripts/scope-check.ps1 -All   (every phase commit since merge-base with main)
      4. scripts/verify-kit.ps1         (the adoption doctor — ADOPTED PROJECTS ONLY,
                                         gated on .kit-version OR kit-adoption.json at
                                         -Root, mirroring the doctor's own discriminator;
                                         a tree with neither marker shows an explicit n/a
                                         line, excluded from the failure count — 007 US3)

    Each member runs as a child pwsh process (the member scripts terminate with `exit`),
    and the wrapper ends with a verdict block, one line per member, then
    'ritual-checks: RESULT OK|FAIL'. Exit 0 iff every member exits 0. Read-only.

    CI note: pass -Branch explicitly — a pull_request checkout is a detached-HEAD merge
    commit where branch detection returns the literal 'HEAD'
    (.github/workflows/ritual-checks.yml does this).

.EXAMPLE
    pwsh -File scripts/ritual-checks.ps1
    pwsh -File scripts/ritual-checks.ps1 -Branch 006-verification-pack
#>
[CmdletBinding()]
param(
    [string]$Branch,
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
# A caller's PS 7.4+ profile may set this to $true, which would throw on the first failing
# member and lose the verdict block — the contract requires all members to run (review F3).
$PSNativeCommandUseErrorActionPreference = $false
$Root = (Resolve-Path $Root).Path
$scriptsDir = Join-Path $Root 'scripts'

$branchArgs = @()
if ($Branch) { $branchArgs = @('-Branch', $Branch) }

$members = [ordered]@{
    'doc-lint'         = @((Join-Path $scriptsDir 'doc-lint.ps1'), '-Root', $Root)
    'enforcement-pack' = @((Join-Path $scriptsDir 'enforcement-pack.ps1'), '-Root', $Root) + $branchArgs
    'scope-check'      = @((Join-Path $scriptsDir 'scope-check.ps1'), '-All', '-Root', $Root) + $branchArgs
}

# The adoption doctor joins for adopted projects. The gate mirrors the doctor's OWN
# discriminator (007 research D5.3/D7, phase 3 review F1): .kit-version OR
# kit-adoption.json — a record-bearing copy adoption without .kit-version must not be
# invisible to CI while a direct doctor run would be red. The kit repo (neither marker)
# gets an explicit n/a line, never a silent omission.
$doctorNA = $true
if ((Test-Path (Join-Path $Root '.kit-version')) -or (Test-Path (Join-Path $Root 'kit-adoption.json'))) {
    $members['verify-kit'] = @((Join-Path $scriptsDir 'verify-kit.ps1'), '-Root', $Root)
    $doctorNA = $false
}

$results = [ordered]@{}
foreach ($name in $members.Keys) {
    Write-Host "=== ritual-checks: $name ==="
    & pwsh -NoProfile -File @($members[$name])
    $results[$name] = $LASTEXITCODE
    Write-Host ''
}

$failedCount = 0
foreach ($name in $results.Keys) {
    $verdict = if ($results[$name] -eq 0) { 'OK' } else { $failedCount++; 'FAIL' }
    Write-Host ('ritual-checks: {0,-16} {1}' -f $name, $verdict)
}
if ($doctorNA) {
    Write-Host ('ritual-checks: {0,-16} {1}' -f 'verify-kit', 'n/a (no adoption markers — kit repository or unadopted tree)')
}
if ($failedCount -gt 0) {
    Write-Host "ritual-checks: RESULT FAIL ($failedCount of $($results.Count) member(s) failed)"
    exit 1
}
Write-Host 'ritual-checks: RESULT OK'
exit 0
