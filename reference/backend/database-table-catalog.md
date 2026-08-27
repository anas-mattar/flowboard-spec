# Database Table Catalog

Generated: 2026-07-07

Source of truth: `specs/feature/**/data-model.md`. This repository currently contains schema specification files only; no backend EF Core entity/migration source was found in the workspace.

Column types are logical/SQL Server-oriented types from the specs. `Mandatory?` means whether the value is required for a valid row. `System` means generated or stamped by the database/application. `Conditional` means required only for a specific status, mode, or workflow branch.

## Common Column Blocks

Most tables inherit one or more of these common blocks. Table sections list the blocks that apply, then list table-specific columns.

### Primary Key

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `Id` | `int IDENTITY(1,1)` | System | Surrogate primary key. GUID/UUID primary keys are prohibited by project standards unless explicitly approved. |

### Audit Columns

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `CreatedDate` | `datetime2` | System | UTC creation timestamp stamped by the application/database interceptor. |
| `CreatedBy` | `nvarchar(100/256)` | System | User or system principal that created the row. |
| `UpdatedDate` | `datetime2` | No | Last update timestamp, null until updated. |
| `UpdatedBy` | `nvarchar(100/256)` | No | User or system principal that last updated the row. |

### Soft Delete Columns

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `IsDeleted` | `bit` | Yes | Soft-delete flag. Default is false. |
| `DeletedDate` | `datetime2` | No | Timestamp when the row was soft-deleted. |
| `DeletedBy` | `nvarchar(100/256)` | No | User or system principal that soft-deleted the row. |

### Concurrency Column

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `RowVersion` | `rowversion` | System | Optimistic concurrency token used to reject stale updates. |

## Master Data And Security

### `LegalEntity`

Source: `specs/feature/002-legal-entity-management/data-model.md`

Description: Legal company/entity master. Every financial transaction is scoped to a legal entity. CAPSUL owns identity fields; FMS owns finance configuration.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `Code` | `string(10)` | Yes | Stable CAPSUL/FMS entity code and sync match key. |
| `Name` | `string` | Yes | Legal entity name from CAPSUL. |
| `CountryId` | `int` | Yes | FK to `Country`. |
| `CountryCode` | `string` | Yes | ISO country code from CAPSUL. |
| `CountryName` | `string` | Yes | Country display name from CAPSUL. |
| `RegistrationNumber` | `string` | Yes | Company registration number; sensitive. |
| `RegisteredAddress` | `string` | Yes | Registered legal address; sensitive. |
| `OfficeAddress` | `string` | No | Operating/trading address maintained in FMS. |
| `Phone` | `string` | No | Contact phone from CAPSUL; sensitive. |
| `IsActive` | `bit` | Yes | CAPSUL active status. Different from soft delete. |
| `ParentId` | `int` | No | Self-FK to parent legal entity in the group hierarchy. |
| `OwnershipPercentage` | `decimal` | No | Parent ownership percentage from 0 to 100. |
| `OwnershipType` | `int/string enum` | No | Direct or indirect ownership classification. |
| `EntityType` | `int/string enum` | Yes | Holding, Operating, or Unspecified; derived from hierarchy. |
| `FunctionalCurrencyCode` | `string(3)` | Yes | Entity base currency used for posting and FX. |
| `ReportingCurrencyCode` | `string(3)` | Yes | Presentation/reporting currency. |
| `TaxRegistrationNumber` | `string` | No | VAT/GST/SST/tax registration number. |
| `FiscalCalendarId` | `int` | Yes | FK to the entity-owned `FiscalCalendar`. |
| `IncorporationDate` | `date` | No | Governance date. |
| `AuditFirm` | `string` | No | External audit firm. |
| `StatutoryFilingDates` | `string` | No | Filing-date text used for governance/alerts. |
| `IsFinanceReady` | `bit` | Yes | Derived readiness flag for required finance configuration. |

### `Country`

Source: `specs/feature/002-legal-entity-management/data-model.md`

Description: Country lookup used for selector scopes, grouping, and country reporting.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `CountryCode` | `string` | Yes | ISO country code, unique. |
| `CountryName` | `string` | Yes | Country display name. |

### `FiscalCalendar`

Source: `specs/feature/002-legal-entity-management/data-model.md`

Description: Accounting calendar owned by exactly one legal entity.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `LegalEntityId` | `int` | Yes | FK to `LegalEntity`; unique per entity. |
| `Code` | `string` | Yes | Calendar code. |
| `Name` | `string` | Yes | Calendar display name. |
| `FiscalYearStartMonth` | `int` | Yes | Start month, 1 to 12. |
| `FiscalYearStartDay` | `int` | Yes | Start day of fiscal year. |

### `FiscalPeriod`

Source: `specs/feature/002-legal-entity-management/data-model.md`

Description: Child accounting periods inside a `FiscalCalendar`.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `FiscalCalendarId` | `int` | Yes | FK to `FiscalCalendar`. |
| `PeriodNumber` | `int` | Yes | Period sequence number. |
| `Name` | `string` | Yes | Period display name. |
| `StartDate` | `date` | Yes | Period start date. |
| `EndDate` | `date` | Yes | Period end date. |

### `CountryTaxConfig`

Source: `specs/feature/002-legal-entity-management/data-model.md`

Description: FMS-owned per-country tax configuration for VAT/GST and withholding tax.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `CountryId` | `int` | Yes | FK to `Country`. |
| `VatGstRegime` | `string/json` | Yes | VAT/GST rules, rates, exemptions, and recoverability configuration. |
| `WithholdingTaxRules` | `string/json` | Yes | Withholding tax rates and treaty override rules. |
| `EffectiveFrom` | `date` | Yes | Start of validity window. |
| `EffectiveTo` | `date` | No | End of validity window. Null means open-ended. |

### `SyncRun`

Source: `specs/feature/002-legal-entity-management/data-model.md`

Description: CAPSUL legal-entity synchronization run audit.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `Source` | `string` | Yes | Source system, normally `CAPSUL`. |
| `StartedAt` | `datetime2` | Yes | Sync start timestamp. |
| `CompletedAt` | `datetime2` | No | Sync completion timestamp. Null while running. |
| `CreatedCount` | `int` | Yes | Number of entities created. |
| `UpdatedCount` | `int` | Yes | Number of entities updated. |
| `DeactivatedCount` | `int` | Yes | Number of entities deactivated. |
| `SkippedCount` | `int` | Yes | Number of records skipped. |
| `ErrorCount` | `int` | Yes | Number of errors. |
| `Outcome` | `int/string enum` | Yes | Success, partial success, or failed. |
| `CorrelationId` | `uniqueidentifier` | Yes | Cross-system trace id. |

### `SyncRunLine`

Source: `specs/feature/002-legal-entity-management/data-model.md`

Description: Per-record summary for a legal-entity sync run.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `SyncRunId` | `int` | Yes | FK to `SyncRun`. |
| `LegalEntityCode` | `string` | Yes | Entity code affected by the sync line. |
| `Action` | `string` | Yes | Created, updated, deactivated, skipped, or error. |
| `Message` | `string` | No | Masked summary message. |

### `User`

Source: `specs/feature/003-user-role-and-permission-foundation/data-model.md`

Description: Local CAPSUL user snapshot and FMS access status.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `Email` | `nvarchar(256)` | Yes | Normalized lower-case email and FMS user key. |
| `DisplayEmail` | `nvarchar(256)` | Yes | Original-cased email for display. |
| `DisplayName` | `nvarchar(200)` | Yes | CAPSUL display name snapshot. |
| `CapsulAxCode` | `nvarchar(50)` | No | CAPSUL AX code for reference only. |
| `CapsulIsActive` | `bit` | Yes | CAPSUL active flag. |
| `AccessStatus` | `int enum` | Yes | PendingNoAccess, Active, or Disabled. |

### `Role`

Source: `specs/feature/003-user-role-and-permission-foundation/data-model.md`

Description: FMS-owned named permission collection.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `Name` | `nvarchar(100)` | Yes | Role name, unique among active roles. |
| `Description` | `nvarchar(500)` | No | Role description. |
| `IsSystem` | `bit` | Yes | True for protected seeded roles. |
| `IsActive` | `bit` | Yes | Business activation flag. |

### `Permission`

Source: `specs/feature/003-user-role-and-permission-foundation/data-model.md`

Description: Permission-key catalog consumed by authorization policies and role mappings.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `Key` | `nvarchar(100)` | Yes | Immutable stable permission key. |
| `Label` | `nvarchar(200)` | Yes | Human-readable permission label. |
| `Category` | `int enum` | Yes | Posting, PeriodManagement, MasterData, Configuration, Viewing, or Access. |
| `Description` | `nvarchar(1000)` | No | Permission explanation. |
| `IsActive` | `bit` | Yes | Soft-disable flag. |

### `RolePermission`

Source: `specs/feature/003-user-role-and-permission-foundation/data-model.md`

Description: Role-to-permission assignment.

Common columns: Primary Key, Audit Columns, Soft Delete Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `RoleId` | `int` | Yes | FK to `Role`. |
| `PermissionId` | `int` | Yes | FK to `Permission`. |

### `UserRole`

Source: `specs/feature/003-user-role-and-permission-foundation/data-model.md`

Description: User-to-role assignment. The model allows one active role per user.

Common columns: Primary Key, Audit Columns, Soft Delete Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `UserId` | `int` | Yes | FK to `User`. |
| `RoleId` | `int` | Yes | FK to `Role`. |

### `UserEntityScope`

Source: `specs/feature/003-user-role-and-permission-foundation/data-model.md`

Description: Per-user legal-entity scope grant.

Common columns: Primary Key, Audit Columns, Soft Delete Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `UserId` | `int` | Yes | FK to `User`. |
| `ScopeType` | `int enum` | Yes | ConsolidatedGroup, Country, or SpecificEntity. |
| `CountryCode` | `nvarchar(10)` | Conditional | Required only for country scope. |
| `LegalEntityId` | `int` | Conditional | Required only for specific-entity scope. |

### `AccessAuditLog`

Source: `specs/feature/003-user-role-and-permission-foundation/data-model.md`

Description: Append-only authorization/access audit trail.

Common columns: Primary Key, created audit fields only.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `Action` | `int enum` | Yes | Access audit action performed. |
| `ActorUserName` | `nvarchar(100)` | Yes | User/principal responsible for the action. |
| `OccurredAt` | `datetime2` | Yes | UTC event time. |
| `TargetType` | `nvarchar(50)` | Yes | Target table/entity type. |
| `TargetId` | `int` | No | Target row id. |
| `TargetKey` | `nvarchar(256)` | No | Masked human-readable target key. |
| `BeforeJson` | `nvarchar(max)` | No | Compact prior-state summary. |
| `AfterJson` | `nvarchar(max)` | No | Compact new-state summary. |
| `CorrelationId` | `uniqueidentifier` | Yes | Correlates related changes. |

### `SodRule`

Source: `specs/feature/003-user-role-and-permission-foundation/data-model.md`

Description: Segregation-of-duties rule storage and evaluation hook.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `Name` | `nvarchar(100)` | Yes | Rule name. |
| `Description` | `nvarchar(1000)` | No | Rule explanation. |
| `RuleType` | `int enum` | Yes | MutuallyExclusiveRoles or AuthorNotApprover. |
| `RoleAId` | `int` | Conditional | First role for role-pair SoD rules. |
| `RoleBId` | `int` | Conditional | Second role for role-pair SoD rules. |
| `IsActive` | `bit` | Yes | Rule active flag. |

### `ApprovalAuthority`

Source: `specs/feature/003-user-role-and-permission-foundation/data-model.md`

Description: Approval threshold and second-approver policy storage.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `RoleId` | `int` | Yes | FK to `Role`. |
| `PermissionKey` | `nvarchar(100)` | Yes | Gated permission/action key. |
| `ThresholdAmount` | `decimal(23,6)` | No | Approval threshold metadata. |
| `ThresholdCurrencyCode` | `nvarchar(3)` | No | Currency of the threshold. |
| `RequiresSecondApprover` | `bit` | Yes | Whether a second approver is required. |
| `IsActive` | `bit` | Yes | Policy active flag. |

## Finance Core

### `Account`

Source: `specs/feature/005-chart-of-accounts/data-model.md`

Description: Global chart-of-accounts hierarchy node.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `AccountCode` | `nvarchar(25)` | Yes | FMS account code, unique among live rows. |
| `AccountName` | `nvarchar(200)` | Yes | Account display name. |
| `StatementType` | `int enum` | Yes | Profit and loss or balance sheet. |
| `ParentAccountId` | `int` | No | Self-FK to parent account. Null only for level 1. |
| `AccountLevel` | `int` | Yes | Level 1 to 4 in the COA hierarchy. |
| `IsPosting` | `bit` | Yes | True only for postable leaf accounts. |
| `IsComputed` | `bit` | Yes | True for computed/aggregate lines. |
| `IsDormant` | `bit` | Yes | Dormant account flag. |
| `DormantDate` | `datetime2` | Conditional | Required when `IsDormant` is true. |
| `Description` | `nvarchar(500)` | No | Optional account note. |

### `AccountAuditLog`

Source: `specs/feature/005-chart-of-accounts/data-model.md`

Description: Append-only audit trail for COA changes.

Common columns: Primary Key, created audit fields only.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `AccountId` | `int` | Yes | FK to changed `Account`. |
| `Action` | `int enum` | Yes | Created, made dormant, removed, formula set, or formula updated. |
| `ActorUserName` | `nvarchar(100)` | Yes | User who performed the change. |
| `OccurredAt` | `datetime2` | Yes | UTC event time. |
| `OldValueJson` | `nvarchar(max)` | No | Before-state summary. |
| `NewValueJson` | `nvarchar(max)` | No | After-state summary. |
| `Reason` | `nvarchar(500)` | No | Optional business reason. |
| `CorrelationId` | `uniqueidentifier` | Yes | Change correlation id. |

### `AccountFormula`

Source: `specs/feature/006-computed-formulas/data-model.md`

Description: Versioned formula for a computed COA account.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `AccountId` | `int` | Yes | FK to the computed account. |
| `FormulaExpression` | `nvarchar(1000)` | Yes | Canonical formula expression. |
| `DisplayText` | `nvarchar(300)` | Yes | Human-readable formula text. |
| `AppliesPerLevel` | `bit` | Yes | Whether L2/L3 formulas apply positionally by level. |
| `VersionNo` | `int` | Yes | Formula version per account. |
| `IsActive` | `bit` | Yes | Active formula version flag. |

### `AccountFormulaAudit`

Source: `specs/feature/006-computed-formulas/data-model.md`

Description: Append-only formula change audit.

