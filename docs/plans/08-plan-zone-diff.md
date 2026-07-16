# 08 Plan: Zone Diff Engine and Plan Command

## Stacked PR Metadata

- Plan identifier: `08`
- Branch: `stack-08-zone-diff-plan`
- Base branch: `stack-07-zone-export`
- PR title: `08: Add zone diff engine and plan command`
- PR description must reference: `Plan 08 - Zone Diff Engine and Plan Command`

## Scope

- Add diff engine.
- Add execution plan objects.
- Add text and JSON plan renderers.
- Add `dme zone plan FILE`.

## Implementation Notes

- Default behavior:
  - create missing records
  - update modified records only when unambiguous
  - never delete records
- Multiple records with the same owner/type must be modeled as record sets.
- Prefer conservative create/delete reporting over unsafe update matching.
- Ambiguous changes should be reported as requiring manual intervention.

## RSpec Requirements

- Add unit specs for create, update, no-op, skipped delete, and ambiguous cases.
- Add golden-file specs for text plan output.
- Add JSON output specs.
- Add Aruba specs for `dme zone plan FILE` with mocked remote state.
- Use `subject(:plan) { described_class.new(...).call }`.
- Use `its(:creates)`, `its(:updates)`, `its(:skipped_deletes)`, and one-liner expectations.

## Acceptance Criteria

- Plan output is deterministic.
- Deletes are skipped by default.
- Ambiguous changes are not applied silently.
- `bundle exec rspec` passes.
