<#
.SYNOPSIS
    Init-kit: guided initializer — turns the kit template into a project-specific ruleset.

.DESCRIPTION
    Run this in YOUR PROJECT's copy of the kit (after the copy step in adoption/, step 0) —
    it rewrites governance documents in place. It asks only the decisions that cannot be
    inferred (project name, repository topology, tiers), then:

      - instantiates a rulebook per selected tier
        (docs/rulebooks/<tier>-rules-template.md -> docs/rulebooks/<tier>-rules.md)
      - optionally deletes the unselected tier templates ("a menu, not a requirement" —
        docs/rulebooks/README.md)
      - wires CLAUDE.md's Task-Scoped Reading table: fills the {{..._RULES_PATH}} slots,
        deletes rows for tiers the project does not have, adds the mobile row when selected
      - fills the mechanical slots: {{PROJECT_NAME}}, {{BACKEND_REPO}}, {{FRONTEND_REPO}},
        {{REPOSITORY_LIST}}
      - prints the judgment slots that remain for a human (gate commands, PK standard,
        domain invariants, stack profile, ...)
      - finishes by running scripts/doc-lint.ps1

    It never generates rulebook content — instantiated rulebooks keep their fill-by-hand
    instructions, and the constitution is still ratified by a human (adoption tracks, step 1/2).
    Single-repo projects still remove constitution principle III (Repository Separation) by
    hand: it requires renumbering, which is a human edit.

.EXAMPLE
    pwsh -File scripts/init-kit.ps1

.EXAMPLE
    pwsh -File scripts/init-kit.ps1 -ProjectName Expenses -Topology single `
        -Tiers backend,database -DeleteUnusedTemplates -NonInteractive
#>
[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [string]$ProjectName,
    [ValidateSet('single', 'multi')]
    [string]$Topology,
    # backend | frontend | mobile | database | integration — array or comma-separated
    [string[]]$Tiers,
    [string]$BackendRepo,
    [string]$FrontendRepo,
    [switch]$DeleteUnusedTemplates,
    [switch]$NonInteractive
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path $Root).Path
$allTiers = 'backend', 'frontend', 'mobile', 'database', 'integration'

if ($Tiers) {
    # `pwsh -File` passes "a,b,c" as one string — accept both forms, then validate.
    $Tiers = @($Tiers -split ',' | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ })
    $unknown = @($Tiers | Where-Object { $_ -notin $allTiers })
    if ($unknown) { throw "Unknown tier(s): $($unknown -join ', '). Valid: $($allTiers -join ', ')" }
}

function Ask([string]$Prompt, [string]$Current) {
    if ($Current) { return $Current }
    if ($NonInteractive) { throw "Missing required value in -NonInteractive mode: $Prompt" }
    while ($true) {
        $answer = (Read-Host $Prompt).Trim()
        if ($answer) { return $answer }
    }
}

function AskYesNo([string]$Prompt, [bool]$Default) {
    if ($NonInteractive) { return $Default }
    $suffix = $Default ? '(Y/n)' : '(y/N)'
    $answer = (Read-Host "$Prompt $suffix").Trim().ToLower()
    if (-not $answer) { return $Default }
    return $answer -in 'y', 'yes'
}

# --- Collect the decisions -----------------------------------------------------------------
$ProjectName = Ask 'Project name' $ProjectName

if (-not $Topology) {
    $Topology = (AskYesNo 'Multiple repositories (one per tier)?' $false) ? 'multi' : 'single'
}

if (-not $Tiers) {
    if ($NonInteractive) { throw 'Missing -Tiers in -NonInteractive mode' }
    Write-Host 'Pick your tiers (docs/rulebooks/README.md — a menu, not a requirement):'
    $Tiers = @($allTiers | Where-Object { AskYesNo "  - $_ tier?" ($_ -in 'backend', 'frontend') })
    if ($Tiers.Count -eq 0) { throw 'No tiers selected — a project has at least one tier.' }
}

if ($Topology -eq 'multi') {
    if ($Tiers -contains 'backend') { $BackendRepo = Ask 'Backend repository name' $BackendRepo }
    if ($Tiers -contains 'frontend' -or $Tiers -contains 'mobile') {
        $FrontendRepo = Ask 'Frontend/app repository name' $FrontendRepo
    }
}

$deleteUnused = $DeleteUnusedTemplates -or
    (-not $NonInteractive -and (AskYesNo 'Delete the unselected tier templates?' $true))

if (-not $NonInteractive) {
    Write-Host ''
    Write-Host "About to rewrite governance docs under $Root"
    Write-Host "  project: $ProjectName | topology: $Topology | tiers: $($Tiers -join ', ')"
    if (-not (AskYesNo 'Continue?' $true)) { Write-Host 'Aborted — nothing changed.'; exit 0 }
}

# --- 1. Instantiate a rulebook per selected tier -------------------------------------------
$rulebookDir = Join-Path $Root 'docs/rulebooks'
foreach ($tier in $Tiers) {
    $template = Join-Path $rulebookDir "$tier-rules-template.md"
    $rulebook = Join-Path $rulebookDir "$tier-rules.md"
    if (Test-Path $rulebook) { Write-Host "keep:   docs/rulebooks/$tier-rules.md (already exists)"; continue }
    Copy-Item $template $rulebook
    Write-Host "create: docs/rulebooks/$tier-rules.md (fill its {{SLOT}}s — see its HOW TO FILL comment)"
}
if ($deleteUnused) {
    foreach ($tier in ($allTiers | Where-Object { $_ -notin $Tiers })) {
        $template = Join-Path $rulebookDir "$tier-rules-template.md"
        if (Test-Path $template) {
            Remove-Item $template
            Write-Host "delete: docs/rulebooks/$tier-rules-template.md (tier not selected)"
        }
    }
}

# --- 2. Wire CLAUDE.md's Task-Scoped Reading table ------------------------------------------
$claudeMd = Join-Path $Root 'CLAUDE.md'
$rowSlots = @{
    backend     = '{{BACKEND_RULES_PATH}}'
    frontend    = '{{FRONTEND_RULES_PATH}}'
    database    = '{{DATABASE_RULES_PATH}}'
    integration = '{{INTEGRATION_RULES_PATH}}'
}
$lines = [System.Collections.Generic.List[string]][IO.File]::ReadAllLines($claudeMd)

foreach ($tier in $rowSlots.Keys) {
    $slot = $rowSlots[$tier]
    if ($tier -in $Tiers) {
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $lines[$i] = $lines[$i].Replace($slot, "``docs/rulebooks/$tier-rules.md``")
        }
    }
    else {
        # The tier is absent: delete its table row rather than pointing at a file that isn't there.
        for ($i = $lines.Count - 1; $i -ge 0; $i--) {
            if ($lines[$i] -like '|*' -and $lines[$i].Contains($slot)) { $lines.RemoveAt($i) }
        }
    }
}
if ($Tiers -contains 'mobile') {
    $anchor = $lines.FindIndex({ param($l) $l -like '|*' -and $l.Contains('Reviewing / finishing') })
    $mobileRow = '| Mobile UI | `docs/rulebooks/mobile-rules.md` + `docs/rulebooks/` compliance checklist for that tier |'
    if ($anchor -ge 0) { $lines.Insert($anchor, $mobileRow) } else { $lines.Add($mobileRow) }
}
[IO.File]::WriteAllLines($claudeMd, $lines)
Write-Host 'wire:   CLAUDE.md Task-Scoped Reading table (rows match selected tiers)'

# --- 3. Fill the mechanical slots across the kit-owned governance docs ----------------------
$docFiles = @(
    @('CLAUDE.md', 'AGENTS.md', 'README.md', '.specify/memory/constitution.md') |
        ForEach-Object { Join-Path $Root $_ } | Where-Object { Test-Path $_ }
    foreach ($dir in 'docs', 'adoption', 'modules', 'specs/_templates') {
        $p = Join-Path $Root $dir
        if (Test-Path $p) { Get-ChildItem $p -Recurse -Filter *.md -File | ForEach-Object FullName }
    }
)

$repositoryList = $Topology -eq 'single' `
    ? 'This repository is the only repository.' `
    : (@(
        if ($BackendRepo)  { "- Backend: ``$BackendRepo``" }
        if ($FrontendRepo) { "- Frontend/app: ``$FrontendRepo``" }
        '- Per `docs/sdlc/repository-strategy.md`; always confirm the active repository.'
    ) -join "`n")

