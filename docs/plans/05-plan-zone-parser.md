# 05 Plan: Zone File Parser and Validation Command

## Stacked PR Metadata

- Plan identifier: `05`
- Branch: `stack-05-zone-parser`
- Base branch: `stack-04-zone-record-model`
- PR title: `05: Parse and validate standard zone files`
- PR description must reference: `Plan 05 - Zone File Parser and Validation Command`

## Scope

- Add `dns-zonefile`.
- Add `dry-monads` and use `Dry::Monads::Result` for parser and validation service results.
- Add parser adapter at the boundary.
- Add `dme zone validate FILE`.
- Convert parser output immediately into internal zone records.

## Implementation Notes

- `aeden/dns-zonefile` is sufficient for v1 parsing of downloaded or standard RFC-style zone files.
- Parser and validation workflows should return `Success(value)` / `Failure(errors)` rather than raising for expected user-input errors.
- Do not leak `DNS::Zonefile::*` classes beyond the adapter.
- Unsupported syntax should produce actionable validation errors.
- `HTTPRED` is not represented in standard zone files and does not need parser support in v1.

## RSpec Requirements

- Add parser unit specs with fixture zone files.
- Add Aruba specs for:
  - valid zone file
  - invalid zone file
  - unsupported record type
- Use `subject(:result) { described_class.new(...).call }` for service specs.
- Use `its(:records) { ... }`, `its(:errors) { ... }`, and one-liner `it { is_expected.to be_success }` style where available.

## Acceptance Criteria

- `dme zone validate FILE` succeeds for standard fixture zone files.
- Parser adapter returns internal records only.
- `bundle exec rspec` passes.
