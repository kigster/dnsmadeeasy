# 10 Plan: Documentation, Migration Notes, and Cleanup

## Stacked PR Metadata

- Plan identifier: `10`
- Branch: `stack-10-docs-cleanup`
- Base branch: `stack-09-zone-apply`
- PR title: `10: Document dnsmadeeasy 1.0 CLI and zone workflow`
- PR description must reference: `Plan 10 - Documentation, Migration Notes, and Cleanup`

## Scope

- Update README examples for the new command tree.
- Document Ruby 4 and version 1.0 breaking changes.
- Document the zone-file workflow.
- Remove deprecated runner leftovers if still present.
- Ensure command examples are represented by smoke specs where practical.

## Documentation Requirements

Include examples for:

```text
dme account domains
dme account records_for example.com
dme zone export example.com > example.com.zone
dme zone validate example.com.zone
dme zone fmt example.com.zone
dme zone plan example.com.zone
dme zone apply example.com.zone --yes
```

Document that `HTTPRED` is omitted from standard zone exports in v1, with warnings.

Document the live integration test domain:

- Domain: `isdue.today`
- DNS Made Easy domain ID: `8218117`

## RSpec Requirements

- Add or update CLI smoke specs for README command examples where practical.
- Add specs for migration messages if old commands are intentionally unsupported.
- Keep specs in the modern style:
  - nested `describe`/`context`
  - block-local `subject`
  - concise `it { ... }`
  - `its(:property) { ... }` where it improves readability

## Acceptance Criteria

- README accurately reflects the 1.0 CLI.
- Old docs for root-level operations are removed or marked as legacy.
- All specs pass.
- The stacked PR series is ready to merge from `01` through `10`.
