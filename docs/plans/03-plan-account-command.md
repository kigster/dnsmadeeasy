# 03 Plan: Account Command for Existing API Operations

## Stacked PR Metadata

- Plan identifier: `03`
- Branch: `stack-03-account-command`
- Base branch: `stack-02-dry-cli-launcher`
- PR title: `03: Move existing API operations under account command`
- PR description must reference: `Plan 03 - Account Command for Existing API Operations`

## Scope

- Add `dme account <operation> [args...]`.
- Move existing CLI behavior from `DnsMadeEasy::Runner` into a dry-cli command.
- Preserve output formats where practical.
- Validate operation names using `DnsMadeEasy::Api::Client.public_operations`.
- Replace runner specs with Aruba command specs.

## Implementation Notes

- Treat `<operation>` as an argument to one `Account` command.
- Do not generate one dry-cli class per API method unless the single-command design becomes unworkable.
- For version 1.0, prefer a clear migration hint for old root operations like `dme domains`.
- Preserve method arity diagnostics where reasonable.

## RSpec Requirements

- Add Aruba specs for:
  - `dme account operations`
  - `dme account domains`
  - `dme account records_for example.com`
  - invalid account operation
  - invalid arity where current behavior provides a useful message
- Mock `DnsMadeEasy.client`; do not hit the network.
- Use nested `describe '#call'`, `context 'with valid operation'`, and `context 'with invalid operation'`.
- Use `subject { output }` for CLI output examples and `its(:exit_status)` if command objects expose it.

## Acceptance Criteria

- Existing API operations are reachable through `dme account`.
- Old `Runner` can be deleted or made a thin deprecated wrapper.
- `bundle exec rspec` passes.
- No live DNS Made Easy calls are made.