Common columns: Primary Key, created audit fields only.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `AccountFormulaId` | `int` | Yes | FK to the newly created formula version. |
| `ActionType` | `int enum` | Yes | Created or updated. |
| `OldExpression` | `nvarchar(1000)` | No | Previous expression. Null on create. |
| `NewExpression` | `nvarchar(1000)` | Yes | New expression. |
| `OldDisplayText` | `nvarchar(300)` | No | Previous display text. Null on create. |
| `NewDisplayText` | `nvarchar(300)` | Yes | New display text. |
| `Reason` | `nvarchar(500)` | No | Optional change reason. |
| `CorrelationId` | `uniqueidentifier` | Yes | Correlates formula audit with account audit. |

### `FiscalYear`

Source: `specs/feature/007-fiscal-year-and-period/data-model.md`

Description: Global fiscal year definition.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `Year` | `int` | Yes | Calendar year, for example 2026. |
| `Name` | `nvarchar(20)` | Yes | Display label, for example FY 2026. |
| `StartDate` | `date` | Yes | Fiscal year start date. |
| `EndDate` | `date` | Yes | Fiscal year end date. |
| `Status` | `int enum` | Yes | Open, Closed, or Locked. |
| `YearEndClosedDate` | `datetime2` | No | Year-end close timestamp. |
| `YearEndClosedBy` | `nvarchar(100)` | No | Year-end close actor. |

### `FiscalYearPeriod`

Source: `specs/feature/007-fiscal-year-and-period/data-model.md`

Description: Monthly fiscal period and close lifecycle.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `FiscalYearId` | `int` | Yes | FK to `FiscalYear`. |
| `PeriodNumber` | `int` | Yes | Month number 1 to 12. |
| `Name` | `nvarchar(20)` | Yes | Period label, for example Jan '26. |
| `StartDate` | `date` | Yes | Period start date. |
| `EndDate` | `date` | Yes | Period end date. |
| `Status` | `int enum` | Yes | Open, InProgress, Closed, or Locked. |
| `ClosedDate` | `datetime2` | No | Hard-close timestamp. |
| `ClosedBy` | `nvarchar(100)` | No | Hard-close actor. |
| `ClosedByRole` | `nvarchar(50)` | No | Actor role at close. |
| `StartedDate` | `datetime2` | No | Soft-close/start timestamp. |
| `StartedBy` | `nvarchar(100)` | No | Soft-close/start actor. |
| `ReopenedDate` | `datetime2` | No | Last reopen timestamp. |
| `ReopenedBy` | `nvarchar(100)` | No | Last reopen actor. |
| `LockedDate` | `datetime2` | No | Lock timestamp. |
| `LockedBy` | `nvarchar(100)` | No | Lock actor. |

### `PeriodCloseChecklistItem`

Source: `specs/feature/007-fiscal-year-and-period/data-model.md`

Description: Seeded close checklist item catalog.

Common columns: Primary Key, Audit Columns, Soft Delete Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `GroupKey` | `int enum` | Yes | Checklist group. |
| `Title` | `nvarchar(150)` | Yes | Checklist item title. |
| `Description` | `nvarchar(1000)` | No | Checklist item helper text. |
| `DisplayOrder` | `int` | Yes | Order within the group. |

### `PeriodCloseChecklistStatus`

Source: `specs/feature/007-fiscal-year-and-period/data-model.md`

Description: Checklist completion state for one period, legal entity, and checklist item.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `FiscalYearPeriodId` | `int` | Yes | FK to `FiscalYearPeriod`. |
| `LegalEntityId` | `int` | Yes | FK to `LegalEntity`. |
| `ChecklistItemId` | `int` | Yes | FK to `PeriodCloseChecklistItem`. |
| `IsCompleted` | `bit` | Yes | Whether the checklist cell is ticked. |
| `CompletedDate` | `datetime2` | No | Completion timestamp. |
| `CompletedBy` | `nvarchar(100)` | No | Completion actor. |
| `IsOverride` | `bit` | Yes | True if changed through a locked-period override. |

### `PeriodWorkflowStep`

Source: `specs/feature/007-fiscal-year-and-period/data-model.md`

Description: Seeded/read-only period close workflow-step catalog.

Common columns: Primary Key, Audit Columns, Soft Delete Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `Phase` | `int enum` | Yes | Workflow phase. |
| `DayRangeLabel` | `nvarchar(40)` | No | Display day range. |
| `SequenceInPhase` | `int` | Yes | Step order within phase. |
| `Title` | `nvarchar(150)` | Yes | Step title. |
| `Description` | `nvarchar(1000)` | Yes | Step description. |
| `Trigger` | `int enum` | Yes | Manual, scheduled, or event-driven. |
| `RequiredRole` | `nvarchar(50)` | Yes | Role required for the step. |
| `Reversibility` | `int enum` | Yes | Reversal/override behavior. |
| `GatePreconditionsJson` | `nvarchar(max)` | No | Preconditions as JSON. |
| `AuditEventKey` | `nvarchar(80)` | No | Audit key emitted by related process. |
| `PayloadFields` | `nvarchar(500)` | No | Relevant payload field list. |
| `RetentionLabel` | `nvarchar(40)` | No | Retention label. |
| `AffectedModules` | `nvarchar(300)` | No | Module chips/display text. |
| `PrototypeStatus` | `nvarchar(500)` | No | Prototype implementation note. |

### `PeriodAuditLog`

Source: `specs/feature/007-fiscal-year-and-period/data-model.md`

Description: Append-only close-management audit trail.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `EventKey` | `int enum` | Yes | Period close audit event. |
| `ActorUserName` | `nvarchar(100)` | Yes | Actor principal. |
| `ActorRole` | `nvarchar(50)` | No | Actor role snapshot. |
| `OccurredAt` | `datetime2` | Yes | UTC event timestamp. |
| `FiscalYearId` | `int` | Yes | FK to `FiscalYear`. |
| `FiscalYearPeriodId` | `int` | No | FK to period for monthly events. |
| `LegalEntityId` | `int` | No | FK to legal entity for entity-scoped events. |
| `OldStatus` | `nvarchar(20)` | No | Previous status. |
| `NewStatus` | `nvarchar(20)` | No | New status. |
| `Reason` | `nvarchar(500)` | No | Reason or override justification. |
| `PayloadJson` | `nvarchar(max)` | No | Compact event payload. |
| `RetentionClass` | `int enum` | Yes | Seven-year or permanent retention class. |
| `IsOverride` | `bit` | Yes | Locked-period override flag. |
| `CorrelationId` | `uniqueidentifier` | Yes | Correlates related audit rows. |

### `ExchangeRate`

Source: `specs/feature/009-exchange-rates/data-model.md`

Description: Manual daily FX rate, global or legal-entity scoped.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `LegalEntityId` | `int` | No | FK to `LegalEntity`; null means global/group-level. |
| `CurrencyFrom` | `nvarchar(3)` | Yes | Source currency. |
| `CurrencyTo` | `nvarchar(3)` | Yes | Target currency. |
| `RateTypeId` | `int` | Yes | FK to `RateType`. |
| `RateDate` | `date` | Yes | Date the rate applies to. |
| `RateSourceId` | `int` | Yes | FK to `RateSource`. |
| `QuotationUnit` | `int` | Yes | Units quoted for `CurrencyFrom`. |
| `UserInputRate` | `decimal(23,10)` | Yes | Rate as entered by user. |
| `CalculatedRate` | `decimal(23,10)` | Yes | Stored calculated rate after quotation-unit conversion. |
| `IsActive` | `bit` | Yes | Business activation flag. |
| `IsOverride` | `bit` | Yes | Whether the row is an override. |
| `OverridesExchangeRateId` | `int` | No | Self-FK to superseded exchange rate. |

### `RateType`

Source: `specs/feature/009-exchange-rates/data-model.md`

Description: Seeded/configurable FX rate type lookup.

Common columns: Primary Key, Audit Columns, Soft Delete Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `Code` | `nvarchar(30)` | Yes | Immutable rate type code. |
| `Name` | `nvarchar(100)` | Yes | Display name. |
| `Description` | `nvarchar(300)` | No | Helper text. |
| `IsActive` | `bit` | Yes | Whether selectable for new rates. |
| `SortOrder` | `int` | Yes | Display order. |

### `RateSource`

Source: `specs/feature/009-exchange-rates/data-model.md`

Description: Seeded/configurable FX rate source lookup.

Common columns: Primary Key, Audit Columns, Soft Delete Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `Code` | `nvarchar(30)` | Yes | Source code. |
| `Name` | `nvarchar(150)` | Yes | Source display name. |
| `IsManualEntry` | `bit` | Yes | True for manual source. |
| `IsActive` | `bit` | Yes | Whether selectable. |
| `SortOrder` | `int` | Yes | Display order. |

### `AppliedRateConfig`

Source: `specs/feature/009-exchange-rates/data-model.md`

Description: Per-jurisdiction applied-rate category configuration.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `JurisdictionCountryCode` | `nvarchar(10)` | Yes | Country/jurisdiction code. |
| `JurisdictionName` | `nvarchar(100)` | Yes | Jurisdiction display name. |
| `LocalCurrencyCode` | `nvarchar(3)` | Yes | Local currency code. |
| `Category` | `int enum` | Yes | Applied-rate category. |
| `DisplayName` | `nvarchar(100)` | No | Optional slot display name. |
| `SpreadBps` | `int` | Yes | Spread in basis points. |
| `IsActive` | `bit` | Yes | Active flag. |

### `TransactionRatePolicy`

Source: `specs/feature/009-exchange-rates/data-model.md`

Description: Document-class default FX policy.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `DocumentClass` | `int enum` | Yes | Purchase order, vendor PO, sales order, or other. |
| `CountryRule` | `int enum` | Yes | Rule for choosing jurisdiction/country. |
| `DefaultRateTypeId` | `int` | Yes | FK to default `RateType`. |

### `FxPolicySettings`

Source: `specs/feature/009-exchange-rates/data-model.md`

Description: Single-row FX policy setup store.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `PrimaryRateSourceId` | `int` | Yes | FK to primary `RateSource`. |
| `PolicyRateTypeId` | `int` | Yes | FK to policy `RateType`. |
| `SnapTiming` | `int enum` | Yes | FX snapshot timing. |
| `StaleTolerance` | `int enum` | Yes | Allowed stale-rate tolerance. |

### `FxAuditLog`

Source: `specs/feature/009-exchange-rates/data-model.md`

Description: Append-only FX configuration/rate audit trail.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `EventKey` | `int enum` | Yes | FX audit event. |
| `ActorUserName` | `nvarchar(256)` | Yes | Actor principal. |
| `ActorRole` | `nvarchar(100)` | No | Actor role snapshot. |
| `OccurredAt` | `datetime2` | Yes | UTC event time. |
| `ExchangeRateId` | `int` | No | FK to affected `ExchangeRate`. |
| `CurrencyFrom` | `nvarchar(3)` | No | Denormalized source currency. |
| `CurrencyTo` | `nvarchar(3)` | No | Denormalized target currency. |
| `JurisdictionCountryCode` | `nvarchar(10)` | No | Affected jurisdiction. |
| `OldValueJson` | `nvarchar(max)` | No | Before-state summary. |
| `NewValueJson` | `nvarchar(max)` | No | After-state summary. |
| `Reason` | `nvarchar(500)` | No | Optional reason. |
| `IsOverride` | `bit` | Yes | Override event marker. |
| `CorrelationId` | `uniqueidentifier` | Yes | Event correlation id. |
| `RetentionClass` | `int enum` | Yes | Retention class. |

### `Division`

Source: `specs/feature/010-cost-center-and-department/data-model.md`

Description: CAPSUL-synced division mirror, read-only in FMS.

Common columns: Primary Key, Audit Columns, Soft Delete Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `Code` | `nvarchar(50)` | Yes | CAPSUL division code and sync key. |
| `Name` | `nvarchar(200)` | Yes | Division display name. |
| `IsActive` | `bit` | Yes | CAPSUL active flag. |
| `LastSyncedDate` | `datetime2` | No | Last sync touch timestamp. |
| `SyncStatus` | `nvarchar(30)` | No | Per-row sync status. |

### `Department`

Source: `specs/feature/010-cost-center-and-department/data-model.md`

Description: CAPSUL-synced department under a division, read-only in FMS.

Common columns: Primary Key, Audit Columns, Soft Delete Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `Code` | `nvarchar(50)` | Yes | CAPSUL department code and sync key. |
| `Name` | `nvarchar(200)` | Yes | Department display name. |
| `DivisionId` | `int` | Yes | FK to owning `Division`. |
| `IsActive` | `bit` | Yes | CAPSUL active flag. |
| `LastSyncedDate` | `datetime2` | No | Last sync touch timestamp. |
| `SyncStatus` | `nvarchar(30)` | No | Per-row sync status. |

### `CostCenter`

Source: `specs/feature/010-cost-center-and-department/data-model.md`

Description: FMS-owned cost center analytical dimension.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `Code` | `nvarchar(50)` | Yes | Unique FMS cost center code. |
| `Name` | `nvarchar(200)` | Yes | Cost center display name. |
| `DivisionId` | `int` | Yes | FK to `Division`. |
| `DepartmentId` | `int` | Yes | FK to `Department`; must belong to the division. |
| `IsActive` | `bit` | Yes | Active/deactivated flag. |

### `OrgSyncRun`

Source: `specs/feature/010-cost-center-and-department/data-model.md`

Description: Organization dimension sync run and run lock.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `Source` | `nvarchar(50)` | Yes | Source system, normally `CAPSUL`. |
| `TriggerType` | `int enum` | Yes | Manual or scheduled. |
| `TriggeredBy` | `nvarchar(256)` | Yes | User/system that triggered sync. |
| `StartedAt` | `datetime2` | Yes | Sync start time. |
| `CompletedAt` | `datetime2` | No | Completion time. Null means in progress. |
| `Outcome` | `int enum` | Yes | Success, partial success, or failed. |
| `DivisionsAdded` | `int` | Yes | Divisions created. |
| `DivisionsUpdated` | `int` | Yes | Divisions updated. |
| `DivisionsDeactivated` | `int` | Yes | Divisions deactivated. |
| `DepartmentsAdded` | `int` | Yes | Departments created. |
| `DepartmentsUpdated` | `int` | Yes | Departments updated. |
| `DepartmentsDeactivated` | `int` | Yes | Departments deactivated. |
| `SkippedCount` | `int` | Yes | Records skipped. |
| `ErrorCount` | `int` | Yes | Errors encountered. |
| `ErrorMessage` | `nvarchar(1000)` | No | Non-sensitive failure summary. |
| `CorrelationId` | `uniqueidentifier` | Yes | Cross-system trace id. |

### `OrgSyncRunLine`

Source: `specs/feature/010-cost-center-and-department/data-model.md`

