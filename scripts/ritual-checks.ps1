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
      3b. scripts/scope-check-repos.ps1 -All  (the same grading for the nested code
                                         repositories declared in kit-adoption.json —
                                         reports n/a, distinct from OK, when none are
                                         declared or none is present here, which is the
                                         kit repository, every single-repo adoption, and
                                         governance CI; 012)
      4. scripts/build-digests.ps1 -Check  (law-digest freshness — reports n/a, distinct
                                         from OK, until digest markers exist; 010)
      5. scripts/verify-kit.ps1         (the adoption doctor — ADOPTED PROJECTS ONLY,
                                         gated on .kit-version OR kit-adoption.json at
                                         -Root, mirroring the doctor's own discriminator;
                                         a tree with neither marker shows an explicit n/a
                                         line, excluded from the failure count — 007 US3)
      6. scripts/roadmap-claim-check.ps1  (every NNN-* claim on origin must have a
                                         non-idea roadmap row — GAP-017; reports n/a
                                         with no remote, an unreachable ledger, or no
                                         Status-bearing roadmap table — 011)

    Each member runs as a child pwsh process (the member scripts terminate with `exit`),
    and the wrapper ends with a verdict block, one line per member, then
    'ritual-checks: RESULT OK|UNGRADED|FAIL'. Exit 0 iff every member exits 0. Read-only.

    THE VERDICT VOCABULARY (feature 015, FR-009; plan D4, D5, D7). Six words, defined here
    once because this script is the single entry point an adopted project runs (FR-012).
    Read 'the check' as 'the run of that member', since a member may grade many commits or
    many repositories:

      OK        The check ran, compared what it claims to compare, and found nothing. The
                word is 'OK' and not 'PASS' because nine scripts, three adopted projects
                and every gate record written to date already say OK (plan D4).
      FAIL      The check ran and found a violation. It is the only word in this block that
                exits 1 - and it is equally what a member's non-zero exit renders when the run
                never reached a verdict at all (an unreadable -Root, a malformed argument).
                The derivation below reads the exit code and does not read the output, so an
                aborted run and a real violation are one word here. HOW a member announces
                such an abort is not uniform; see WHAT THIS BLOCK DOES NOT CLAIM.
      WARN      The check ran, formed an opinion, and that opinion is advisory. It observed
                something real and is not blocking on it (e.g. PhaseSizeWarning).
      N/A       The check DOES NOT APPLY here - a doctor in an unadopted tree, a roadmap
                check with no roadmap table. A positive, honest claim about scope.
      UNGRADED  The check applies and RAN AND FORMED NO OPINION: no computable diff base,
                unreadable history, a depth-1 clone whose base is absent. It is not OK (it
                compared nothing), not N/A (it does apply), and not WARN (it observed
                nothing). Before feature 015 this state had no word, so it printed OK and a
                run that graded nothing was indistinguishable from a clean one - GAP-027.
                UNGRADED changes the VERDICT, never the exit code (plan D6, FR-011).
      PENDING   RESERVED, and emitted by nothing today (grep confirms it). It belongs to
                GAP-022 - a Critical branch red from its first commit to its last - which is
                out of scope here. Defined now so GAP-022's eventual fix is not also a
                vocabulary change (plan D7). A state nothing emits is documented as reserved
                rather than left implicit; if you are adding an emission of PENDING, the
                rule you are implementing needs its own feature first.

    HOW THIS SCRIPT CHOOSES THE WORD, which is the whole of the mechanism - nothing else in
    a member's output affects its verdict line:

      1. Member exit code non-zero                            -> FAIL. Output is not read.
      2. Exit 0, member listed in $captureMembers, and its output contains a line matching
         ^<member>: UNGRADED                                  -> UNGRADED, reason echoed.
      3. Exit 0, same capture condition, ^<member>: n/a        -> n/a, reason echoed.
      4. Exit 0, anything else                                -> OK.

    So the verdict block prints FOUR of the six words. WARN is never lifted: a member that
    warns exits 0 and reads as OK here, with the warning itself in its own output above.
    PENDING is emitted by nothing. Two further consequences, both load-bearing, and each got
    wrong once (phase 5 review, rounds 1 and 2):

      - A member NOT in $captureMembers has its output ignored entirely, so adding an
        UNGRADED line to one changes nothing here. That is exactly how scope-check shipped
        a fail-open through the phase that existed to close GAP-027.
      - The anchored patterns are scanned over the WHOLE of a member's output, first match
        wins. The verdict is NOT 'the last line': scope-check.ps1 ends an ordinary graded
        run on `scope-check: PASS phase 3 commit abc1234 (7 file(s))`, which this wrapper
        neither reads nor is misled by, because PASS is not looked for.

    WHAT THIS BLOCK DOES NOT CLAIM (phase 5 review, F2 across three rounds - each earlier
    revision of this paragraph asserted some kit-wide conformance that a grep or a single run
    disproves, the last of them inside the FAIL definition above, so the claim is now confined
    to the mechanism and every known exception is named here by path):

      - Members print words outside this vocabulary, by design, and they are findings and
        prose rather than verdicts: `PASS` and `not applicable` on the two scope checks'
        per-commit and per-repository lines, `ERROR:` and `INFO:` in doc-lint.ps1, indented
        issue bullets in enforcement-pack.ps1.
      - `scripts/update-kit.ps1` is an installer - spec.md:277 puts it among the scripts that
        perform actions rather than grade - is not a member of this wrapper, and is outside
        feature 015's Territory.
      - `scripts/territory-check.ps1` does not speak this vocabulary either: it prints
        `CLEAN`/`OVERLAP` and exits 0, 1 or 2, and it is not a member of this wrapper, so the
        derivation above never sees it. It is NOT out of scope, and an earlier revision of
        this block wrongly said it was: tasks.md:241 declares it inside phase 5's Territory
        and spec.md:274-277 counts it among the nine that decide a verdict. Reconciling it
        against FR-009 is unfinished business awaiting an owner decision (round 3 review, F2
        and F3) - not a boundary this block may invoke.
      - An invocation error is announced differently by different members, and defining a
        vocabulary does not make it uniform. `scripts/verify-kit.ps1` prints
        `verify-kit: ERROR root not found: ...`; the other six surface PowerShell's own
        unhandled-error output from the `Resolve-Path` on their `-Root` and print no `ERROR`
        line of their own. All seven exit 1, which is the only part the derivation uses.
      - `scripts/verify-kit.ps1` spells one state `not applicable` in full. That line is
        unreachable through this wrapper - it fires only against the kit template, a tree
        with neither adoption marker, which does not run the doctor at all and gets the n/a
        line printed further down - and verify-kit is not in $captureMembers, so the
        spelling makes no difference here either way.

    What remains unreconciled is listed above rather than dismissed. T039 ('emit UNGRADED from
    every member that can return without grading') is ticked, so a claim that no task reaches
    these would be false; whether they are reconciled here, deferred, or answered by amending
    FR-009 is an owner decision on the round 3 review, not a call this block makes.

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
    'scope-repos'      = @((Join-Path $scriptsDir 'scope-check-repos.ps1'), '-All', '-Root', $Root) + $branchArgs
    'digests'          = @((Join-Path $scriptsDir 'build-digests.ps1'), '-Check', '-Root', $Root)
    'roadmap-claims'   = @((Join-Path $scriptsDir 'roadmap-claim-check.ps1'), '-Root', $Root) + $branchArgs
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
$naReasons = @{}
$ungradedReasons = @{}
# Members whose n/a states (010 SC-004; 011 no-ledger/no-table) are distinct verdicts,
# not OK: capture their output (re-echoed verbatim) to read the n/a line while keeping
# the exit-code contract identical to the other members.
$naCapableMembers = @('digests', 'roadmap-claims', 'scope-repos')
# Members that can report UNGRADED - they RAN and formed no opinion (feature 015, FR-010).
# Captured for the same reason and by the same mechanism as an n/a line: reading the
# member's own words keeps every member exit code byte-identical to today, which is what
# plan D6 requires. A dedicated exit code would itself have been an exit-code change, and
# FR-011 says any such change is stated explicitly and separately - so there is not one.
#
# scope-check and scope-repos joined in the phase-5 remediation (review F1). They carried
# the identical GAP-027 fail-open: on the same depth-1 clone GAP27-001 and GAP27-004 build,
# scope-check printed 'WARN ... nothing checked' and this block summarised it OK. Being
# left out of this list was half of that defect - the other half was the member's own word.
$ungradedCapableMembers = @('enforcement-pack', 'scope-check', 'scope-repos')
$captureMembers = @($naCapableMembers + $ungradedCapableMembers | Select-Object -Unique)
foreach ($name in $members.Keys) {
    Write-Host "=== ritual-checks: $name ==="
    if ($name -in $captureMembers) {
        $out = & pwsh -NoProfile -File @($members[$name]) 2>&1
        $results[$name] = $LASTEXITCODE
        $out | ForEach-Object { Write-Host $_ }
        if ($results[$name] -eq 0) {
            # Echo the member's own n/a reason into the summary (phase 1 review F5).
            $naLine = @($out | ForEach-Object { "$_" } | Where-Object { $_ -match "^${name}: n/a" }) | Select-Object -First 1
            if ($naLine) { $naReasons[$name] = $naLine.Substring("${name}: ".Length) }
            # The same idiom for the state this feature adds. Anchored on the member's own
            # name so a line that merely quotes the word inside a longer sentence - a
            # failure message explaining UNGRADED, say - cannot be read as the verdict.
            $ungradedLine = @($out | ForEach-Object { "$_" } | Where-Object { $_ -match "^${name}: UNGRADED" }) | Select-Object -First 1
            if ($ungradedLine) { $ungradedReasons[$name] = $ungradedLine.Substring("${name}: ".Length) }
        }
    } else {
        & pwsh -NoProfile -File @($members[$name])
        $results[$name] = $LASTEXITCODE
    }
    Write-Host ''
}

$failedCount = 0
$ungradedCount = 0
foreach ($name in $results.Keys) {
    $verdict = if ($results[$name] -eq 0) {
        # Order matters: UNGRADED outranks n/a outranks OK. A member that formed no opinion
        # must not be summarised by whichever other word also happens to fit.
        if ($ungradedReasons.ContainsKey($name)) { $ungradedCount++; $ungradedReasons[$name] }
        elseif ($naReasons.ContainsKey($name)) { $naReasons[$name] }
        else { 'OK' }
    } else { $failedCount++; 'FAIL' }
    Write-Host ('ritual-checks: {0,-16} {1}' -f $name, $verdict)
}
if ($doctorNA) {
    Write-Host ('ritual-checks: {0,-16} {1}' -f 'verify-kit', 'n/a (no adoption markers — kit repository or unadopted tree)')
}
if ($failedCount -gt 0) {
    Write-Host "ritual-checks: RESULT FAIL ($failedCount of $($results.Count) member(s) failed)"
    exit 1
}
if ($ungradedCount -gt 0) {
    # Exit 0: the run did not fail, and FR-011 forbids making it fail. What it must not do
    # is print RESULT OK over the top of a member that compared nothing - that last line is
    # what a reader, a grep, and a status badge all take as the answer.
    Write-Host "ritual-checks: RESULT UNGRADED ($ungradedCount of $($results.Count) member(s) formed no opinion; nothing failed)"
    exit 0
}
Write-Host 'ritual-checks: RESULT OK'
exit 0
