# Agentic SDLC Kit

A reusable governance framework for delivering software with AI coding agents under human
control. Extracted from a production deployment (a multi-entity financial management system)
that shipped **68 features** under it — every one spec-first, phase-gated, and human-approved.

The kit is not a library or a tool: it is the **document system** that makes an AI agent a
controlled engineering assistant instead of an enthusiastic liability. It targets the failure
modes that actually sink agent-driven delivery:

| Agent failure mode | Kit countermeasure |
|---|---|
| Claims success without proof | The **user** runs the gate and confirms the exit code; the agent may never self-certify |
| Scope creep / drive-by refactors | One approved phase at a time; `git diff --stat` after every phase |
| Hallucinated requirements or UI | Ordered source-of-truth ladder; on conflict, **stop and report** |
| "Creative" violations of domain rules | Domain invariants with constitutional force |
| Big-bang failure | Phase-per-commit; rollback checklist before work starts |
| One model's blind spots | AI review + mandatory human review + periodic second-model audits |

## What's inside

```text
CLAUDE.md                      Thin agent entry point ({{SLOT}}s to fill) — the always-loaded core
AGENTS.md                      Cross-agent pointer (@CLAUDE.md) so non-Claude agents inherit the same law
.specify/memory/constitution.md  The constitution template (13 principles; the project's ONLY constitution)
.specify/                      Stock Spec Kit 0.4.4: templates, PowerShell scripts, init receipt
.claude/commands/              Stock /speckit.* commands (specify, plan, tasks, implement, analyze, …)
docs/sdlc/                     The process law: gate-command, review-process, rollback-process,
                               branch-strategy, repository-strategy, deployment-standards,
                               definition-of-done, team-workflow (multi-developer layer)
docs/rulebooks/                Tier rulebook menu: templates for backend, frontend, mobile,
                               database, integration + a skeleton for any other tier —
                               instantiate only the tiers your project has (see its README)
specs/_templates/              House templates: ai-code-review, human-pr-review, rollback, roadmap
modules/finance/               Worked example of a domain-invariants pack (write your own for your domain)
adoption/                      Step-by-step tracks: greenfield.md and existing-system.md
```

Layer anatomy: **governance** (constitution + CLAUDE.md) → **process** (docs/sdlc + Spec Kit)
→ **rulebooks** (docs/rulebooks, grown reactively) → **feature trail** (specs/NNN-name/ per
feature) → **feedback loops** (AI review, human review, second-model audits).

## Quick start

1. Copy this repository's contents into your project (or use it as a template repo).
2. Follow the adoption track that matches you:
   - New system: [`adoption/greenfield.md`](adoption/greenfield.md)
   - Existing codebase: [`adoption/existing-system.md`](adoption/existing-system.md)
3. The short version: fill every `{{SLOT}}` and `TODO(...)` in
   `.specify/memory/constitution.md` and `CLAUDE.md`, write your domain-invariants pack,
   define the gate in `docs/sdlc/gate-command.md` and **prove it green** — then ship feature
   `001` through the full ritual before anything real.

Machine assist for the mechanical part: `pwsh -File scripts/init-kit.ps1` asks your project
name, topology, and tiers, then instantiates the selected rulebooks, wires CLAUDE.md's
Task-Scoped Reading table, fills the mechanical slots, and prints the judgment slots that
remain yours (gates, invariants, stack profile). It generates no rulebook content — the
judgment stays human.

Find remaining slots at any time:

```bash
grep -rn "{{\|TODO(" --include="*.md" .
```

## The non-negotiables

Everything else adapts to your stack; these five do not:

1. **Spec before code** — spec.md, plan.md, tasks.md exist and are approved first.
2. **One phase at a time** — the agent stops after each phase and waits for approval.
3. **The user holds the gate** — the agent never claims success without the user-confirmed
   exit code.
4. **Stop and report on conflict** — the agent never silently chooses between conflicting
   sources of truth.
5. **Human review before merge** — AI review is necessary but never sufficient.

## Conventions this kit fixes at birth

- **Exactly one constitution** (`.specify/memory/constitution.md`); other docs point at it.
- **Stock Spec Kit layout** — `NNN-name` branches ↔ `specs/NNN-name/` directories, so the
  bundled scripts and `/speckit.*` commands work unmodified.
- **Every referenced path must resolve** — add a doc-lint check in CI on day one; drift
  between the rules and reality is what kills rule-based frameworks.

## Provenance

Patterns extracted 2026-08 from a live deployment: the constitution format (SYNC IMPACT
REPORT + per-principle rationale), the Constitution Check gate in plan-template, the
phase-gate tasks shape, the user-held gate ritual, the compliance-checklist meta-structure,
the break-glass template, and the audit → numbered-remediation loop are all battle-tested;
the drift fixes above are the lessons from its first 68 features.
