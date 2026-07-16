# 06 Plan: Canonical Zone Serializer and Formatter

## Stacked PR Metadata

- Plan identifier: `06`
- Branch: `stack-06-zone-formatter`
- Base branch: `stack-05-zone-parser`
- PR title: `06: Add canonical zone serializer and formatter`
- PR description must reference: `Plan 06 - Canonical Zone Serializer and Formatter`

## Scope

- Add canonical serializer.
- Add `dme zone fmt FILE`.
- Optionally add `dme zone format FILE` as an alias.
- Normalize whitespace and ordering.

## Normalized Output Rules

- one zone per file
- explicit owner on every record
- `$ORIGIN`
- `$TTL`
- `@` for zone apex
- deterministic ordering
- normalized, aligned whitespace
- provider-managed SOA omitted
- apex NS records omitted by default
- delegated NS records preserved

## RSpec Requirements

- Add golden-file specs for formatter output.
- Add idempotency spec: parse, serialize, parse, serialize produces byte-identical output.
- Add specs for apex NS omission and delegated NS preservation.
- Use `subject(:serialized_zone) { described_class.new(...).to_s }`.
- Use one-liners for exact matches and property checks where readable.

## Acceptance Criteria

- `dme zone fmt FILE` emits canonical zone text.
- Already formatted files remain byte-identical.
- `bundle exec rspec` passes.
