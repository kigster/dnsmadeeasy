# 04 Plan: Typed Zone Record Model

## Stacked PR Metadata

- Plan identifier: `04`
- Branch: `stack-04-zone-record-model`
- Base branch: `stack-03-account-command`
- PR title: `04: Add typed zone record domain model`
- PR description must reference: `Plan 04 - Typed Zone Record Model`

## Scope

- Add `dry-types`.
- Add `dry-struct`.
- Define internal provider-neutral zone record objects.
- Define record-set and sorting behavior.
- Keep provider IDs out of serializable zone records.

## Implementation Notes

- Create `DnsMadeEasy::Types`.
- Support initial record types:
  - `A`
  - `AAAA`
  - `CNAME`
  - `MX`
  - `NS`
  - `PTR`
  - `SPF`
  - `SRV`
  - `TXT`
- Represent DNS Made Easy metadata separately from record equality.
- Build deterministic sort keys now because serializer and diff will depend on them.

## RSpec Requirements

- Add specs for valid construction.
- Add specs for invalid record type, TTL, and required attributes.
- Add specs for deterministic sorting.
- Add specs proving provider metadata is separate from record equality.
- Use `subject(:record) { described_class.new(...) }`.
- Use `its(:owner) { ... }`, `its(:type) { ... }`, and `it { is_expected.to ... }` one-liners where useful.

## Acceptance Criteria

- Zone records are immutable typed value objects.
- Invalid input fails before parser/diff/apply logic can use it.
- `bundle exec rspec` passes.