Description: Per-record detail for an organization sync run.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `OrgSyncRunId` | `int` | Yes | FK to `OrgSyncRun`. |
| `EntityType` | `int enum` | Yes | Division or Department. |
| `EntityCode` | `nvarchar(50)` | No | Code of affected row. |
| `Action` | `nvarchar(30)` | Yes | Created, updated, deactivated, skipped, or error. |
| `Message` | `nvarchar(500)` | No | Masked summary message. |

### `CostCenterAuditLog`

Source: `specs/feature/010-cost-center-and-department/data-model.md`

Description: Append-only cost-center audit trail.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `EventKey` | `int enum` | Yes | Created, updated, deactivated, or reactivated. |
| `ActorUserName` | `nvarchar(256)` | Yes | Actor principal. |
| `ActorRole` | `nvarchar(100)` | No | Actor role snapshot. |
| `OccurredAt` | `datetime2` | Yes | UTC event time. |
| `CostCenterId` | `int` | No | FK to `CostCenter`. |
| `CostCenterCode` | `nvarchar(50)` | No | Denormalized code. |
| `OldValueJson` | `nvarchar(max)` | No | Before-state summary. |
| `NewValueJson` | `nvarchar(max)` | No | After-state summary. |
| `Reason` | `nvarchar(500)` | No | Optional reason. |
| `CorrelationId` | `uniqueidentifier` | Yes | Event correlation id. |
| `RetentionClass` | `int enum` | Yes | Retention class. |

### `Journal`

Source: `specs/feature/011-journal-entry-core/data-model.md`; `specs/feature/037-opening-balances/data-model.md`

Description: Journal header/document for one legal entity.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `JournalNumber` | `nvarchar(20)` | Yes | System-generated journal number. |
| `LegalEntityId` | `int` | Yes | FK to `LegalEntity`. |
| `JournalTypeId` | `int` | Yes | FK to `JournalType`. |
| `JournalDate` | `date` | Yes | Journal date. |
| `FiscalYearPeriodId` | `int` | Yes | FK to posting fiscal period. |
| `Source` | `int enum` | Yes | Manual, DMS, POMS, SOMS, WMS, etc. |
| `Status` | `int enum` | Yes | Draft, PendingApproval, Posted, Rejected, or Reversed. |
| `CurrencyCode` | `char(3)` | Yes | Transaction currency. |
| `ExchangeRate` | `decimal(23,10)` | No | Transaction-to-functional rate. Null when same currency. |
| `ReferenceNo` | `nvarchar(100)` | No | Document/reference number. |
| `Description` | `nvarchar(500)` | No | Header narrative. |
| `TotalDebit` | `decimal(23,6)` | Yes | Sum of debit line amounts. |
| `TotalCredit` | `decimal(23,6)` | Yes | Sum of credit line amounts. |
| `SubmittedBy` | `nvarchar` | No | Submitter. |
| `SubmittedDate` | `datetime2` | No | Submit timestamp. |
| `ApprovedBy` | `nvarchar` | No | Approver. |
| `ApprovedDate` | `datetime2` | No | Approval/direct-post timestamp. |
| `ReversalOfJournalId` | `int` | No | Original journal when this is a reversal. |
| `ReversedByJournalId` | `int` | No | Reversal journal created for this original. |
| `ReversalReason` | `nvarchar(500)` | Conditional | Required when the journal reverses another. |
| `IsOpeningBalance` | `bit` | Yes | True for opening-balance journals; added by feature 037. |

### `JournalLine`

Source: `specs/feature/011-journal-entry-core/data-model.md`; `specs/feature/033-settlement-fx-realised/data-model.md`

Description: Debit/credit posting line inside a journal.

Common columns: Primary Key, Audit Columns, Soft Delete Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `JournalId` | `int` | Yes | FK to parent `Journal`. |
| `LineNumber` | `int` | Yes | Display/order number. |
| `AccountId` | `int` | Yes | FK to postable leaf `Account`. |
| `DebitAmount` | `decimal(23,6)` | Yes | Transaction-currency debit amount. |
| `CreditAmount` | `decimal(23,6)` | Yes | Transaction-currency credit amount. |
| `DivisionId` | `int` | No | Optional division dimension. |
| `DepartmentId` | `int` | No | Optional department dimension. |
| `Narrative` | `nvarchar(500)` | No | Line memo. |
| `FunctionalDebitAmount` | `decimal(23,6)` | No | Optional functional debit override for realized-FX settlements. |
| `FunctionalCreditAmount` | `decimal(23,6)` | No | Optional functional credit override for realized-FX settlements. |

### `JournalType`

Source: `specs/feature/011-journal-entry-core/data-model.md`

Description: Seeded journal classification and filter lookup.

Common columns: Primary Key, Audit Columns, Soft Delete Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `Code` | `nvarchar(20)` | Yes | Journal type code, for example MANUAL or PAYMENT. |
| `Name` | `nvarchar(100)` | Yes | Display label. |
| `IsActive` | `bit` | Yes | Business active flag. |

### `JournalTypeAllowedAccount`

Source: `specs/feature/011-journal-entry-core/data-model.md`

Description: Soft guardrail mapping of typical/allowed accounts for each journal type.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `JournalTypeId` | `int` | Yes | FK to `JournalType`. |
| `AccountId` | `int` | Yes | FK to `Account`. |

### `JournalApproval`

Source: `specs/feature/011-journal-entry-core/data-model.md`

Description: Approval or rejection decision record for a journal.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `JournalId` | `int` | Yes | FK to `Journal`. |
| `Decision` | `int enum` | Yes | Approved or rejected. |
| `DecidedBy` | `nvarchar(256)` | Yes | Approver principal. |
| `DecidedDate` | `datetime2` | Yes | Decision timestamp. |
| `Comment` | `nvarchar(500)` | No | Optional approve/reject comment. |

### `JournalAuditLog`

Source: `specs/feature/011-journal-entry-core/data-model.md`; `specs/feature/012-journal-posting-engine/data-model.md`

Description: Append-only journal workflow/posting audit.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `EventKey` | `int enum` | Yes | Journal audit event. |
| `ActorUserName` | `nvarchar(256)` | Yes | Actor principal. |
| `ActorRole` | `nvarchar(100)` | No | Actor role snapshot. |
| `OccurredAt` | `datetime2` | Yes | UTC event time. |
| `JournalId` | `int` | No | FK to affected journal. |
| `JournalNumber` | `nvarchar(20)` | No | Denormalized journal number. |
| `FromStatus` | `int enum` | No | Previous journal status. |
| `ToStatus` | `int enum` | No | New journal status. |
| `Reason` | `nvarchar(500)` | No | Reject/reversal/override reason. |
| `OldValueJson` | `nvarchar(max)` | No | Before-state summary. |
| `NewValueJson` | `nvarchar(max)` | No | After-state summary. |
| `CorrelationId` | `uniqueidentifier` | Yes | Event correlation id. |
| `RetentionClass` | `int enum` | Yes | Retention class. |
| `LegalEntityId` | `int` | No | Target entity for posting/reversal audit. |
| `Result` | `int enum` | Yes | Success or failure. |
| `FailureCode` | `nvarchar(64)` | No | Failure reason code. |
| `ReversalJournalId` | `int` | No | Journal created as reversal. |

### `GeneralLedgerEntry`

Source: `specs/feature/012-journal-posting-engine/data-model.md`; `specs/feature/013-general-ledger/data-model.md`

Description: Immutable posted ledger row, one per posted journal line.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `JournalId` | `int` | Yes | FK to posted journal. |
| `JournalLineId` | `int` | Yes | FK to source journal line; unique. |
| `LegalEntityId` | `int` | Yes | FK to `LegalEntity`. |
| `FiscalYearPeriodId` | `int` | Yes | FK to posting period. |
| `AccountId` | `int` | Yes | FK to posted account. |
| `DivisionId` | `int` | No | Optional division dimension. |
| `DepartmentId` | `int` | No | Optional department dimension. |
| `JournalDate` | `date` | Yes | Booking date. |
| `PostedAtUtc` | `datetime2` | Yes | Posting timestamp. |
| `CurrencyCode` | `char(3)` | Yes | Transaction currency. |
| `ExchangeRate` | `decimal(23,10)` | No | Transaction-to-functional rate. |
| `DebitAmount` | `decimal(23,6)` | Yes | Transaction-currency debit. |
| `CreditAmount` | `decimal(23,6)` | Yes | Transaction-currency credit. |
| `FunctionalDebitAmount` | `decimal(23,6)` | Yes | Functional-currency debit. |
| `FunctionalCreditAmount` | `decimal(23,6)` | Yes | Functional-currency credit. |
| `JournalNumber` | `nvarchar(20)` | Yes | Denormalized journal number. |
| `Source` | `int enum` | Yes | Journal source. |
| `IsReversal` | `bit` | Yes | Whether entry belongs to a reversal journal. |
| `SalesTypeCode` | `string` | No | Optional sales-type reporting filter. |
| `SalesTypeLabel` | `string` | No | Optional sales-type display label. |
| `IsOpeningBalance` | `bit` | Yes | True for opening-balance GL rows. |

### `FiscalYearPeriodLegalEntityClose`

Source: `specs/feature/014A-period-closing-per-legal-entity/data-model.md`

Description: Entity-scoped close state for one fiscal period.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `FiscalYearPeriodId` | `int` | Yes | FK to `FiscalYearPeriod`. |
| `FiscalYearId` | `int` | Yes | FK to `FiscalYear`, denormalized for year checks. |
| `LegalEntityId` | `int` | Yes | FK to `LegalEntity`. |
| `Status` | `int enum` | Yes | Open, InProgress, Closed, or Locked. |
| `StartedDate` | `datetime2` | No | Soft-close/start timestamp. |
| `StartedBy` | `nvarchar(100)` | No | Start actor. |
| `ClosedDate` | `datetime2` | No | Hard-close timestamp. |
| `ClosedBy` | `nvarchar(100)` | No | Hard-close actor. |
| `ClosedByRole` | `nvarchar(50)` | No | Actor role at close. |
| `ReopenedDate` | `datetime2` | No | Reopen timestamp. |
| `ReopenedBy` | `nvarchar(100)` | No | Reopen actor. |
| `ReopenReason` | `nvarchar(500)` | No | Last reopen reason. |
| `LockedDate` | `datetime2` | No | Lock timestamp. |
| `LockedBy` | `nvarchar(100)` | No | Lock actor. |

### `PeriodCloseSnapshot`

Source: `specs/feature/014A-period-closing-per-legal-entity/data-model.md`

Description: Frozen statement snapshot header captured at close.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `EntityCloseId` | `int` | Yes | FK to `FiscalYearPeriodLegalEntityClose`. |
| `LegalEntityId` | `int` | Yes | Denormalized legal entity. |
| `FiscalYearPeriodId` | `int` | Yes | Denormalized fiscal period. |
| `SnapshotType` | `int enum` | Yes | ProfitLoss or BalanceSheet. |
| `CapturedAt` | `datetime2` | Yes | Capture timestamp. |
| `CapturedBy` | `nvarchar(100)` | Yes | Capture actor. |
| `LineCount` | `int` | Yes | Number of captured lines. |

### `PeriodCloseSnapshotLine`

Source: `specs/feature/014A-period-closing-per-legal-entity/data-model.md`

Description: Frozen statement line value inside a period close snapshot.

Common columns: Primary Key, created audit fields.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `SnapshotId` | `int` | Yes | FK to `PeriodCloseSnapshot`. |
| `LineKey` | `nvarchar(60)` | Yes | Stable statement line key. |
| `LineLabel` | `nvarchar(120)` | Yes | Display label. |
| `DisplayOrder` | `int` | Yes | Statement display order. |
| `AtCloseValue` | `decimal(18,2)` | Yes | Frozen functional-currency value. |

### `FiscalYearLegalEntityClose`

Source: `specs/feature/014A-period-closing-per-legal-entity/data-model.md`

Description: Entity-scoped year-end close state.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `FiscalYearId` | `int` | Yes | FK to `FiscalYear`. |
| `LegalEntityId` | `int` | Yes | FK to `LegalEntity`. |
| `Status` | `int enum` | Yes | Open, InProgress, or Locked. |
| `ClosedDate` | `datetime2` | No | Year-end close timestamp. |
| `ClosedBy` | `nvarchar(100)` | No | Year-end close actor. |
| `ClosedByRole` | `nvarchar(50)` | No | Actor role at close. |
| `LockedDate` | `datetime2` | No | Lock timestamp. |
| `LockedBy` | `nvarchar(100)` | No | Lock actor. |
| `ReopenedDate` | `datetime2` | No | Reopen timestamp. |
| `ReopenedBy` | `nvarchar(100)` | No | Reopen actor. |
| `ReopenReason` | `nvarchar(500)` | No | Last reopen reason. |

## Fixed Assets

### `AssetClass`

Source: `specs/feature/018-fixed-assets/data-model.md`

Description: Fixed-asset class master and default account mapping.

Common columns: Primary Key, Audit Columns, Soft Delete Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `Code` | `nvarchar(40)` | Yes | Asset class code. |
| `Name` | `nvarchar(120)` | Yes | Display name. |
| `CodeAbbrev` | `nvarchar(8)` | Yes | Abbreviation for asset-code generation. |
| `DefaultUsefulLifeMonths` | `int` | No | Default depreciation life in months. |
| `AssetBookValueAccountId` | `int` | Yes | FK to asset book value account. |
| `AccumulatedDepreciationAccountId` | `int` | Yes | FK to accumulated depreciation account. |
| `DepreciationExpenseAccountId` | `int` | Yes | FK to depreciation expense account. |
| `IsIntangible` | `bit` | Yes | Tangible/intangible flag. |
| `SortOrder` | `int` | Yes | Display/filter order. |

### `FixedAsset`

Source: `specs/feature/018-fixed-assets/data-model.md`

Description: Fixed asset register row.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `LegalEntityId` | `int` | Yes | FK to owning legal entity. |
| `AssetClassId` | `int` | Yes | FK to `AssetClass`. |
| `AssetCode` | `nvarchar(40)` | Yes | Generated unique asset code. |
| `AssetName` | `nvarchar(200)` | Yes | Asset name. |
| `DivisionId` | `int` | No | Cost-ownership division. |
| `DepartmentId` | `int` | No | Cost-ownership department. |
| `InServiceDate` | `date` | Yes | Date asset enters service. |
| `UsefulLifeMonths` | `int` | Yes | Depreciation useful life. |
| `AcquisitionCost` | `decimal(23,6)` | Yes | Original acquisition cost. |
| `GrossBookValue` | `decimal(23,6)` | Yes | Current gross book value. |
| `AccumulatedDepreciation` | `decimal(23,6)` | Yes | Accumulated depreciation. |
| `AccumulatedImpairment` | `decimal(23,6)` | Yes | Accumulated impairment. |
| `NetBookValue` | `decimal(23,6)` | Yes | Maintained net book value. |
| `Status` | `tinyint enum` | Yes | Active, fully depreciated, or disposed. |
| `LastDepreciatedYear` | `int` | No | Last depreciation run year. |
| `LastDepreciatedMonth` | `int` | No | Last depreciation run month. |
| `CorrelationId` | `uniqueidentifier` | Yes | Operation correlation id. |

