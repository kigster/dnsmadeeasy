# 02 Plan: dry-cli Launcher and Aruba Test Harness

## Stacked PR Metadata

- Plan identifier: `02`
- Branch: `stack-02-dry-cli-launcher`
- Base branch: `stack-01-ruby4-baseline`
- PR title: `02: Introduce dry-cli launcher and Aruba harness`
- PR description must reference: `Plan 02 - dry-cli Launcher and Aruba Test Harness`

## Scope

- Add `dry-cli`.
- Include `tty-spinner` as a runtime dependency for later threaded zone export/apply progress reporting.
- Add a `DnsMadeEasy::CLI::Commands` registry.
- Add `DnsMadeEasy::CLI::Launcher`.
- Add `DnsMadeEasy::CLI::Commands::Base`.
- Add a `version` command.
- Configure Aruba for in-process CLI tests.
- Update `exe/dme` to call the launcher.
- Keep `DnsMadeEasy::Runner` temporarily for migration reference.

## Implementation Notes

- Follow the `../githuh` launcher shape, but keep the implementation smaller.
- All command output must use injected `stdout` and `stderr`.
- Do not put business logic in the launcher.
- Do not make zone commands in this PR.

## RSpec Requirements

- Add launcher specs using direct `StringIO` streams.
- Add Aruba specs for:
  - `dme --help`
  - `dme version`
- Use `subject(:launcher)` or block-local `subject { output }` per describe block.
- Use `its(:stdout)` style only where the object exposes a clear property; otherwise use `it { is_expected.to ... }`.

## Acceptance Criteria

- `dme --help` is handled through dry-cli.
- `dme version` prints `1.0.0`.
- Aruba runs the CLI in-process.
- Existing library specs still pass.
