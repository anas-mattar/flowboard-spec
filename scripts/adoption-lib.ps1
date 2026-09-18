<#
.SYNOPSIS
    Shared reader for the adoption record's developer declaration.

.DESCRIPTION
    Dot-sourced by scripts/enforcement-pack.ps1 (which enforces) and scripts/verify-kit.ps1
    (which reports). Feature 012 established this pattern with scripts/scope-lib.ps1, for the
    same reason: two graders of one rule drift, and a comment claiming they agree is not a
    mechanism.

    That is not a hypothetical here. Feature 013 shipped the logic twice, and it went wrong
    in both of the ways duplication allows, inside one feature: the copies drifted (the
    root-object guard landed in the enforcing copy only), and the reporting copy used two
    comparers that disagreed with each other. The drift was found by a reviewer reading a
    comment asserting the two copies matched exactly.

    Get-DeveloperMode returns one object describing the record, and BOTH behaviours are read
    from it: the mode the check enforces, and the problems the doctor reports. Neither script
    interprets the record itself.
#>

# The evidence mode for the Critical lane (docs/sdlc/critical-delivery.md item 5), derived
# from the project's declared developers — never declared directly, so a project cannot
# assert team independence while naming one person.
#
# Every degenerate input resolves to 'solo', the stricter arm: no record, an unreadable or
# unparsable one, a root that is not a JSON object, no field, a non-array, an empty array, an
# array of blanks. Adoptions predating this feature declare nothing, and any other default
# would silently drop a requirement in projects that never asked.
#
# Returns:
#   Mode      'solo' | 'team'
#   Count     usable developers after trimming, dropping non-strings/blanks, and collapsing
#             duplicates case-insensitively
#   Why       one clause naming the reason, for the caller's message
#   Declared  whether the record declares the field at all, so no caller needs its own notion
#             of "is this declared" — a second such notion had grown in the doctor
#   Problems  zero or more @{ Message; Fix } the doctor reports. The check ignores them, and
#             the reason is narrower than it first looks: a problem never makes a record
#             produce a LAXER mode than it would without the malformation. It does NOT mean
#             every problem lands on solo — ["ada","grace"," "] is malformed and is team.
#             Getting that reason wrong is how a maintainer talks themselves out of the
#             doctor (013 phase 5 review, NEW-4)
function Get-DeveloperMode {
    param([Parameter(Mandatory)][string]$Root)

    $problems = [System.Collections.Generic.List[object]]::new()
    $recordPath = Join-Path $Root 'kit-adoption.json'
    if (-not (Test-Path -LiteralPath $recordPath)) {
        return @{ Mode = 'solo'; Count = 0; Declared = $false; Why = 'no kit-adoption.json'; Problems = $problems }
    }

    # Inside the try: 'unreadable' is one of the degenerate records FR-003 names, and a read
    # can fail on a path Test-Path accepts — a directory, a lock, a permission denial, a
    # dangling symlink. Phase 4 moved this read out of the try and, with
    # $ErrorActionPreference = 'Stop', an unreadable record became an unhandled error that
    # skipped every check ordered after this one (013 phase 4 re-review, N2).
    try {
        # -ErrorAction Stop so the catch fires regardless of the caller's preference. Both
        # shipped callers set 'Stop', but a library that only works under one caller's
        # settings is not self-contained (013 phase 5 review, NEW-E).
        $rawRecord = "$(Get-Content -LiteralPath $recordPath -Raw -ErrorAction Stop)"
    } catch {
        return @{ Mode = 'solo'; Count = 0; Declared = $false; Why = 'kit-adoption.json could not be read'; Problems = $problems }
    }

    # The root must be a JSON OBJECT, judged from the TEXT. Testing the parsed value is not
    # enough: ConvertFrom-Json emits array elements to the pipeline one at a time, so a
    # single-element root array collapses to one PSCustomObject indistinguishable from a real
    # record. The root of a JSON document is whatever the first non-whitespace character
    # opens, so this test cannot be fooled by a brace inside a string.
    if ($rawRecord.TrimStart([char]0xFEFF, ' ', "`t", "`r", "`n") -notmatch '^\{') {
        $problems.Add(@{ Message = 'kit-adoption.json is not a JSON object at its root'; Fix = 'the record is a single JSON object; a root array is ignored entirely and the project falls back to the solo evidence rule' })
        return @{ Mode = 'solo'; Count = 0; Declared = $true; Why = 'kit-adoption.json is not a JSON object at its root'; Problems = $problems }
    }
    try {
        $record = $rawRecord | ConvertFrom-Json
    } catch {
        return @{ Mode = 'solo'; Count = 0; Declared = $false; Why = 'kit-adoption.json does not parse'; Problems = $problems }
    }
    if ($record -isnot [PSCustomObject]) {
        return @{ Mode = 'solo'; Count = 0; Declared = $false; Why = 'kit-adoption.json is not a JSON object'; Problems = $problems }
    }

    if ($null -eq $record.developers) {
        # An explicit `"developers": null` is the same unfinished edit as `[]` and is reported
        # the same way — but only when the key is really present. An ABSENT key is the
        # supported default for every adoption predating this feature and must stay silent.
        if ($rawRecord -match '(?m)"developers"\s*:') {
            $problems.Add(@{ Message = 'kit-adoption.json developers is null'; Fix = 'name the project''s developers, or remove the key — an explicit null is treated as solo, the same as an empty array' })
            return @{ Mode = 'solo'; Count = 0; Declared = $true; Why = 'developers in kit-adoption.json is null'; Problems = $problems }
        }
        return @{ Mode = 'solo'; Count = 0; Declared = $false; Why = 'no developers declared in kit-adoption.json'; Problems = $problems }
    }
    if ($record.developers -isnot [Array]) {
        $problems.Add(@{ Message = 'kit-adoption.json developers is not an array'; Fix = 'declare it as a JSON array of names, e.g. ["ada", "grace"] — a non-array is ignored and the project is treated as solo (adoption/updating.md)' })
        return @{ Mode = 'solo'; Count = 0; Declared = $true; Why = 'developers in kit-adoption.json is not an array'; Problems = $problems }
    }

    $entries = @($record.developers)
    $named = @($entries |
        Where-Object { $_ -is [string] -and -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { $_.Trim() })
    if ($entries.Count -eq 0) {
        $problems.Add(@{ Message = 'kit-adoption.json developers is empty'; Fix = 'name the project''s developers, or remove the field — an empty array is indistinguishable from an unfinished edit and is treated as solo' })
    } elseif ($named.Count -ne $entries.Count) {
        $problems.Add(@{ Message = 'kit-adoption.json developers contains a blank or non-string entry'; Fix = 'every entry is a non-empty name; blanks and non-strings are dropped before the count is taken, which can silently move the project from team back to solo' })
    }

    # ONE comparer for detecting duplicates and for naming them. Two comparers that disagree
    # would dereference an empty group (013 phase 4 re-review, N6).
    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $unique = [System.Collections.Generic.List[string]]::new()
    $firstDupe = $null
    foreach ($n in $named) {
        if ($seen.Add($n)) { $unique.Add($n) } elseif (-not $firstDupe) { $firstDupe = $n }
    }
    if ($firstDupe) {
        $problems.Add(@{ Message = "kit-adoption.json developers lists '$firstDupe' more than once (case-insensitively)"; Fix = 'one entry per person — duplicates are collapsed before the count is taken, so the extra entry changes nothing except how the record reads' })
    }

    $mode = if ($unique.Count -ge 2) { 'team' } else { 'solo' }
    $noun = if ($unique.Count -eq 1) { 'developer' } else { 'developers' }
    return @{
        Mode     = $mode
        Count    = $unique.Count
        Declared = $true
        Why      = "$($unique.Count) $noun declared in kit-adoption.json"
        Problems = $problems
    }
}
