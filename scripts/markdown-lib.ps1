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

    Feature 016 found the fix for both was per-line (GAP-028): a code span that wrapped onto
    the next line of its paragraph looked like an unpaired backtick, so its '<!--' stayed
    armed and hid everything after it, in both consumers. Three review rounds then showed
    that every reading which disarms more than per-line pairing lets the amendment check
    count some hidden record as a grant: pairing spans across lines misreads backticks, and
    even disarming an opener that is not a comment reveals text hidden by an attribute or a
    title. So the fix is the digest generator's alone (016 D11). Spans are still paired one
    line at a time everywhere (Convert-SpanText, which the amendment check uses as it is),
    and the generator also disarms an opener its model finds cannot open a comment
    (Convert-CodeSpanMarkers says exactly when). In the amendment check GAP-028 stays, on
    purpose, fail-closed. Still not modelled: a '-->' inside a span that wraps, and a '<!--'
    opened mid-line in prose that runs on into later lines. That is the comment model's
    business; 016's phase 2 is scoped to make build-digests report a marker it passes over
    inside one.

    Three of these functions were enforcement-pack.ps1's. They live here because the next
    script to read a Markdown document should not be the fourth to learn it. Same reason
    scripts/scope-lib.ps1 exists for the two scope graders: one implementation cannot drift
    from itself.

.NOTES
    Not a runnable script — dot-source it:
        . (Join-Path $PSScriptRoot 'markdown-lib.ps1')

    Every function here is pure: no git, no file system, no working directory.
#>

# Disarm comment markers in one string. Both substitutions preserve length, which is what
# lets Convert-SpanText patch text in place by offset, and Convert-CodeSpanMarkers hand back
# lines of their input's lengths.
function Disable-CommentMarkers {
    param([string]$Text)
    return ($Text -replace '<!--', '<!@@') -replace '-->', '@@>'
}