### `FixedAssetTransaction`

Source: `specs/feature/018-fixed-assets/data-model.md`

Description: Append-only asset acquisition, disposal, revaluation, or impairment transaction.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `FixedAssetId` | `int` | Yes | FK to `FixedAsset`. |
| `LegalEntityId` | `int` | Yes | Denormalized entity scope. |
| `OperationType` | `tinyint enum` | Yes | Acquisition, disposal, revaluation, or impairment. |
| `TransactionDate` | `date` | Yes | Effective transaction date. |
| `DivisionId` | `int` | No | Division dimension. |
| `DepartmentId` | `int` | No | Department dimension. |
| `Amount` | `decimal(23,6)` | Yes | Principal transaction amount. |
| `GainLossAmount` | `decimal(23,6)` | No | Disposal gain/loss. |
| `CarryingValueBefore` | `decimal(23,6)` | Yes | NBV before transaction. |
| `CarryingValueAfter` | `decimal(23,6)` | Yes | NBV after transaction. |
| `JournalId` | `int` | No | Related journal. |
| `DisposalType` | `tinyint enum` | No | Disposal subtype. |
| `IdempotencyKey` | `uniqueidentifier` | No | Request dedupe key. |
| `CorrelationId` | `uniqueidentifier` | Yes | Trace id. |

### `FixedAssetDepreciationSchedule`

Source: `specs/feature/018-fixed-assets/data-model.md`

Description: Append-only monthly depreciation projection for an asset.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `FixedAssetId` | `int` | Yes | FK to `FixedAsset`. |
| `MonthNumber` | `int` | Yes | Schedule month number. |
| `PeriodYear` | `int` | Yes | Calendar/fiscal year. |
| `PeriodMonth` | `int` | Yes | Calendar/fiscal month. |
| `DepreciationCharge` | `decimal(23,6)` | Yes | Charge for the period. |
| `CumulativeDepreciation` | `decimal(23,6)` | Yes | Running depreciation total. |
| `NetBookValue` | `decimal(23,6)` | Yes | Projected NBV after charge. |

### `FixedAssetDepreciationRun`

Source: `specs/feature/018-fixed-assets/data-model.md`

Description: Append-only depreciation run header.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `LegalEntityId` | `int` | Yes | Entity for the run. |
| `PeriodYear` | `int` | Yes | Run year. |
| `PeriodMonth` | `int` | Yes | Run month. |
| `AssetsIncluded` | `int` | Yes | Number of assets included. |
| `AssetsSkipped` | `int` | Yes | Number of assets skipped. |
| `ClassCount` | `int` | Yes | Number of asset classes included. |
| `TotalDepreciation` | `decimal(23,6)` | Yes | Total depreciation posted. |
| `IdempotencyKey` | `uniqueidentifier` | Yes | Run dedupe key. |
| `CorrelationId` | `uniqueidentifier` | Yes | Trace id. |

### `FixedAssetDepreciationRunLine`

Source: `specs/feature/018-fixed-assets/data-model.md`

Description: Append-only depreciation run line per asset class.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `DepreciationRunId` | `int` | Yes | FK to `FixedAssetDepreciationRun`. |
| `AssetClassId` | `int` | Yes | FK to `AssetClass`. |
| `AssetCount` | `int` | Yes | Number of assets in the class. |
| `ClassTotal` | `decimal(23,6)` | Yes | Class depreciation total. |
| `DebitAccountId` | `int` | Yes | Depreciation expense account. |
| `CreditAccountId` | `int` | Yes | Accumulated depreciation account. |
| `JournalId` | `int` | Yes | Journal posted for the class. |

### `FixedAssetDepreciationCharge`

Source: `specs/feature/018-fixed-assets/data-model.md`

Description: Append-only per-asset/per-period depreciation fact.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `DepreciationRunId` | `int` | Yes | FK to run header. |
| `DepreciationRunLineId` | `int` | Yes | FK to class run line. |
| `FixedAssetId` | `int` | Yes | FK to depreciated asset. |
| `LegalEntityId` | `int` | Yes | Denormalized entity scope. |
| `PeriodYear` | `int` | Yes | Depreciation year. |
| `PeriodMonth` | `int` | Yes | Depreciation month. |
| `Charge` | `decimal(23,6)` | Yes | Depreciation amount. |
| `NetBookValueAfter` | `decimal(23,6)` | Yes | NBV after the charge. |

### `FixedAssetAuditLog`

Source: `specs/feature/018-fixed-assets/data-model.md`

Description: Append-only fixed-asset operation audit trail.

Common columns: Primary Key, created audit fields.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `FixedAssetId` | `int` | No | FK to affected asset; null for entity-wide operations. |
| `LegalEntityId` | `int` | Yes | Entity scope. |
| `OperationType` | `tinyint enum` | Yes | Asset operation type. |
| `AssetCode` | `nvarchar(40)` | No | Asset code snapshot. |
| `PerformedBy` | `nvarchar(256)` | Yes | Actor principal. |
| `RoleSnapshot` | `nvarchar(max)` | No | Role/permission snapshot. |
| `CarryingValueBefore` | `decimal(23,6)` | No | Carrying value before operation. |
| `CarryingValueAfter` | `decimal(23,6)` | No | Carrying value after operation. |
| `GeneratedJournalIds` | `nvarchar(200)` | No | Related journal ids. |
| `Result` | `tinyint enum` | Yes | Success or failure. |
| `FailureReason` | `nvarchar(1000)` | No | Failure detail. |
| `CorrelationId` | `uniqueidentifier` | Yes | Trace id. |
| `OccurredAtUtc` | `datetime2` | Yes | Event time. |

## Integration, Sales, Purchasing, And Payments

### `SourceSystem`

Source: `specs/feature/021A-source-system-foundation/data-model.md`

Description: Source-system master registry.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `Code` | `nvarchar(20)` | Yes | Source code, for example SOMS, DMS, POMS, or WMS. |
| `Name` | `nvarchar(120)` | Yes | Display name. |
| `IsActive` | `bit` | Yes | Soft-disable flag. |
| `IsTestMode` | `bit` | Yes | Test-mode indicator. |
| `DisplayColor` | `nvarchar(20)` | Yes | UI color. |
| `SortOrder` | `int` | Yes | Display order. |
| `ContractReference` | `nvarchar(200)` | No | Contract document reference. |

### `IntegrationEndpoint`

Source: `specs/feature/021A-source-system-foundation/data-model.md`

Description: Per-source endpoint namespace/auth/config.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `SourceSystemId` | `int` | Yes | FK to `SourceSystem`. |
| `Namespace` | `nvarchar(40)` | Yes | URL namespace, for example `soms`. |
| `AuthMode` | `int enum` | Yes | OAuth client credentials or signed webhook. |
| `IsEnabled` | `bit` | Yes | Endpoint enable flag. |
| `MaxPayloadBytes` | `int` | Yes | Payload size limit. |
| `MaxRetryAttempts` | `int` | Yes | Retry/dead-letter threshold. |

### `IntegrationBatch`

Source: `specs/feature/021A-source-system-foundation/data-model.md`

Description: Append-only inbound batch header.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `SourceSystemId` | `int` | Yes | FK to source system. |
| `BatchReference` | `nvarchar(100)` | Yes | External batch id. |
| `CorrelationId` | `uniqueidentifier` | Yes | End-to-end trace id. |
| `MessageCount` | `int` | Yes | Number of documents/messages in batch. |
| `ReceivedDate` | `datetime2` | Yes | Receipt timestamp. |

### `IntegrationInboundMessage`

Source: `specs/feature/021A-source-system-foundation/data-model.md`

Description: Staged raw inbound integration message with mutable processing status.

Common columns: Primary Key, Audit Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `SourceSystemId` | `int` | Yes | FK to `SourceSystem`. |
| `IntegrationBatchId` | `int` | No | Optional FK to `IntegrationBatch`. |
| `LegalEntityId` | `int` | No | Mapped legal entity; nullable until mapping succeeds. |
| `SourceDocumentType` | `nvarchar(60)` | Yes | Source document type. |
| `SourceDocumentNo` | `nvarchar(100)` | Conditional | Source document number; required if external id absent. |
| `ExternalDocumentId` | `nvarchar(100)` | Conditional | External id; required if document number absent. |
| `IdempotencyKey` | `nvarchar(256)` | Yes | Dedupe key. |
| `PayloadHash` | `char(64)` | Yes | SHA-256 payload hash. |
| `PayloadJson` | `nvarchar(max)` | Yes | Raw payload, access-controlled. |
| `CurrencyCode` | `nvarchar(3)` | No | Currency code when amounts are present. |
| `DocumentDate` | `date` | No | Source document date. |
| `Status` | `int enum` | Yes | Integration message status. |
| `CorrelationId` | `uniqueidentifier` | Yes | Trace id. |
| `ReceivedDate` | `datetime2` | Yes | Receipt timestamp. |
| `RetryCount` | `int` | Yes | Number of retry attempts. |

### `SourceDocument`

Source: `specs/feature/021A-source-system-foundation/data-model.md`

Description: Normalized inbound source document, one per source document.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `IntegrationInboundMessageId` | `int` | Yes | FK to inbound message. |
| `SourceSystemId` | `int` | Yes | FK to source system. |
| `LegalEntityId` | `int` | No | Mapped legal entity. |
| `SourceDocumentType` | `nvarchar(60)` | Yes | Source document type. |
| `SourceDocumentNo` | `nvarchar(100)` | No | Source document number. |
| `ExternalDocumentId` | `nvarchar(100)` | No | External document id. |
| `NormalizedReference` | `nvarchar(200)` | No | Generic normalized reference. |
| `ProcessingStatus` | `int enum` | Yes | Processing status. |

### `IntegrationError`

Source: `specs/feature/021A-source-system-foundation/data-model.md`

Description: Validation or processing errors, separate from raw payload.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `IntegrationInboundMessageId` | `int` | Yes | FK to inbound message. |
| `SourceDocumentId` | `int` | No | Optional FK to normalized source document. |
| `ErrorCode` | `nvarchar(60)` | Yes | Machine-readable error code. |
| `FieldPath` | `nvarchar(200)` | No | Failed field path. |
| `Message` | `nvarchar(500)` | Yes | Human-readable non-sensitive error. |
| `IsRetryable` | `bit` | Yes | Whether retry is allowed. |

### `IntegrationAuditLog`

Source: `specs/feature/021A-source-system-foundation/data-model.md`

Description: Append-only integration event/status/retry/config audit log.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `IntegrationInboundMessageId` | `int` | No | Related inbound message. |
| `SourceSystemId` | `int` | No | Related source system. |
| `EventType` | `int enum` | Yes | Received, validated, status changed, retried, dead-lettered, linked, or config changed. |
| `FromStatus` | `int enum` | No | Previous message status. |
| `ToStatus` | `int enum` | No | New message status. |
| `PerformedBy` | `nvarchar` | Yes | User or system actor. |
| `RoleSnapshot` | `nvarchar` | No | Actor role snapshot. |
| `Reason` | `nvarchar(500)` | No | Retry/cancel/config reason. |
| `CorrelationId` | `uniqueidentifier` | Yes | Trace id. |
| `Detail` | `nvarchar(max)` | No | Structured non-payload details. |
| `OccurredAtUtc` | `datetime2` | Yes | UTC event time. |

### `SourceDocumentJournalLink`

Source: `specs/feature/021A-source-system-foundation/data-model.md`

Description: Append-only link from normalized source document to generated journal.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `SourceDocumentId` | `int` | Yes | FK to `SourceDocument`. |
| `JournalId` | `int` | Yes | Linked journal id. |
| `LinkType` | `int enum` | Yes | Primary posting, adjustment, or reversal. |
| `CreatedAtUtc` | `datetime2` | Yes | Link creation timestamp. |

### `Customer`

Source: `specs/feature/021B-soms-integration/data-model.md`; `specs/feature/022-customer-master-sync/data-model.md`

Description: Customer master mirrored from CAPSUL and used by SOMS/AR.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `Code` | `string(50)` | Yes | Customer code, unique per legal entity. |
| `Name` | `string(200)` | Yes | Customer name. |
| `LegalEntityId` | `int` | Yes | FK to `LegalEntity`. |
| `CustomerSegment` | `string` | No | Segment used by revenue routing. |
| `IsActive` | `bit` | Yes | Active flag. |
| `Status` | `string(50)` | No | CAPSUL status. |
| `CallingName` | `string(200)` | No | CAPSUL calling name. |
| `CountryCode` | `string(10)` | No | Customer country code. |
| `CurrencyCode` | `string(10)` | No | Customer currency. |
| `CompanyCode` | `string(50)` | No | CAPSUL company code resolved to legal entity. |
| `CompanyName` | `string(200)` | No | CAPSUL company name. |
| `MotherCompanyAxCode` | `string(50)` | No | Mother-company AX code. |
| `WarehouseCode` | `string(50)` | No | Warehouse code from API. |
| `WarehouseSite` | `string(100)` | No | Warehouse site. |
| `WarehouseName` | `string(200)` | No | Warehouse name. |
| `ProvinceCode` | `string(20)` | No | Province code. |
| `ProvinceName` | `string(100)` | No | Province name. |
| `SalesPoolId` | `string(50)` | No | Sales pool id. |
| `StatisticsGroup` | `string(50)` | No | Statistics group. |
| `TaxGroup` | `string(50)` | No | Tax group. |
| `TaxNumber` | `string(100)` | No | Sensitive tax number. |
| `TaxType` | `string(50)` | No | Tax type. |
| `TaxRate` | `int` | No | Tax rate. |
| `TaxRegNo` | `string(100)` | No | Sensitive tax registration number. |
| `BankName` | `string(200)` | No | Sensitive bank name. |
| `SalesDistrict` | `string(100)` | No | Sales district. |
| `DeliveryTerm` | `string(50)` | No | Delivery term. |
| `ModeOfDelivery` | `string(50)` | No | Delivery mode. |
| `NonReturnableConsignment` | `string(10)` | No | Consignment flag string. |
| `NumberDeliveriesEntitled` | `int` | No | Delivery entitlement count. |
| `Worker` | `string(100)` | No | Worker/sales owner. |
| `GrRequired` | `string(10)` | No | Goods receipt required flag. |
| `ProformaRequired` | `string(10)` | No | Proforma required flag. |
| `TermOfPayment` | `string(50)` | No | Payment term. |
| `MandatoryCreditLimit` | `string(10)` | No | Mandatory credit-limit flag. |
| `CheckOverdueTransaction` | `string(10)` | No | Overdue-check flag. |
| `AlwaysReferredToCreditManagement` | `string(10)` | No | Credit-management referral flag. |
| `LegalRemarks` | `int` | No | Legal remarks code. |
| `InvoicingMethod` | `int` | No | Invoicing method code. |
| `CreditLimit` | `decimal(18,2)` | No | Customer credit limit. |
| `ChildCount` | `int` | No | Number of child customers. |
| `LastSyncedDate` | `datetime2` | No | Last sync touch timestamp. |
| `SyncStatus` | `string(50)` | No | Per-row sync status. |