foreach ($file in $docFiles) {
    $text = [IO.File]::ReadAllText($file)
    $new = $text.Replace('{{PROJECT_NAME}}', $ProjectName).Replace('{{REPOSITORY_LIST}}', $repositoryList)
    if ($BackendRepo)  { $new = $new.Replace('{{BACKEND_REPO}}', $BackendRepo) }
    if ($FrontendRepo) { $new = $new.Replace('{{FRONTEND_REPO}}', $FrontendRepo) }
    if ($new -ne $text) { [IO.File]::WriteAllText($file, $new) }
}
Write-Host "fill:   {{PROJECT_NAME}} -> $ProjectName; {{REPOSITORY_LIST}}$(($BackendRepo -or $FrontendRepo) ? '; repository slots' : '')"

# --- 4. Report the judgment slots that remain for a human -----------------------------------
Write-Host ''
Write-Host '=== Remaining for a human (judgment, not mechanics) ==='
if ($Topology -eq 'single') {
    Write-Host '  - .specify/memory/constitution.md: DELETE principle III (Repository Separation) and renumber'
}
Write-Host '  - docs/sdlc/gate-command.md: define the gate(s) and PROVE them green (adoption, step 3)'
Write-Host '  - write the domain-invariants pack and point {{DOMAIN_INVARIANTS_PATH}} at it (constitution VII)'
Write-Host '  - each instantiated rulebook: fill its slots, delete untrue baseline rules'
Write-Host ''
$remaining = foreach ($file in $docFiles | Where-Object { Test-Path $_ }) {
    $rel = [IO.Path]::GetRelativePath($Root, $file) -replace '\\', '/'
    $n = ([regex]::Matches([IO.File]::ReadAllText($file), '\{\{[A-Z_]+\}\}|TODO\(')).Count
    if ($n -gt 0) { '  {0,3}  {1}' -f $n, $rel }
}
if ($remaining) {
    Write-Host 'Unfilled {{SLOT}} / TODO(...) markers by file:'
    $remaining | ForEach-Object { Write-Host $_ }
    Write-Host 'Locate them: grep -rn "{{\|TODO(" --include="*.md" .'
}

# --- 5. Doc-lint as the exit check -----------------------------------------------------------
Write-Host ''
& (Join-Path $PSScriptRoot 'doc-lint.ps1') -Root $Root
exit $LASTEXITCODE
