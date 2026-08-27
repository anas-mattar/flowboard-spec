# Finance Domain Invariants (worked example)

> **What this is**: the domain-invariant pack from the kit's reference deployment — a
> multi-entity financial management system that shipped 68 features under this framework.
> If your project is a financial system, adopt these (adjusted to your entity names) as
> `{{DOMAIN_INVARIANTS_PATH}}` and they carry constitutional force via principle VII.
> If not, use this file as the model for writing your own domain pack: name the data that
> must survive any refactor, the operations that are forbidden, and the approved additive
> alternatives.

## 1. Financial Data Protection

Financial transactions are immutable. Physical deletion is prohibited for Journals, Journal
Lines, Ledger Entries, Invoices, Payments, Receipts, Reconciliations, Consolidation Entries,
and FX Revaluation Entries. Corrections MUST be performed using reversal, adjustment, void,
cancellation, or status transition — each itself auditable.

**Rationale**: Immutable financial records are a regulatory and accounting requirement; only
additive corrections preserve the audit trail.

## 2. Accounting Integrity

Every journal MUST balance. The system MUST reject unbalanced postings. Posted journals are
append-only. Posted financial transactions MUST NOT be edited.

**Rationale**: Double-entry integrity is foundational; allowing unbalanced or editable
postings would corrupt the ledger.

## 3. Soft Delete for Master Data

Business master data MUST use soft delete. Physical deletion is prohibited unless explicitly
approved. This applies to entities such as Customers, Vendors, Accounts, Cost Centres,
Departments, Budgets, Legal Entities, and Configuration records.

**Rationale**: Master data is referenced by historical transactions; physical deletion would
break referential and audit integrity.

## 4. Entity Isolation

All financial transactions MUST belong to a legal entity. Data access MUST respect entity
boundaries. Users MUST only access entities they are authorized to access — enforced
server-side, fail-closed.

**Rationale**: Multi-entity finance requires strict isolation to prevent cross-entity data
leakage and unauthorized access.

## 5. Period Control

Posting into closed periods is prohibited. Period reopening MUST be auditable. All period
status changes MUST be logged.

**Rationale**: Period control protects the integrity of closed financial results and supports
auditable close processes.

## 6. Deterministic Financial Calculation

Financial calculations (aggregations, FX translation, depreciation, aging) require
deterministic validation — golden-fixture tests with hand-worked expected values that tie to
the cent. Rounding rules and rate-resolution rules are documented once and referenced, never
re-derived per feature.

**Rationale**: "Roughly right" does not exist in accounting; only exact, regression-covered
expectations catch an agent's silent drift.

## Rollback interaction

Reverting code or a migration MUST NOT cascade into physical deletion of the records in §1.
If a rollback would touch them, stop and report; resolve via a correcting entry
(see `docs/sdlc/rollback-process.md`).

---

*Writing your own pack (healthcare, e-commerce, logistics…): keep the shape — numbered
invariants, each with a MUST statement, the forbidden operation, the approved alternative,
and a one-line **Rationale**. Aim for 4–8 invariants; if you have twenty, most belong in an
ordinary rulebook, not the constitution-force pack.*