### `SomsAccountMapping`

Source: `specs/feature/021B-soms-integration/data-model.md`; `specs/feature/033-settlement-fx-realised/data-model.md`; `specs/feature/036-unrealised-fx-revaluation/data-model.md`

Description: Per-legal-entity SOMS account determination and routing defaults.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `LegalEntityId` | `int` | Yes | FK to `LegalEntity`, unique per active row. |
| `TradeDebtorsAccountId` | `int` | Yes | AR control account. |
| `TaxPayableAccountId` | `int` | Yes | Output tax account. |
| `AccruedRevenueAccountId` | `int` | Yes | Accrued/unbilled revenue account. |
| `CustomerSuspenseAccountId` | `int` | Yes | Customer routing suspense account. |
| `DefaultRevenueAccountId` | `int` | Yes | Fallback revenue account. |
| `DefaultRebateAccountId` | `int` | Yes | Fallback rebate/contra-revenue account. |
| `RealisedFxAccountId` | `int` | No | Realized FX gain/loss account for AR settlement. |
| `UnrealisedFxAccountId` | `int` | No | Unrealized FX account for AR revaluation. |
| `IsActive` | `bit` | Yes | Mapping activation flag. |

### `SomsRevenueRouteMap`

Source: `specs/feature/021B-soms-integration/data-model.md`

Description: Revenue routing map from entity/dimensions/segment to revenue leaf account.

Common columns: Primary Key, Audit Columns, Soft Delete Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `LegalEntityId` | `int` | Yes | FK to `LegalEntity`. |
| `Division` | `nvarchar` | No | Optional route division key. |
| `Department` | `nvarchar` | No | Optional route department key. |
| `Segment` | `nvarchar` | No | Optional customer segment key. |
| `RevenueAccountId` | `int` | Yes | FK to routed revenue account. |

### `SomsRebateRouteMap`

Source: `specs/feature/021B-soms-integration/data-model.md`

Description: Rebate routing map from entity/customer/segment to rebate account.

Common columns: Primary Key, Audit Columns, Soft Delete Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `LegalEntityId` | `int` | Yes | FK to `LegalEntity`. |
| `CustomerId` | `int` | Conditional | FK to customer when routing by specific customer. |
| `Segment` | `nvarchar` | Conditional | Customer segment route key when not customer-specific. |
| `RebateAccountId` | `int` | Yes | FK to routed rebate account. |

### `SalesDocument` / `SalesInvoice`

Source: `specs/feature/021B-soms-integration/data-model.md`

Description: Accepted SOMS sales document. As-built type may be `SalesInvoice`.

Common columns: Primary Key, Audit Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `SourceDocumentId` | `int` | Yes | FK to 021A `SourceDocument`. |
| `IntegrationInboundMessageId` | `int` | Yes | FK to inbound message. |
| `LegalEntityId` | `int` | Yes | FK to `LegalEntity`. |
| `CustomerId` | `int` | No | FK to `Customer`; nullable for suspense routing. |
| `DocumentType` | `int enum` | Yes | Tax invoice, credit note, debit note, or trade rebate. |
| `EntryType` | `int enum` | Yes | Full/final, accrual, or accrual confirmation. |
| `SourceDocumentNo` | `nvarchar(100)` | Yes | SOMS source document number. |
| `OriginalInvoiceRef` | `nvarchar(100)` | No | Original invoice reference. |
| `NoteRef` | `nvarchar(100)` | No | Note/reference component. |
| `ReferencedDocumentNo` | `nvarchar` | No | Referenced original document number. |
| `ReferencedSalesDocumentId` | `int` | No | Self-FK to referenced document. |
| `ReferencedAccrualItemId` | `int` | No | Accrual item confirmed by this document. |
| `SoNumber` | `nvarchar` | No | Sales order number. |
| `SoState` | `nvarchar` | No | SOMS sales order state. |
| `Division` | `nvarchar` | No | Division/routing attribute. |
| `Department` | `nvarchar` | No | Department/routing attribute. |
| `Segment` | `nvarchar` | No | Customer/item segment. |
| `Warehouse` | `nvarchar` | No | Warehouse code. |
| `Site` | `nvarchar` | No | Site code. |
| `InvoiceDate` | `date` | Yes | Invoice date. |
| `DueDate` | `date` | No | Due date. |
| `CurrencyCode` | `nvarchar(3)` | Yes | Transaction currency. |
| `ExchangeRate` | `decimal(23,10)` | No | Transaction-to-functional rate. |
| `SubtotalAmount` | `decimal(23,6)` | Yes | Amount before tax. |
| `TaxAmount` | `decimal(23,6)` | Yes | Tax amount. |
| `TotalAmount` | `decimal(23,6)` | Yes | Total amount including tax. |
| `Status` | `int enum` | Yes | Normalized, accrued, posted, review, failed, or held. |
| `AccrualJournalId` | `int` | No | Accrual journal id. |
| `FinalJournalId` | `int` | No | Final posting journal id. |
| `ArOpenItemId` | `int` | No | Created AR open item id. |
| `RequiresReview` | `bit` | Yes | Review/suspense flag. |
| `SuspenseAccountId` | `int` | No | Account used for suspense routing. |
| `EInvoiceUuid` | `nvarchar` | No | E-invoice UUID. |
| `EInvoiceConfirmedAt` | `datetime2` | No | E-invoice confirmation time. |
| `CorrelationId` | `uniqueidentifier` | Yes | Integration trace id. |
| `SalPicCode` | `nvarchar(4)` | No | Salesperson-in-charge code (feature 067; mandatory at intake, nullable in DB). |
| `SalPicName` | `nvarchar(100)` | No | Salesperson-in-charge name (feature 067; mandatory at intake, nullable in DB). |

### `SalesDocumentLine` / `SalesInvoiceLine`

Source: `specs/feature/021B-soms-integration/data-model.md`

Description: Sales document line.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `SalesDocumentId` | `int` | Yes | FK to sales document. |
| `LineNumber` | `int` | Yes | Line sequence number. |
| `ItemCode` | `nvarchar` | No | Item code. |
| `Description` | `nvarchar` | No | Line description. |
| `Quantity` | `decimal(23,6)` | Yes | Quantity. |
| `UnitPrice` | `decimal(23,6)` | Yes | Unit price. |
| `LineAmount` | `decimal(23,6)` | Yes | Line amount. |
| `TaxCode` | `nvarchar` | No | Tax code. |
| `LineTaxAmount` | `decimal(23,6)` | Yes | Line tax amount. |
| `IsAdjustment` | `bit` | Yes | Adjustment line flag. |
| `RoutedAccountId` | `int` | Yes | Revenue/rebate account resolved for the line. |
| `BatchNo` | `nvarchar(25)` | No | SKU batch number (feature 067; mandatory at intake on physical-SKU lines, nullable in DB). |
| `ExpiryDate` | `date` | No | SKU expiry date (feature 067; mandatory at intake on physical-SKU lines, nullable in DB). |

### `ArOpenItem`

Source: `specs/feature/021B-soms-integration/data-model.md`; `specs/feature/030-ar-record-payment-in/data-model.md`

Description: AR open receivable/contra item.

Common columns: Primary Key, Audit Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `SalesDocumentId` | `int` | Yes | FK to originating sales document. |
| `LegalEntityId` | `int` | Yes | Entity scope. |
| `CustomerId` | `int` | Yes | FK to customer. |
| `OriginalAmount` | `decimal(23,6)` | Yes | Original sign-aware amount. |
| `AppliedAmount` | `decimal(23,6)` | Yes | Amount applied by credit notes/reductions. |
| `SettledAmount` | `decimal(23,6)` | Yes | Cash settlement amount from receipts. |
| `RemainingBalance` | `decimal(23,6)` | Yes | Remaining open balance. |
| `Status` | `int enum` | Yes | Open, partially applied, or closed. |
| `ReferencedArOpenItemId` | `int` | No | Linked original item for credit-note reduction. |

### `AccrualItem`

Source: `specs/feature/021B-soms-integration/data-model.md`; `specs/feature/021C-dms-integration/data-model.md`

Description: SOMS accrual lifecycle tracker.

Common columns: Primary Key, Audit Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `SalesDocumentId` | `int` | Yes | Originating sales document. |
| `LegalEntityId` | `int` | Yes | Entity scope. |
| `CustomerId` | `int` | Yes | Customer. |
| `AccrualJournalId` | `int` | Yes | Accrual journal. |
| `GrossAmount` | `decimal(23,6)` | Yes | Accrued gross amount. |
| `AccrualDate` | `date` | Yes | Accrual date. |
| `Status` | `int enum` | Yes | Open, reversed, or confirmed. |
| `ConfirmedBySalesDocumentId` | `int` | No | Sales document that confirmed the accrual. |
| `ConfirmedByPodDocumentId` | `int` | No | POD document that confirmed/released the accrual. |
| `ReversalJournalId` | `int` | No | Reversal journal. |

### `PodDocument`

Source: `specs/feature/021C-dms-integration/data-model.md`

Description: Normalized DMS proof-of-delivery evidence.

Common columns: Primary Key, Audit Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `IntegrationInboundMessageId` | `int` | Yes | FK to inbound message. |
| `SourceDocumentId` | `int` | Yes | FK to source document. |
| `LegalEntityId` | `int` | Yes | Entity scope. |
| `CustomerId` | `int` | No | Resolved customer. |
| `PodNumber` | `nvarchar(64)` | Yes | POD reference. |
| `SoNumber` | `nvarchar(64)` | Yes | Originating sales order. |
| `DoNumber` | `nvarchar(64)` | No | Delivery order number. |
| `Division` | `nvarchar(64)` | No | Division from POD. |
| `DocumentName` | `nvarchar(256)` | No | Source file/display name. |
| `CustomerCode` | `nvarchar(64)` | Yes | Customer code as received. |
| `CustomerName` | `nvarchar(256)` | No | Customer name as received. |
| `DeliveryStatus` | `int enum` | Yes | DMS delivery status. |
| `PromisedDeliveryDate` | `date` | No | Promised delivery date. |
| `ActualDeliveryDate` | `date` | No | Actual delivery date. |
| `LastStatusTimestamp` | `datetime2` | No | Last delivery status timestamp. |
| `AwbTrackingNumber` | `nvarchar(64)` | No | Shipment tracking number. |
| `CourierCode` | `nvarchar(32)` | No | Courier code. |
| `CurrencyCode` | `char(3)` | Yes | Transaction currency. |
| `ExchangeRate` | `decimal(23,10)` | No | Functional FX rate. |
| `TolerancePercent` | `decimal(9,4)` | Yes | Reconciliation tolerance. |
| `TotalExclTax` | `decimal(23,6)` | Yes | Delivered total excluding tax. |
| `TotalInclTax` | `decimal(23,6)` | Yes | Delivered total including tax. |
| `ReleasedCogsAmount` | `decimal(23,6)` | No | Cost basis for COGS release. |
| `MatchedAccrualItemId` | `int` | No | Matched accrual item. |
| `Status` | `int enum` | Yes | Received, normalized, posted, rejected, or held. |
| `JournalId` | `int` | No | Posted journal. |
| `CorrelationId` | `uniqueidentifier` | Yes | Integration trace id. |
| `PostedDate` | `datetime2` | No | Posting timestamp. |

### `PodDocumentLine`

Source: `specs/feature/021C-dms-integration/data-model.md`

Description: POD delivered item line.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `PodDocumentId` | `int` | Yes | FK to `PodDocument`. |
| `LineNo` | `int` | Yes | Line sequence. |
| `Sku` | `nvarchar(64)` | Yes | Delivered SKU. |
| `Uom` | `nvarchar(16)` | Yes | Unit of measure. |
| `DeliveredQty` | `decimal(23,6)` | Yes | Delivered quantity. |
| `UnitPrice` | `decimal(23,6)` | Yes | Unit price. |
| `TaxRate` | `decimal(9,4)` | Yes | Tax percentage. |
| `LineAmountExclTax` | `decimal(23,6)` | Yes | Line amount excluding tax. |
| `LineAmountInclTax` | `decimal(23,6)` | Yes | Line amount including tax. |

### `PodValidationError`

Source: `specs/feature/021C-dms-integration/data-model.md`

Description: Structured POD validation error.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `PodDocumentId` | `int` | No | Related POD document. |
| `IntegrationInboundMessageId` | `int` | Yes | Related inbound message. |
| `ErrorCode` | `nvarchar(64)` | Yes | Error code. |
| `Field` | `nvarchar(128)` | No | Offending field or line. |
| `Message` | `nvarchar(512)` | Yes | Human-readable non-sensitive message. |
| `Severity` | `nvarchar(16)` | Yes | Severity, usually Error. |

### `DmsAccountMapping`

Source: `specs/feature/021C-dms-integration/data-model.md`

Description: Per-entity DMS POD/COGS account mapping.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `LegalEntityId` | `int` | Yes | FK to `LegalEntity`, unique per active row. |
| `CostOfGoodsSoldAccountId` | `int` | Yes | COGS account. |
| `DeferredCogsAccountId` | `int` | Yes | Deferred COGS account. |
| `TradeReceivablesAccountId` | `int` | Yes | AR control account. |
| `AccruedRevenueAccountId` | `int` | Yes | Accrued revenue account. |
| `CustomerSuspenseAccountId` | `int` | No | Suspense account for routing gaps. |
| `PostCogsLegs` | `bit` | Yes | Whether to post COGS legs. |
| `IsActive` | `bit` | Yes | Mapping active flag. |

### `GrnDocument`

Source: `specs/feature/021D-wms-integration/data-model.md`

Description: Normalized WMS goods-receipt note evidence.