# Disarm comment markers inside the inline code spans of ONE line. CommonMark pairs a run of
# N backticks with the next run of EXACTLY N, and a backslash-escaped backtick is literal and
# delimits nothing (K1's second trigger). A run with no partner on the line opens no span:
# an unrecognised span leaves its markers armed, which HIDES text rather than revealing it —
# the safe direction for a check whose job is to refuse an invisible record.
function Convert-SpanText {
    param([string]$Text)
    # Nothing to disarm, or nothing to disarm it with: the overwhelming majority of text, and
    # the reason this is a string scan rather than a character walk (a per-character loop over
    # every line of every graded blob cost ~9x the whole check's runtime — 014 SC-006).
    if ($Text -notmatch '`') { return $Text }
    if ($Text -notmatch '<!--' -and $Text -notmatch '-->') { return $Text }
    # Backtick runs, skipping any run a backslash escapes — '\`' is a literal backtick to
    # CommonMark and delimits nothing (K1's second trigger).
    $runs = @([regex]::Matches($Text, '(?<!\\)`+') | ForEach-Object { @{ Start = $_.Index; Len = $_.Length } })
    if ($runs.Count -lt 2) { return $Text }
    $result = $Text
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

# The DIGEST generator's reading of a whole document (016 D1, D10, D11): the per-line span
# pairing every line had before 016 (Convert-SpanText), plus one change. A '<!--' that result
# left armed is disarmed when the model below finds no way for it to open a comment. Returns
# the same number of lines, each the same length as its input, so a caller may index the
# result by line and take substrings of it by the raw line's offsets.
#
# The amendment-authority check does NOT use this: it keeps per-line Convert-SpanText (016
# D11). Three review rounds found that every reading which disarms more than per-line pairing
# let some record in a real comment, or hidden by a tag attribute or link title, count as a
# grant. Here the stakes are a digest line, and an opener this rule disarms wrongly costs at
# most a harvested marker the source never showed.
#
# An opener is disarmed when it sits inline and no '-->' follows it, in the raw text, before
# the next blank line: an inline comment cannot cross a blank line. That is GAP-028's wrapped
# span, whose quoted opener has no closer in its paragraph. What the model counts:
#   - Blank: a line of spaces and tabs only, as CommonMark reads it. A no-break space or a
#     form feed is content, so a comment runs on through it (016 round-3 review F1).
#   - Not inline: a fenced line, and a line inside a raw HTML block. A block is found on the
#     raw text after any list or block-quote markers and runs to its CommonMark end: a pre,
#     script, style or textarea block to its closing tag, a comment to its closer, a
#     processing instruction to '?>', a declaration to '>', CDATA to ']]>', any other tag to a
#     blank line. Raw HTML passes through to the browser, where a comment does cross a blank
#     line. A start of a block with one of the longer ends is honoured even inside a block
#     that ends at a blank line, and the enclosing block resumes when it closes (round-3 and
#     round-4 review F1). Every block start is read on fenced lines too, for the fence map
#     misreads some fences. A tag line that opens a pre, script, style or textarea element
#     later on the line takes that element's end, and its own block, which ends at a blank
#     line, resumes when the element closes (round-5 F1). Ends are read after the container
#     markers. These are the shapes the reviews found and the cases guard; containers are
#     otherwise not modelled (a container that closes does not end a block here). Each
#     modelled rule is meant to keep lines on the per-line result, but that is checked only
#     for the shapes the cases guard: round 5 found a rule of round 4 that disarmed more.
# Not modelled, and left on the per-line result: a code span that wraps is not recognised, so
# a '-->' inside one stays armed, and so does the '<!--' of one whose paragraph holds a '-->'
# later. Constructs other than comments that hide text (attributes, titles) are not modelled
# at all; a marker inside one may be harvested. The pre, script, style and textarea elements
# are modelled only as far as CommonMark's block end: an end tag of one anywhere on a line
# closes it, so one closed and reopened on a line ('<script>a</script><script>'), a
# '<script/>', an end tag inside an attribute or of another element, and the other elements
# whose text the browser reads raw (xmp, iframe, noembed, noframes, noscript, plaintext) or as
# RCDATA (title) are all read as closed or absent, and a marker inside one may be harvested.
# Modelling the reopen hid the blocks that start inside it and disarmed a real comment (016
# round-7 review F1).
# Not modelled either, and here the rule can disarm a real comment (FR-003's exception, 016
# round-8 and round-9 review F1): wherever this rule holds a block with a longer end that
# CommonMark does not hold at that line, whether because it misreads block structure or
# because it follows the browser into an element CommonMark's block does not contain. Until
# that end the block starts CommonMark reads are ignored, and the end returns to inline text
# (or to a block that ends at a blank line), so in a raw HTML block CommonMark started
# meanwhile a comment's opener with no closer before the blank line is disarmed, and a marker
# inside the comment may be harvested. The doors are examples, not a closed list: a real
# fence's line, an indented code block, a list item or block quote that CommonMark then
# closes, a start honoured inside a block that ends at a blank line, a tag line that takes its
# element's end, and a paragraph line whose indentation or ordered marker the container
# pattern strips. Closing it means modelling CommonMark's block structure.
function Convert-CodeSpanMarkers {
    param([string[]]$Lines)
    $out = [string[]]::new($Lines.Count)
    for ($i = 0; $i -lt $Lines.Count; $i++) { $out[$i] = Convert-SpanText -Text $Lines[$i] }
    # No opener anywhere means nothing more to disarm (016 R5).
    if (($Lines -join "`n") -notmatch '<!--') { return ,$out }

    $blankLine = '^[ \t]*\r?$'
    # Candidates first: each armed opener with no raw closer before the next blank line. A
    # document with none takes no further work (FR-010 as amended).
    $candidates = @{}
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $from = 0
        while (($p = $out[$i].IndexOf('<!--', $from)) -ge 0) {
            $from = $p + 4
            # From the opener's third character, so '<!-->' and '<!--->' close themselves.
            $closed = $Lines[$i].IndexOf('-->', $p + 2) -ge 0
            for ($k = $i + 1; -not $closed -and $k -lt $Lines.Count; $k++) {
                if ($Lines[$k] -match $blankLine) { break }
                if ($Lines[$k].IndexOf('-->') -ge 0) { $closed = $true }
            }
            if (-not $closed) {
                if (-not $candidates.ContainsKey($i)) { $candidates[$i] = [System.Collections.Generic.List[int]]::new() }
                $candidates[$i].Add($p)
            }
        }
    }
    if ($candidates.Count -eq 0) { return ,$out }

    $fenced = Get-FencedLineMap -Lines $Lines
    # Container markers before a block's first text: indentation, list markers, block quotes.
    $container = '^(?:[ \t]*(?:[-*+]|\d{1,9}[.)])(?=[ \t]|$)|[ \t]*>)*[ \t]*'
    # The end of the raw HTML block being read: $null outside one, 'blank' for a block that
    # ends at a blank line, otherwise the pattern of the line that ends it.
    $htmlEnd = $null
    # The block to return to when a block with a longer end, opened inside a block that ends
    # at a blank line, closes: the enclosing block runs on to its blank line (round-4 F1).
    $resume = $null
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $raw = $Lines[$i]
        $blank = $raw -match $blankLine
        $body = [regex]::Replace($raw, $container, '', 1)
        # A block start with a longer end than a blank line: honoured anywhere but inside a
        # block that already has one, fenced lines included. Every start is read on fenced
        # lines too, so a misread fence masks none. On a real fence's lines a start can also
        # mask a block start after the fence, and a comment there may be disarmed (see "Not
        # modelled" above).
        # A tag line that opens one of the four raw-text elements later on the line takes that
        # element's end too: the browser stays inside it past the blank line CommonMark ends at.
        $longEnd = if ($body -match '(?i)^<(pre|script|style|textarea)(\s|>|$)' -or
                       ($body -match '^<[A-Za-z/]' -and $body -match '(?i)<(pre|script|style|textarea)(\s|>|$)')) { '(?i)</(pre|script|style|textarea)>' }
                   elseif ($body -match '^<!--') { '-->' }
                   elseif ($body -match '^<\?') { '\?>' }
                   elseif ($body -match '^<!\[CDATA\[') { '\]\]>' }
                   elseif ($body -match '^<![A-Za-z]') { '>' }
                   else { $null }
        $inHtml = $false
        if ($longEnd -and ($null -eq $htmlEnd -or $htmlEnd -eq 'blank')) {
            $inHtml = $true
            # A tag line that opens the element later on the line starts a block that ends at
            # a blank line itself, so that block resumes when the element closes (round-5 F1).
            $resume = if ($htmlEnd -eq 'blank' -or
                          ($null -eq $htmlEnd -and $body -match '^<[A-Za-z/]' -and
                           $body -notmatch '(?i)^<(pre|script|style|textarea)(\s|>|$)')) { 'blank' } else { $null }
            # A block whose end is on its own opening line is over already.
            if ($body -match $longEnd) { $htmlEnd = $resume; $resume = $null } else { $htmlEnd = $longEnd }
        } elseif ($htmlEnd) {
            $inHtml = $true
            if ($htmlEnd -eq 'blank') { if ($blank) { $htmlEnd = $null } }
            # Ends are read after the container markers, so a block quote's own '>' does not
            # end a declaration.
            elseif ($body -match $htmlEnd) { $htmlEnd = $resume; $resume = $null }
        } elseif ($body -match '^<[A-Za-z/]') {
            $inHtml = $true
            $htmlEnd = 'blank'
        }
        if ($inHtml -or $fenced[$i] -or -not $candidates.ContainsKey($i)) { continue }
        foreach ($p in $candidates[$i]) { $out[$i] = $out[$i].Substring(0, $p) + '<!@@' + $out[$i].Substring($p + 4) }
    }
    return ,$out
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
