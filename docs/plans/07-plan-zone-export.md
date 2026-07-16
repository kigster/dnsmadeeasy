# 07 Plan: Remote Adapter and Zone Export

## Stacked PR Metadata

- Plan identifier: `07`
- Branch: `stack-07-zone-export`
- Base branch: `stack-06-zone-formatter`
- PR title: `07: Export DNS Made Easy records as canonical zone files`
- PR description must reference: `Plan 07 - Remote Adapter and Zone Export`

## Scope

- Add remote record adapter.
- Add `dme zone export DOMAIN`.
- Convert DNS Made Easy API responses to internal zone records.
- Serialize remote records through the canonical serializer.

## Implementation Notes

- Use the existing API client as the provider boundary.
- Keep provider IDs separate from exported records.
- Omit `HTTPRED` from exports.
- Emit warnings listing omitted `HTTPRED` records.
- Write zone text to stdout by default.
- Write warnings to stderr so stdout remains pipe-safe.
- When export requires multiple independent provider calls, split work into bounded worker-thread chunks.
- Use one `TTY::Spinner` per active worker/chunk for interactive progress.
- Use `TTY::Spinner::Multi` for concurrent thread progress:
  https://github.com/piotrmurach/tty-spinner#5-ttyspinnermulti-api
- Collect worker results and render final zone output deterministically after all workers finish.
- Inject a fake/no-op spinner in specs so output remains stable.

## Live Integration Note

Opt-in live specs may use:

- Domain: `isdue.today`
- DNS Made Easy domain ID: `8218117`

Live specs must be gated by `DNSMADEEASY_LIVE_TESTS=1` or equivalent and must only touch test-owned records.

## RSpec Requirements

- Add unit specs for remote adapter conversion.
- Add Aruba specs for export using a mocked client.
- Add specs proving `HTTPRED` is omitted and warning text is emitted.
- Add specs for chunked parallel execution with deterministic result ordering.
- Add specs for failed worker chunks and aggregated error reporting.
- Add optional live integration specs marked/skipped unless explicitly enabled.
- Use `subject(:records)`, `subject(:output)`, and `its(:warnings)` where the object model supports it.

## Acceptance Criteria

- `dme zone export example.com` produces deterministic zone output with mocked data.
- Provider metadata is not serialized.
- Independent provider reads can run concurrently with bounded worker threads.
- Progress is displayed with `TTY::Spinner` during interactive export work.
- `bundle exec rspec` passes without live credentials.