Common columns: Primary Key, Audit Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `IntegrationInboundMessageId` | `int` | Yes | FK to inbound message. |
| `SourceDocumentId` | `int` | Yes | FK to source document. |
| `LegalEntityId` | `int` | Yes | Entity scope. |
| `GrnNumber` | `nvarchar(64)` | Yes | WMS GRN reference. |
| `PoNumber` | `nvarchar(64)` | Yes | POMS PO reference. |
| `PomsInvoiceNumber` | `nvarchar(64)` | No | Supplier invoice reference. |
| `SupplierName` | `nvarchar(256)` | No | Supplier name as received. |
| `WarehouseCode` | `nvarchar(32)` | No | Receiving warehouse. |
| `GrnDate` | `date` | Yes | Physical receipt date. |
| `CurrencyCode` | `char(3)` | Yes | Transaction currency. |
| `ExchangeRate` | `decimal(23,10)` | No | Functional FX rate. |
| `ReceiptOutcome` | `int enum` | Yes | As per PO or different from PO. |
| `EntryType` | `int enum` | Yes | Full complete, accrual GRNI, or accrual confirmation. |
| `QualityInspectionPassed` | `bit` | Yes | Required posting gate. |
| `OverDeliveryApproved` | `bit` | Yes | Required when over-delivery exists. |
| `CnStatus` | `int enum` | No | Credit-note/discrepancy status. |
| `DiscrepantValue` | `decimal(23,6)` | No | Discrepancy amount. |
| `TolerancePercent` | `decimal(9,4)` | Yes | Three-way-match tolerance. |
| `ThreeWayMatchState` | `int enum` | Yes | Match or discrepancy snapshot. |
| `TotalExclTax` | `decimal(23,6)` | Yes | Total excluding tax. |
| `TotalTax` | `decimal(23,6)` | Yes | Total tax. |
| `TotalInclTax` | `decimal(23,6)` | Yes | Total including tax. |
| `Status` | `int enum` | Yes | Received, normalized, posted, rejected, or held. |
| `JournalId` | `int` | No | Posted inventory journal. |
| `CorrelationId` | `uniqueidentifier` | Yes | Integration trace id. |
| `PostedDate` | `datetime2` | No | Posting timestamp. |

### `GrnDocumentLine`

Source: `specs/feature/021D-wms-integration/data-model.md`

Description: GRN received line with PO comparison values.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `GrnDocumentId` | `int` | Yes | FK to `GrnDocument`. |
| `LineNo` | `int` | Yes | Line sequence. |
| `Sku` | `nvarchar(64)` | Yes | Received SKU. |
| `Uom` | `nvarchar(16)` | Yes | Unit of measure. |
| `ReceivedQty` | `decimal(23,6)` | Yes | Received quantity. |
| `UnitPrice` | `decimal(23,6)` | Yes | Unit price. |
| `TaxRate` | `decimal(9,4)` | Yes | Tax rate. |
| `ValueExclTax` | `decimal(23,6)` | Yes | Received value excluding tax. |
| `ValueInclTax` | `decimal(23,6)` | Yes | Received value including tax. |
| `PoOrderedQty` | `decimal(23,6)` | No | PO ordered quantity. |
| `PoUnitPrice` | `decimal(23,6)` | No | PO unit price. |
| `PoOrderedValue` | `decimal(23,6)` | No | PO ordered value. |
| `IsSkuResolved` | `bit` | Yes | False routes to inventory suspense. |

### `GrnDiscrepancy`

Source: `specs/feature/021D-wms-integration/data-model.md`

Description: Discrepancy records for GRNs where receipt differs from PO.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `GrnDocumentId` | `int` | Yes | FK to `GrnDocument`. |
| `DiscrepancyType` | `int enum` | Yes | Discrepancy category. |
| `Notes` | `nvarchar(512)` | Conditional | Required when discrepancy type is Other. |

### `WmsCogsBatchDocument`

Source: `specs/feature/021D-wms-integration/data-model.md`

Description: Normalized WMS SO-batch COGS allocation evidence.

Common columns: Primary Key, Audit Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `IntegrationInboundMessageId` | `int` | Yes | FK to inbound message. |
| `SourceDocumentId` | `int` | Yes | FK to source document. |
| `LegalEntityId` | `int` | Yes | Entity scope. |
| `CustomerId` | `int` | No | Resolved customer. |
| `BatchDocumentNo` | `nvarchar(64)` | Yes | WMS batch document number. |
| `SoNumber` | `nvarchar(64)` | Yes | SOMS sales order key. |
| `AppliedCnNumber` | `nvarchar(64)` | No | Applied credit-note reference. |
| `SourcePoReference` | `nvarchar(64)` | No | Source PO reference. |
| `WarehouseCode` | `nvarchar(32)` | No | Warehouse. |
| `Division` | `nvarchar(64)` | No | Division/department attribute. |
| `ItemGroup` | `nvarchar(64)` | No | Item group/family/category. |
| `BatchNumber` | `nvarchar(64)` | No | Batch reference. |
| `CustomerCode` | `nvarchar(64)` | No | Customer code as received. |
| `CustomerName` | `nvarchar(256)` | No | Customer name as received. |
| `DocumentDate` | `date` | Yes | JE date basis. |
| `CurrencyCode` | `char(3)` | Yes | Transaction currency. |
| `ExchangeRate` | `decimal(23,10)` | No | Functional FX rate. |
| `EntryType` | `int enum` | Yes | Deferred pick, full final, accrual, or accrual confirmation. |
| `TotalExclTax` | `decimal(23,6)` | Yes | Total excluding tax. |
| `TotalInclTax` | `decimal(23,6)` | Yes | Total including tax. |
| `Status` | `int enum` | Yes | Received, normalized, posted, rejected, or held. |
| `JournalId` | `int` | No | Posted COGS journal. |
| `CorrelationId` | `uniqueidentifier` | Yes | Integration trace id. |
| `PostedDate` | `datetime2` | No | Posting timestamp. |

### `WmsCogsBatchLine`

Source: `specs/feature/021D-wms-integration/data-model.md`

Description: WMS landed-cost COGS line.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `WmsCogsBatchDocumentId` | `int` | Yes | FK to COGS batch document. |
| `LineNo` | `int` | Yes | Line sequence. |
| `Sku` | `nvarchar(64)` | Yes | Item/SKU. |
| `Uom` | `nvarchar(16)` | Yes | Unit of measure. |
| `QtyPicked` | `decimal(23,6)` | Yes | Picked quantity. |
| `LandedUnitCost` | `decimal(23,6)` | Yes | Landed unit cost. |
| `TaxRate` | `decimal(9,4)` | Yes | Tax rate. |
| `LineTotalExclTax` | `decimal(23,6)` | Yes | Line total excluding tax. |
| `LineTotalInclTax` | `decimal(23,6)` | Yes | Line total including tax. |
| `IsSkuResolved` | `bit` | Yes | False routes to inventory suspense. |

### `WmsValidationError`

Source: `specs/feature/021D-wms-integration/data-model.md`

Description: Structured WMS validation error for GRN or COGS flows.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `IntegrationInboundMessageId` | `int` | Yes | FK to inbound message. |
| `GrnDocumentId` | `int` | No | Related GRN document. |
| `WmsCogsBatchDocumentId` | `int` | No | Related COGS batch document. |
| `ErrorCode` | `nvarchar(64)` | Yes | Error code. |
| `Field` | `nvarchar(128)` | No | Offending field or line. |
| `Message` | `nvarchar(512)` | Yes | Human-readable non-sensitive message. |
| `Severity` | `nvarchar(16)` | Yes | Severity, usually Error. |

### `WmsAccountMapping`

Source: `specs/feature/021D-wms-integration/data-model.md`

Description: Per-entity WMS GRN/COGS account mapping.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `LegalEntityId` | `int` | Yes | FK to `LegalEntity`, unique per active row. |
| `InventoryGoodsReceivedAccountId` | `int` | Yes | Inventory goods received account. |
| `GrIrClearingAccountId` | `int` | Yes | GR/IR clearing account. |
| `InputVatAccountId` | `int` | Yes | Input VAT account. |
| `TradeCreditorsAccountId` | `int` | Yes | Trade creditors account. |
| `DeferredCogsAccountId` | `int` | Yes | Deferred COGS account. |
| `InventoryFinishedGoodsAccountId` | `int` | Yes | Finished goods inventory account. |
| `InventoryRawMaterialsAccountId` | `int` | Yes | Raw materials inventory account. |
| `CogsDirectMaterialsAccountId` | `int` | Yes | COGS direct materials account. |
| `CogsAccruedAccountId` | `int` | No | COGS accrued account, pending sign-off. |
| `AccruedCogsLiabilityAccountId` | `int` | Yes | Accrued COGS liability account. |
| `InventoryLossAccountId` | `int` | No | Inventory loss/write-off account. |
| `InventorySuspenseAccountId` | `int` | No | Inventory suspense account. |
| `TolerancePercent` | `decimal(9,4)` | Yes | Three-way-match tolerance. |
| `IsActive` | `bit` | Yes | Mapping active flag. |

### `PomsPurchaseDocument`

Source: `specs/feature/021E-poms-integration/data-model.md`; `specs/feature/032-ap-record-payment-out/data-model.md`

Description: Normalized POMS supplier invoice or credit-note evidence, also AP settlement target.

Common columns: Primary Key, Audit Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `InboundMessageId` | `int` | Yes | FK to integration inbound message. |
| `LegalEntityId` | `int` | Yes | FK to `LegalEntity`. |
| `LegalEntityCode` | `nvarchar(20)` | Yes | Entity code snapshot. |
| `DocumentType` | `int enum` | Yes | Supplier invoice or credit-note type. |
| `EntryType` | `int enum` | Yes | Full/final, accrual, or accrual confirmation. |
| `DocumentNumber` | `nvarchar(60)` | Yes | Invoice or credit-note number. |
| `PoReference` | `nvarchar(60)` | No | PO reference. |
| `GrnNumber` | `nvarchar(60)` | No | GRN reference. |
| `SupplierCode` | `nvarchar(40)` | No | Supplier code from payload. |
| `SupplierAccountCode` | `nvarchar(40)` | No | Supplier account code. |
| `SupplierName` | `nvarchar(200)` | No | Supplier display name. |
| `SalPicCode` | `nvarchar(4)` | No | Salesperson-in-charge code (feature 067; mandatory at intake, nullable in DB). |
| `SalPicName` | `nvarchar(100)` | No | Salesperson-in-charge name (feature 067; mandatory at intake, nullable in DB). |
| `SalesTypeClassification` | `int enum` | Yes | Sales-type/routing classification. |
| `SalesTypeLabel` | `nvarchar(120)` | No | Raw classification label. |
| `PostingDate` | `date` | Yes | Posting date. |
| `CurrencyCode` | `nchar(3)` | Yes | Transaction currency. |
| `ExchangeRate` | `decimal(23,10)` | No | Functional FX rate. |
| `TotalExclTax` | `decimal(23,6)` | Yes | Total excluding tax. |
| `TotalTax` | `decimal(23,6)` | Yes | Tax total. |
| `TotalInclTax` | `decimal(23,6)` | Yes | Total including tax. |
| `SettledAmount` | `decimal(23,6)` | Yes | Cumulative supplier cash settlement amount. |
| `ThreeWayMatchState` | `int enum` | Yes | Three-way-match state. |
| `Status` | `int enum` | Yes | Integration/posting lifecycle status. |
| `RequiresReview` | `bit` | Yes | Review/suspense flag. |
| `IsSoftClosePosted` | `bit` | Yes | Posted into soft-closed period flag. |
| `JournalId` | `int` | No | Posted journal. |
| `PostedAtUtc` | `datetime2` | No | Posting timestamp. |
| `CorrelationId` | `uniqueidentifier` | Yes | Integration trace id. |

### `PomsPurchaseLine`

Source: `specs/feature/021E-poms-integration/data-model.md`

Description: POMS purchase document line.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `PurchaseDocumentId` | `int` | Yes | FK to `PomsPurchaseDocument`. |
| `LineNumber` | `int` | Yes | Line sequence. |
| `ItemCode` | `nvarchar(60)` | No | Item code. |
| `Sku` | `nvarchar(60)` | No | SKU. |
| `Uom` | `nvarchar(20)` | No | Unit of measure. |
| `Quantity` | `decimal(23,6)` | Yes | Invoiced quantity. |
| `UnitPrice` | `decimal(23,6)` | Yes | Unit price. |
| `TaxRate` | `decimal(9,4)` | Yes | Tax rate. |
| `LineExclTax` | `decimal(23,6)` | Yes | Line amount excluding tax. |
| `LineTax` | `decimal(23,6)` | Yes | Line tax amount. |
| `LineInclTax` | `decimal(23,6)` | Yes | Line amount including tax. |
| `PoOrderedQty` | `decimal(23,6)` | No | PO ordered quantity. |
| `PoUnitPrice` | `decimal(23,6)` | No | PO unit price. |
| `PoOrderedValue` | `decimal(23,6)` | No | PO ordered value. |
| `BatchNo` | `nvarchar(25)` | No | SKU batch number (feature 067; mandatory at intake unless Rebate Credit Note, nullable in DB). |
| `ExpiryDate` | `date` | No | SKU expiry date (feature 067; mandatory at intake unless Rebate Credit Note, nullable in DB). |

### `PomsValidationError`

Source: `specs/feature/021E-poms-integration/data-model.md`

Description: Structured POMS validation/review reason.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `PurchaseDocumentId` | `int` | Yes | FK to `PomsPurchaseDocument`. |
| `ErrorCode` | `nvarchar(60)` | Yes | Error code. |
| `Field` | `nvarchar(120)` | No | Offending field or line. |
| `Message` | `nvarchar(500)` | Yes | Human-readable non-sensitive message. |
| `Severity` | `int enum` | Yes | Reject, warn, or review. |

### `PomsAccountMapping`

Source: `specs/feature/021E-poms-integration/data-model.md`; `specs/feature/033-settlement-fx-realised/data-model.md`; `specs/feature/036-unrealised-fx-revaluation/data-model.md`

Description: Per-entity POMS account determination and AP bank/FX setup.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `LegalEntityId` | `int` | Yes | FK to `LegalEntity`, unique per active row. |
| `InventoryGoodsReceivedAccountId` | `int` | Yes | Inventory goods received account. |
| `InputVatAccountId` | `int` | Yes | Input VAT account. |
| `TradeCreditorsAccountId` | `int` | Yes | Trade creditors/AP control account. |
| `GrIrClearingAccountId` | `int` | Yes | GR/IR clearing account. |
| `PurchaseRebateAccountId` | `int` | No | Purchase rebate account. |
| `AccruedSupplierRebateReceivableAccountId` | `int` | No | Accrued supplier rebate receivable account. |
| `SupplierRoutingSuspenseAccountId` | `int` | No | Supplier routing suspense account. |
| `BankLocalAccountId` | `int` | No | Local bank account for AP payments. |
| `RealisedFxAccountId` | `int` | No | Realized FX gain/loss account for AP settlement. |
| `UnrealisedFxAccountId` | `int` | No | Unrealized FX account for AP revaluation. |
| `TolerancePercent` | `decimal(9,4)` | Yes | Three-way-match tolerance. |
| `IsActive` | `bit` | Yes | Mapping active flag. |

