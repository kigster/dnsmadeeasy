# 01 Plan: Ruby 4 Baseline

## Stacked PR Metadata

- Plan identifier: `01`
- Branch: `stack-01-ruby4-baseline`
- Base branch: `master`
- PR title: `01: Establish Ruby 4 baseline for dnsmadeeasy 1.0`
- PR description must reference: `Plan 01 - Ruby 4 Baseline`

## Scope

- Drop Ruby 2 support.
- Add Ruby 4 support.
- Bump `DnsMadeEasy::VERSION` to `1.0.0`.
- Update gem metadata and CI Ruby version.
- Add the first dependency baseline needed by later PRs only when it is directly required here.
- Preserve current library behavior.

## Implementation Notes

- Prefer Ruby 4 only with `spec.required_ruby_version = '~> 4.0'` unless we decide public compatibility requires Ruby 3.2+.
- Add `tsort` explicitly to quiet the Ruby 4.1 default-gem warning from `sym`.
- Update GitHub Actions from Ruby 2.7 and old `actions/setup-ruby` usage to current `ruby/setup-ruby`.

## RSpec Requirements

- Update or add specs proving `DnsMadeEasy::VERSION == '1.0.0'`.
- Keep the Ruby 4 keyword-argument compatibility specs passing.
- Use modern nested `describe`/`context` blocks with block-local `subject`.
- Use concise one-liner expectations, including `it { ... }` and `its(:property) { ... }` where readable.

## Acceptance Criteria

- `bundle exec rspec` passes on Ruby 4.
- CI config targets Ruby 4.
- The gem metadata no longer claims Ruby 2 support.
- No live DNS Made Easy calls are made.
