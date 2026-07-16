# 09 Plan: Safe Zone Apply Command

## Stacked PR Metadata

- Plan identifier: `09`
- Branch: `stack-09-zone-apply`
- Base branch: `stack-08-zone-diff-plan`
- PR title: `09: Apply zone plans safely`
- PR description must reference: `Plan 09 - Safe Zone Apply Command`

## Scope

- Add `dme zone apply FILE`.
- Reuse the same planner used by `zone plan`.
- Execute creates and updates through the existing API client.
- Keep deletes opt-in.

## Safety Rules

- Never delete by default.
- Never delete SOA records.
- Never delete apex NS records in v1.
- Require confirmation unless `--yes` is provided.
- Fail before applying if parsing or validation fails.
- Report partial failures clearly.

## Live Integration Note

Opt-in live specs may use:

- Domain: `isdue.today`
- DNS Made Easy domain ID: `8218117`

Live specs must only mutate predictable test records such as `_dnsmadeeasy-test.isdue.today` and must clean them up.

## RSpec Requirements

- Add unit specs for executor behavior.
- Add Aruba specs for confirmation flow.
- Add specs for `--yes`.
- Add specs for delete refusal without `--delete`.
- Add optional gated live integration specs for create/update/delete of test-owned records.
- Use `subject(:result) { described_class.new(...).call }`.
- Use `its(:applied_actions)`, `its(:failed_actions)`, and concise one-liners where useful.

## Acceptance Criteria

- Apply executes the current plan.
- Apply refuses destructive operations unless explicitly allowed.
- Default test suite never touches live DNS.
- `bundle exec rspec` passes.