### `CustomerInvoiceProfile`

Source: `specs/feature/022-customer-master-sync/data-model.md`

Description: One-to-one CAPSUL invoice profile for a customer.

Common columns: Primary Key, Audit Columns, Soft Delete Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `CustomerId` | `int` | Yes | FK to owning `Customer`. |
| `Individual` | `bit` | No | Individual flag. |
| `AxCustomerRef` | `string(50)` | No | AX customer reference. |
| `Type` | `string(50)` | No | Invoice profile type. |
| `GroupDeliveries` | `bit` | No | Group deliveries flag. |
| `Consolidate` | `bit` | No | Consolidate flag. |
| `EndOfMonth` | `bit` | No | End-of-month flag. |
| `Frequency` | `string(50)` | No | Invoicing frequency. |
| `Weekday` | `string(20)` | No | Invoicing weekday. |
| `NextInvoicingDate` | `datetime2` | No | Next invoicing date. |
| `DayOfMonth` | `string(10)` | No | Day of month. |

### `CustomerDivisionDepartment`

Source: `specs/feature/022-customer-master-sync/data-model.md`

Description: Customer division/department assignment.

Common columns: Primary Key, Audit Columns, Soft Delete Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `CustomerId` | `int` | Yes | FK to owning `Customer`. |
| `DivisionId` | `int` | Yes | FK to `Division`. |
| `DepartmentId` | `int` | Yes | FK to `Department`. |
| `IsPrimary` | `bit` | No | Primary assignment flag. |

### `CustomerMarketSegment`

Source: `specs/feature/022-customer-master-sync/data-model.md`

Description: Market segment under a customer division/department assignment.

Common columns: Primary Key, Audit Columns, Soft Delete Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `CustomerDivisionDepartmentId` | `int` | Yes | FK to assignment. |
| `SegmentCode` | `string(50)` | Yes | Market segment code. |
| `SegmentName` | `string(200)` | No | Market segment name. |

### `CustomerSyncRun`

Source: `specs/feature/022-customer-master-sync/data-model.md`

Description: Append-only customer sync run history.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `Source` | `string` | Yes | Source system, normally CAPSUL. |
| `TriggerType` | `int enum` | Yes | Manual sync trigger. |
| `TriggeredBy` | `string` | Yes | Actor who triggered sync. |
| `StartedAt` | `datetime2` | Yes | Sync start timestamp. |
| `CompletedAt` | `datetime2` | No | Completion timestamp. Null while running. |
| `Outcome` | `int enum` | Yes | Success, partial success, or failed. |
| `CustomersAdded` | `int` | Yes | Customers added. |
| `CustomersUpdated` | `int` | Yes | Customers updated. |
| `CustomersDeactivated` | `int` | Yes | Customers deactivated. |
| `AssignmentsSynced` | `int` | Yes | Assignments synced. |
| `SkippedCount` | `int` | Yes | Records skipped. |
| `ErrorCount` | `int` | Yes | Errors counted. |
| `CorrelationId` | `uniqueidentifier` | Yes | Trace id. |
| `ErrorMessage` | `string` | No | Non-sensitive failure summary. |

### `Supplier`

Source: `specs/feature/029-supplier-master-sync/data-model.md`

Description: Supplier master mirrored from CAPSUL, scoped by legal entity.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `Code` | `string(50)` | Yes | Supplier code, unique per legal entity. |
| `Name` | `string(200)` | Yes | Supplier name. |
| `LegalEntityId` | `int` | Yes | FK to `LegalEntity`. |
| `IsActive` | `bit` | Yes | Active flag derived from CAPSUL status. |
| `Status` | `string(10)` | No | CAPSUL status. |
| `CompanyCode` | `string(50)` | No | CAPSUL company code. |
| `CompanyName` | `string(200)` | No | CAPSUL company name. |
| `CountryCode` | `string(10)` | No | Supplier country code. |
| `CountryName` | `string(100)` | No | Supplier country name. |
| `PaymentTerm` | `string(50)` | No | Supplier payment term. |
| `CurrencyCode` | `string(10)` | No | Default supplier currency. |
| `LastSyncedDate` | `datetime2` | No | Last sync touch timestamp. |
| `SyncStatus` | `string(50)` | No | Per-row sync status. |

### `SupplierSyncRun`

Source: `specs/feature/029-supplier-master-sync/data-model.md`

Description: Append-only supplier sync run history.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `Source` | `string(50)` | Yes | Source system, normally CAPSUL. |
| `TriggerType` | `int enum` | Yes | Manual sync trigger. |
| `TriggeredBy` | `string(256)` | Yes | Actor who triggered sync. |
| `StartedAt` | `datetime2` | Yes | Sync start timestamp. |
| `CompletedAt` | `datetime2` | No | Completion timestamp. Null while running. |
| `Outcome` | `int enum` | Yes | Success, partial success, or failed. |
| `SuppliersAdded` | `int` | Yes | Suppliers added. |
| `SuppliersUpdated` | `int` | Yes | Suppliers updated. |
| `SuppliersDeactivated` | `int` | Yes | Suppliers deactivated. |
| `SkippedCount` | `int` | Yes | Records skipped. |
| `ErrorCount` | `int` | Yes | Errors counted. |
| `CorrelationId` | `uniqueidentifier` | Yes | Trace id. |
| `ErrorMessage` | `string(1000)` | No | Non-sensitive failure summary. |

### `CustomerReceipt`

Source: `specs/feature/030-ar-record-payment-in/data-model.md`; `specs/feature/033-settlement-fx-realised/data-model.md`

Description: Append-only posted AR cash receipt evidence.

Common columns: Primary Key, Audit Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `LegalEntityId` | `int` | Yes | Posting entity. |
| `CustomerId` | `int` | Yes | FK to settled customer. |
| `ReceiptDate` | `date` | Yes | Payment receipt date. |
| `CurrencyCode` | `nvarchar(3)` | Yes | Receipt currency. |
| `Amount` | `decimal(23,6)` | Yes | Receipt amount. |
| `BankAccountId` | `int` | Yes | Debit bank account. |
| `JournalId` | `int` | Yes | Posted settlement journal. |
| `Reference` | `nvarchar(64)` | No | Optional user reference. |
| `IdempotencyKey` | `uniqueidentifier` | No | Replay guard. |
| `Status` | `int enum` | Yes | Posted in v1; void reserved. |
| `SettlementRate` | `decimal(18,6)` | No | Receipt-date FX rate for foreign-currency settlements. |
| `RealisedFxAmount` | `decimal(23,6)` | No | Signed realized FX amount. |

### `CustomerReceiptAllocation`

Source: `specs/feature/030-ar-record-payment-in/data-model.md`

Description: Allocation from a customer receipt to an AR open item.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `CustomerReceiptId` | `int` | Yes | FK to `CustomerReceipt`. |
| `ArOpenItemId` | `int` | Yes | FK to settled `ArOpenItem`. |
| `AllocatedAmount` | `decimal(23,6)` | Yes | Amount allocated to the item. |

### `ArBankAccountMapping`

Source: `specs/feature/030-ar-record-payment-in/data-model.md`

Description: Per-entity bank GL account mapping for AR receipts.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `LegalEntityId` | `int` | Yes | FK to `LegalEntity`, unique. |
| `BankAccountId` | `int` | Yes | Bank GL leaf account. |
| `IsActive` | `bit` | Yes | Active flag. |

### `SupplierPayment`

Source: `specs/feature/032-ap-record-payment-out/data-model.md`; `specs/feature/033-settlement-fx-realised/data-model.md`

Description: Append-only posted AP supplier payment evidence.

Common columns: Primary Key, Audit Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `LegalEntityId` | `int` | Yes | Posting entity. |
| `SupplierId` | `int` | Yes | FK to settled supplier. |
| `PaymentDate` | `date` | Yes | Supplier payment date. |
| `CurrencyCode` | `nvarchar(3)` | Yes | Payment currency. |
| `Amount` | `decimal(23,6)` | Yes | Payment amount. |
| `BankAccountId` | `int` | Yes | Credit bank account. |
| `JournalId` | `int` | Yes | Posted settlement journal. |
| `Reference` | `nvarchar(64)` | No | Optional user reference. |
| `IdempotencyKey` | `uniqueidentifier` | No | Replay guard. |
| `Status` | `int enum` | Yes | Posted in v1; void reserved. |
| `SettlementRate` | `decimal(18,6)` | No | Payment-date FX rate for foreign-currency settlements. |
| `RealisedFxAmount` | `decimal(23,6)` | No | Signed realized FX amount. |

### `SupplierPaymentAllocation`

Source: `specs/feature/032-ap-record-payment-out/data-model.md`

Description: Allocation from a supplier payment to a POMS bill.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `SupplierPaymentId` | `int` | Yes | FK to `SupplierPayment`. |
| `PomsPurchaseDocumentId` | `int` | Yes | FK to settled `PomsPurchaseDocument`. |
| `AllocatedAmount` | `decimal(23,6)` | Yes | Amount allocated to the bill. |

## Bank, FX, Opening Balances, Budgets, And Alerts

### `BankReconciliation`

Source: `specs/feature/035-bank-reconciliation/data-model.md`

Description: Bank reconciliation aggregate root for one bank account and fiscal period.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `LegalEntityId` | `int` | Yes | Owning legal entity. |
| `BankAccountId` | `int` | Yes | FK to bank account leaf. |
| `FiscalYearPeriodId` | `int` | Yes | FK to reconciliation period. |
| `CurrencyCode` | `nvarchar(3)` | Yes | Bank currency. |
| `Status` | `int enum` | Yes | Open, reconciled, or locked. |
| `StatementClosingBalance` | `decimal(18,4)` | No | Statement closing balance snapshot. |
| `GlClosingBalance` | `decimal(18,4)` | No | GL closing balance snapshot. |
| `Variance` | `decimal(18,4)` | No | Statement minus GL variance. |
| `ReconciledBy` | `nvarchar` | No | Reconciliation actor. |
| `ReconciledDate` | `datetimeoffset` | No | Reconciliation timestamp. |
| `LockedBy` | `nvarchar` | No | Lock actor. |
| `LockedDate` | `datetimeoffset` | No | Lock timestamp. |
| `ReopenedBy` | `nvarchar` | No | Reopen actor. |
| `ReopenedDate` | `datetimeoffset` | No | Reopen timestamp. |
| `ReopenReason` | `nvarchar` | No | Reopen reason. |

### `BankStatement`

Source: `specs/feature/035-bank-reconciliation/data-model.md`

Description: Imported or synthesized bank statement header.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `BankReconciliationId` | `int` | Yes | FK to `BankReconciliation`. |
| `LegalEntityId` | `int` | Yes | Denormalized entity scope. |
| `BankAccountId` | `int` | Yes | Bank account. |
| `CurrencyCode` | `nvarchar(3)` | Yes | Statement currency. |
| `StatementFormat` | `int enum` | Yes | MT940, CAMT.053, CSV, or internal. |
| `PeriodStart` | `date` | Yes | Statement start date. |
| `PeriodEnd` | `date` | Yes | Statement end date. |
| `OpeningBalance` | `decimal(18,4)` | Yes | Opening bank balance. |
| `ClosingBalance` | `decimal(18,4)` | Yes | Closing bank balance. |
| `LineCount` | `int` | Yes | Number of statement lines. |
| `ImportedBy` | `nvarchar` | Yes | Import actor. |
| `ImportedDate` | `datetimeoffset` | Yes | Import timestamp. |
| `IsSynthesized` | `bit` | Yes | True for v1 synthesized statements. |
| `SeedFingerprint` | `nvarchar(64)` | Yes | Deterministic synthesis hash. |

### `BankStatementLine`

Source: `specs/feature/035-bank-reconciliation/data-model.md`

Description: Append-only bank statement line.

Common columns: Primary Key, Audit Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `BankStatementId` | `int` | Yes | FK to `BankStatement`. |
| `BankReconciliationId` | `int` | Yes | Denormalized reconciliation workspace id. |
| `ValueDate` | `date` | Yes | Bank value date. |
| `PostingDate` | `date` | Yes | Bank posting date. |
| `Narration` | `nvarchar(500)` | Yes | Bank line description. |
| `Reference` | `nvarchar(100)` | No | Optional bank reference. |
| `Debit` | `decimal(18,4)` | Yes | Debit amount. |
| `Credit` | `decimal(18,4)` | Yes | Credit amount. |
| `RunningBalance` | `decimal(18,4)` | Yes | Bank running balance. |
| `Source` | `int enum` | Yes | Source classification. |
| `AutoJeKind` | `int enum` | Yes | Auto-JE marker. |
| `MatchStatus` | `int enum` | Yes | Unmatched, suggested, matched, or excluded. |
| `SuggestedConfidence` | `int enum` | Yes | Suggested match confidence. |
| `SuggestedTier` | `int` | Yes | Suggested match tier, 0 to 5. |

### `ReconciliationMatch`

Source: `specs/feature/035-bank-reconciliation/data-model.md`

Description: Append-only confirmed match between a bank statement line and a target.

Common columns: Primary Key, Audit Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `BankReconciliationId` | `int` | Yes | FK to reconciliation. |
| `BankStatementLineId` | `int` | Yes | FK to matched bank statement line. |
| `JournalId` | `int` | Conditional | Cash book journal target. |
| `ArOpenItemId` | `int` | Conditional | AR target. |
| `ApOpenItemId` | `int` | Conditional | AP target. |
| `BankChargeJournalId` | `int` | Conditional | Generated bank charge/interest journal. |
| `MatchKind` | `int enum` | Yes | Exact, fuzzy, tolerance, bulk, recurring, manual, or forced. |
| `MatchTier` | `int` | Yes | Match tier. |
| `Confidence` | `int enum` | Yes | Confidence score. |
| `IsForced` | `bit` | Yes | CFO force-match flag. |
| `MatchedBy` | `nvarchar` | Yes | Match actor. |
| `MatchedDate` | `datetimeoffset` | Yes | Match timestamp. |
| `BulkGroupKey` | `nvarchar(40)` | No | Bulk match group key. |
| `IsActive` | `bit` | Yes | False when unmatched/removed. |

### `ReconcilingItem`

Source: `specs/feature/035-bank-reconciliation/data-model.md`

