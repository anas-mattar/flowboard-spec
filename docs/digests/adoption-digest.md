# adoption pack — law digest (GENERATED)

<!-- GENERATED FILE — do not edit. Regenerate: pwsh -File scripts/build-digests.ps1
     Non-authoritative: for orientation only. The source documents prevail (constitution
     II is unchanged); read the full document before acting on its area. -->

- update-kit.ps1 runs from a kit clone with -Target: verbatim files copied, surgical only reported, never written. (`adoption/updating.md`)
- generated-class paths (docs/digests/*-digest.md) never flow down — each project generates digests from its own law. (`adoption/updating.md`)
- The surgical report is delivered once — handle it in the session that produced it; the record advances to kit HEAD. (`adoption/updating.md`)
- Constitution amendments are re-expressed, never copied: your own version bump, your own SYNC IMPACT, citation sweep. (`adoption/updating.md`)
- Verify demoted content lands in your project before deleting the principle — nowhere to land means a rule is lost. (`adoption/updating.md`)
- Human approval adopts an amendment — the update script only delivers the report, never amends your constitution. (`adoption/updating.md`)
- Surgical files carry project-filled content: re-apply by hand only what applies — an ordinary governance edit. (`adoption/updating.md`)
- verify-kit.ps1 is the adoption doctor: read-only, runs at init end, update end, and in adopted-project CI. (`adoption/updating.md`)
- kit-adoption.json is project-owned: every declared tier needs an instantiated rulebook; gateProof is your attestation. (`adoption/updating.md`)
