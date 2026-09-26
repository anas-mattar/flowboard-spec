<#
.SYNOPSIS
    How Markdown renders a comment marker: shared by every kit script that reads a document.

.DESCRIPTION
    Feature 014 learned this the expensive way. A '<!--' inside a fenced block or an inline
    code span is LITERAL TEXT, not a comment opener, and a check that misses the distinction
    reads a document nobody can see: 014's B7 truncated tasks.md from the line that quoted the
    syntax onward, hiding every approver record after it, and its first fix (a '(?s)```.*?```'
    sweep over the whole blob) re-paired fence runs across line starts and put a REAL comment
    inside a region the check called code — H1, reopened by its own fix.

    Feature 015 found the same blindness a third time, in build-digests.ps1 (GAP-025): one
    backticked '<!--' in prose opened a phantom comment that swallowed every digest marker
    after it, so the generator wrote a digest missing real rules and reported OK.

    These three functions were enforcement-pack.ps1's. They live here because the next script
    to read a Markdown document should not be the fourth to learn it. Same reason
    scripts/scope-lib.ps1 exists for the two scope graders: one implementation cannot drift
    from itself.

.NOTES
    Not a runnable script — dot-source it:
        . (Join-Path $PSScriptRoot 'markdown-lib.ps1')

    Every function here is pure: no git, no file system, no working directory.
#>

# Disarm comment markers in one string. Both substitutions preserve length, which is what
# lets Convert-CodeSpanMarkers patch a line in place by offset.
function Disable-CommentMarkers {
    param([string]$Text)
    return ($Text -replace '<!--', '<!@@') -replace '-->', '@@>'
}

# Disarm comment markers inside the inline code spans of ONE line. CommonMark pairs a run of
# N backticks with the next run of EXACTLY N, and a backslash-escaped backtick is literal and
# delimits nothing (K1's second trigger). A run with no partner on the line opens no span:
# an unrecognised span leaves its markers armed, which HIDES text rather than revealing it —
# the safe direction for a check whose job is to refuse an invisible record.
function Convert-CodeSpanMarkers {
    param([string]$Line)
    # Nothing to disarm, or nothing to disarm it with: the overwhelming majority of lines, and
    # the reason this is a string scan rather than a character walk (a per-character loop over
    # every line of every graded blob cost ~9x the whole check's runtime — SC-006).
    if ($Line -notmatch '`') { return $Line }
    if ($Line -notmatch '<!--' -and $Line -notmatch '-->') { return $Line }
    # Backtick runs, skipping any run a backslash escapes — '\`' is a literal backtick to
    # CommonMark and delimits nothing (K1's second trigger).
    $runs = @([regex]::Matches($Line, '(?<!\\)`+') | ForEach-Object { @{ Start = $_.Index; Len = $_.Length } })
    if ($runs.Count -lt 2) { return $Line }
    $result = $Line
    $r = 0
    while ($r -lt $runs.Count - 1) {
        $open = $runs[$r]
        $closeIdx = -1
        for ($k = $r + 1; $k -lt $runs.Count; $k++) {
            if ($runs[$k].Len -eq $open.Len) { $closeIdx = $k; break }
        }
        if ($closeIdx -lt 0) { $r++; continue }
        $from = $open.Start + $open.Len
        $len  = $runs[$closeIdx].Start - $from
        if ($len -gt 0) {
            $result = $result.Substring(0, $from) +
                      (Disable-CommentMarkers -Text $result.Substring($from, $len)) +
                      $result.Substring($from + $len)
        }
        $r = $closeIdx + 1
    }
    return $result
}

# True for each line that Markdown renders as CODE rather than as content: the lines of a
# fenced block, fences included. A fence OPENS on a line whose first non-space run (at most
# three spaces of indent) is three or more backticks or tildes, and CLOSES on a later line
# whose run is the same character and at least as long — CommonMark's rule, line by line.
# An unclosed fence runs to the end of the document, exactly as a renderer treats it.
function Get-FencedLineMap {
    param([string[]]$Lines)
    $map = New-Object 'bool[]' $Lines.Count
    # A document with no fence run at all has no fenced lines, and most do not.
    if (($Lines -join "`n") -notmatch '(?m)^ {0,3}(`{3,}|~{3,})') { return $map }
    $fenceChar = ''
    $fenceLen = 0
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $m = [regex]::Match($Lines[$i], '^ {0,3}(`{3,}|~{3,})')
        if ($fenceLen -gt 0) {
            $map[$i] = $true
            if ($m.Success -and $m.Groups[1].Value[0] -eq $fenceChar -and $m.Groups[1].Value.Length -ge $fenceLen) {
                $fenceChar = ''; $fenceLen = 0
            }
            continue
        }
        if ($m.Success) {
            $fenceChar = $m.Groups[1].Value[0]
            $fenceLen = $m.Groups[1].Value.Length
            $map[$i] = $true
        }
    }
    return $map
}