Description: Lifecycle record for unmatched bank-only or GL-only differences.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `BankReconciliationId` | `int` | Yes | FK to reconciliation. |
| `LegalEntityId` | `int` | Yes | Entity scope. |
| `BankAccountId` | `int` | Yes | Bank account. |
| `Kind` | `int enum` | Yes | Bank-only or GL-only. |
| `Subkind` | `int enum` | Yes | Charge, receipt, cheque, deposit, interest, or other. |
| `Description` | `nvarchar(500)` | Yes | Item explanation. |
| `Amount` | `decimal(18,4)` | Yes | Item amount. |
| `CurrencyCode` | `nvarchar(3)` | Yes | Currency. |
| `RaisedDate` | `date` | Yes | Aging basis date. |
| `Status` | `int enum` | Yes | Open, investigating, resolved, or written off. |
| `BankStatementLineId` | `int` | No | Originating bank statement line. |
| `PostedJournalId` | `int` | No | Resolving journal. |
| `FollowUpNotes` | `nvarchar(1000)` | No | Follow-up notes. |
| `ResolvedBy` | `nvarchar` | No | Resolver actor. |
| `ResolvedDate` | `datetimeoffset` | No | Resolution timestamp. |
| `EscalatedBy` | `nvarchar` | No | Escalation actor. |
| `EscalatedDate` | `datetimeoffset` | No | Escalation timestamp. |

### `ReconciliationAuditEvent`

Source: `specs/feature/035-bank-reconciliation/data-model.md`

Description: Append-only bank reconciliation audit trail.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `BankReconciliationId` | `int` | Yes | FK to reconciliation. |
| `EventType` | `int enum` | Yes | Reconciliation audit event. |
| `Actor` | `nvarchar(200)` | Yes | Actor display/name. |
| `ActorRole` | `nvarchar(50)` | No | Actor role. |
| `OccurredDate` | `datetimeoffset` | Yes | Event timestamp. |
| `Summary` | `nvarchar(500)` | Yes | Human-readable summary. |
| `PayloadJson` | `nvarchar(max)` | No | Structured event details. |
| `CorrelationId` | `uniqueidentifier` | No | Correlates with period close/audit events. |

### `FxRevaluationRun`

Source: `specs/feature/036-unrealised-fx-revaluation/data-model.md`

Description: One unrealized FX revaluation execution for one legal entity and period.

Common columns: Primary Key, Audit Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `LegalEntityId` | `int` | Yes | FK to `LegalEntity`. |
| `FiscalYearPeriodId` | `int` | Yes | FK to revalued period. |
| `Status` | `int enum` | Yes | Posted, superseded, or failed. |
| `RevaluationJournalId` | `int` | No | Period-end revaluation journal. |
| `ReversalJournalId` | `int` | No | Next-period reversal journal. |
| `BackoutJournalId` | `int` | No | Supersession backout journal. |
| `BackoutReversalJournalId` | `int` | No | Supersession reversal backout journal. |
| `SupersedesRunId` | `int` | No | Prior run superseded by this run. |
| `RateTypeId` | `int` | Yes | Rate type snapshot. |
| `TotalUnrealisedGainLoss` | `decimal(23,6)` | Yes | Signed functional gain/loss total. |
| `ExcludedCurrenciesJson` | `nvarchar(1000)` | No | Skipped currencies and reasons. |
| `ActorRole` | `nvarchar(100)` | No | Actor role snapshot. |
| `IdempotencyKey` | `uniqueidentifier` | No | Replay guard. |

### `FxRevaluationLine`

Source: `specs/feature/036-unrealised-fx-revaluation/data-model.md`

Description: Per-open-item unrealized FX revaluation detail.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `FxRevaluationRunId` | `int` | Yes | FK to revaluation run. |
| `Side` | `int enum` | Yes | AR or AP exposure. |
| `ArOpenItemId` | `int` | Conditional | AR open item when side is AR. |
| `PomsPurchaseDocumentId` | `int` | Conditional | AP document when side is AP. |
| `CurrencyCode` | `nvarchar(3)` | Yes | Transaction currency. |
| `OutstandingAmount` | `decimal(23,6)` | Yes | Outstanding transaction amount. |
| `BookingRate` | `decimal(18,8)` | Yes | Original booking rate. |
| `ClosingRate` | `decimal(18,8)` | Yes | Closing/revaluation rate. |
| `ClosingRateDate` | `date` | Yes | Date of rate used. |
| `CarriedFunctionalValue` | `decimal(23,6)` | Yes | Outstanding amount at booking rate. |
| `RevaluedFunctionalValue` | `decimal(23,6)` | Yes | Outstanding amount at closing rate. |
| `UnrealisedDifference` | `decimal(23,6)` | Yes | Signed revaluation difference. |

### `OpeningBalanceDraft`

Source: `specs/feature/037-opening-balances/data-model.md`

Description: Working cutover trial balance workspace per legal entity.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `LegalEntityId` | `int` | Yes | FK to `LegalEntity`. |
| `CutoverDate` | `date` | Yes | Opening balance journal date. |
| `Status` | `int enum` | Yes | Draft, confirmed, or reversed. |
| `JournalId` | `int` | No | Effective opening balance journal. |
| `ConfirmedBy` | `nvarchar(256)` | No | Confirmation actor. |
| `ConfirmedDate` | `datetime2` | No | Confirmation timestamp. |
| `ActorRole` | `nvarchar(100)` | No | Actor role snapshot. |
| `IdempotencyKey` | `uniqueidentifier` | No | Confirm replay guard. |

### `OpeningBalanceLine`

Source: `specs/feature/037-opening-balances/data-model.md`

Description: Entered debit/credit opening balance amount for a postable account.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `OpeningBalanceDraftId` | `int` | Yes | FK to opening balance draft. |
| `AccountId` | `int` | Yes | FK to postable account. |
| `DebitAmount` | `decimal(23,6)` | Yes | Debit amount, zero when credit side used. |
| `CreditAmount` | `decimal(23,6)` | Yes | Credit amount, zero when debit side used. |

### `InternalCheckAttestation`

Source: `specs/feature/039-internal-checks/data-model.md`

Description: Evidence that a human performed an internal control cadence review.

Common columns: Primary Key, Audit Columns, Soft Delete Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `ControlRef` | `nvarchar(10)` | Yes | Control reference, for example AR-04. |
| `LegalEntityId` | `int` | Yes | Reviewed legal entity. |
| `AttestedAtUtc` | `datetime2` | Yes | Attestation timestamp. |
| `AttestedBy` | `nvarchar(256)` | Yes | Attesting principal. |
| `Note` | `nvarchar(500)` | No | Optional note. |

### `RecurringApTemplate`

Source: `specs/feature/040-recurring-ap/data-model.md`

Description: Recurring AP master template.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `LegalEntityId` | `int` | Yes | Owning/posting entity. |
| `Name` | `nvarchar(200)` | Yes | Template name. |
| `CounterpartyName` | `nvarchar(200)` | Yes | Descriptive counterparty name. |
| `CounterpartyType` | `int enum` | Yes | Vendor, government, insurer, intercompany, or other. |
| `Cadence` | `int enum` | Yes | Monthly, quarterly, or annual. |
| `CurrencyCode` | `nchar(3)` | Yes | Posting currency. |
| `AmountMode` | `int enum` | Yes | Fixed or variable. |
| `FixedAmount` | `decimal(18,2)` | Conditional | Required when amount mode is Fixed. |
| `DebitAccountId` | `int` | Yes | Debit account. |
| `CreditAccountId` | `int` | Yes | Credit account. |
| `DivisionId` | `int` | No | Optional division dimension. |
| `DepartmentId` | `int` | No | Optional department dimension. |
| `SettlementBankAccountId` | `int` | No | Optional bank account for forecast attribution. |
| `IsActive` | `bit` | Yes | Active/deactivated flag. |

### `RecurringApTemplatePost`

Source: `specs/feature/040-recurring-ap/data-model.md`

Description: Immutable history bridge from recurring AP template/period to posted journal.

Common columns: Primary Key, Audit Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `RecurringApTemplateId` | `int` | Yes | FK to template. |
| `LegalEntityId` | `int` | Yes | Denormalized entity scope. |
| `PeriodKey` | `nvarchar(10)` | Yes | Period key such as 2026-07 or 2026-Q3. |
| `PostingDate` | `date` | Yes | Journal date. |
| `JournalId` | `int` | No | Journal created by the post; nullable during in-flight claim. |
| `Amount` | `decimal(18,2)` | Yes | Transaction amount. |
| `CurrencyCode` | `nchar(3)` | Yes | Transaction currency. |
| `FunctionalAmount` | `decimal(18,2)` | Yes | Functional equivalent. |
| `FunctionalCurrencyCode` | `nchar(3)` | Yes | Entity functional currency. |
| `ExchangeRate` | `decimal(18,6)` | Yes | Rate used. |

### `BudgetLine`

Source: `specs/feature/041-budget/data-model.md`

Description: Monthly budget values by legal entity, leaf account, and fiscal year.

Common columns: Primary Key, Audit Columns, Soft Delete Columns, Concurrency Column.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `LegalEntityId` | `int` | Yes | Owning legal entity. |
| `AccountId` | `int` | Yes | Postable leaf account. |
| `FiscalYear` | `int` | Yes | Budget fiscal year. |
| `M01` | `decimal(18,2)` | Yes | Month 1 budget amount. |
| `M02` | `decimal(18,2)` | Yes | Month 2 budget amount. |
| `M03` | `decimal(18,2)` | Yes | Month 3 budget amount. |
| `M04` | `decimal(18,2)` | Yes | Month 4 budget amount. |
| `M05` | `decimal(18,2)` | Yes | Month 5 budget amount. |
| `M06` | `decimal(18,2)` | Yes | Month 6 budget amount. |
| `M07` | `decimal(18,2)` | Yes | Month 7 budget amount. |
| `M08` | `decimal(18,2)` | Yes | Month 8 budget amount. |
| `M09` | `decimal(18,2)` | Yes | Month 9 budget amount. |
| `M10` | `decimal(18,2)` | Yes | Month 10 budget amount. |
| `M11` | `decimal(18,2)` | Yes | Month 11 budget amount. |
| `M12` | `decimal(18,2)` | Yes | Month 12 budget amount. |

### `NotificationRule`

Source: `specs/feature/045-notification-alerts/data-model.md`

Description: Governed notification/alert rule.

Common columns: Primary Key, Audit Columns, Soft Delete Columns.

| Column | Type | Mandatory? | Description |
|---|---:|---:|---|
| `Name` | `nvarchar(120)` | Yes | Rule display name. |
| `Category` | `nvarchar(20)` | Yes | Period, approval, sync, data, or statutory. |
| `TriggerType` | `nvarchar(40)` | Yes | Trigger catalog type. |
| `ParamsJson` | `nvarchar(max)` | Yes | Trigger parameters as typed JSON. |
| `Severity` | `nvarchar(10)` | Yes | Error, warn, or info. |
| `VisibleToRoles` | `nvarchar(100)` | Yes | CSV of role keys. |
| `Channels` | `nvarchar(100)` | Yes | Notification channels; in-app is required. |
| `IsEnabled` | `bit` | Yes | Disabled rules never evaluate. |
| `IsSeeded` | `bit` | Yes | True for default seed rules. |
| `LastFiredUtc` | `datetime2` | No | Last time this rule produced a notification. |

## Existing Tables With Additive Columns Only

These columns are already listed on their owning table above, but are repeated here for migration tracking.

| Feature | Existing table | Added column | Type | Mandatory? | Description |
|---|---|---|---:|---:|---|
| 012 | `JournalAuditLog` | `LegalEntityId` | `int` | No | Entity targeted by posting/reversal action. |
| 012 | `JournalAuditLog` | `Result` | `int enum` | Yes | Success or failure. |
| 012 | `JournalAuditLog` | `FailureCode` | `nvarchar(64)` | No | Failure reason code. |
| 012 | `JournalAuditLog` | `ReversalJournalId` | `int` | No | Created reversal journal id. |
| 013 | `GeneralLedgerEntry` | `SalesTypeCode` | `string` | No | Sales-type filter code. |
| 013 | `GeneralLedgerEntry` | `SalesTypeLabel` | `string` | No | Sales-type display label. |
| 013 | `GeneralLedgerEntry` | `IsOpeningBalance` | `bit` | Yes | Opening-balance GL flag. |
| 021C | `AccrualItem` | `ConfirmedByPodDocumentId` | `int` | No | DMS POD that confirmed/released accrual. |
| 022 | `Customer` | Multiple CAPSUL mirror fields | mixed | No | See `Customer` table section. |
| 030 | `ArOpenItem` | `SettledAmount` | `decimal(23,6)` | Yes | Cash-settled amount from AR receipts. |
| 032 | `PomsPurchaseDocument` | `SettledAmount` | `decimal(23,6)` | Yes | Cash-settled amount from AP supplier payments. |
| 033 | `JournalLine` | `FunctionalDebitAmount` | `decimal(23,6)` | No | Functional debit override for FX settlement. |
| 033 | `JournalLine` | `FunctionalCreditAmount` | `decimal(23,6)` | No | Functional credit override for FX settlement. |
| 033 | `PomsAccountMapping` | `RealisedFxAccountId` | `int` | No | AP realized FX account. |
| 033 | `SomsAccountMapping` | `RealisedFxAccountId` | `int` | No | AR realized FX account. |
| 033 | `SupplierPayment` | `SettlementRate` | `decimal(18,6)` | No | Payment-date FX rate. |
| 033 | `SupplierPayment` | `RealisedFxAmount` | `decimal(23,6)` | No | Signed realized FX amount. |
| 033 | `CustomerReceipt` | `SettlementRate` | `decimal(18,6)` | No | Receipt-date FX rate. |
| 033 | `CustomerReceipt` | `RealisedFxAmount` | `decimal(23,6)` | No | Signed realized FX amount. |
| 036 | `SomsAccountMapping` | `UnrealisedFxAccountId` | `int` | No | AR unrealized FX account. |
| 036 | `PomsAccountMapping` | `UnrealisedFxAccountId` | `int` | No | AP unrealized FX account. |
| 037 | `Journal` | `IsOpeningBalance` | `bit` | Yes | Opening-balance journal flag. |

## Features With No New Persisted Tables

The following data-model specs are read-only projections, seed-only changes, or application transport models with no new persisted business tables: `001-solution-scaffold`, `004-azure-ad-authentication-and-authorization`, `013-general-ledger`, `014-trial-balance`, `015-profit-and-loss-statement`, `016-balance-sheet-statement`, `017-cashflow-statement`, `023-global-legal-entity-selector`, `024-country-consolidated-scope-transport`, `025-pl-country-consolidated-rollup`, `026-tb-country-consolidated-rollup`, `027-tb-rollup-both-currency`, `028-accounts-receivable`, `031-accounts-payable`, `034-cash-book`, `038-weekly-forecast`, `042-inventory-overview`, `043-ar-statement-of-account`, `044-integration-test-run`, and `046-dashboard`.
