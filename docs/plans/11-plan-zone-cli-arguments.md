# 11 Plan: Consistent Zone CLI Arguments (and the Trailing-Dot 404)

## Stacked PR Metadata

- Plan identifier: `11`
- Branch: `11-zone-cli-arguments`
- Base branch: `master`
- PR title: `11: Make domain a positional argument across zone commands`
- PR description must reference: `Plan 11 - Consistent Zone CLI Arguments`

## The Bug That Started This

Found live, while writing the kig.re blog post announcing 1.0.1:

```bash
$ dmez zone export kig.re --output=kig.re.zone   # works
$ dmez zone plan kig.re.zone                     # 404 "Not Found"
$ dmez zone plan kig.re.zone --domain=kig.re     # works
```

`Plan#call` and `Apply#build_plan_context` fall back to the parsed zone's
origin when `--domain` is absent:

```ruby
plan_domain = domain || desired_result.value!.origin
```

The parser returns the origin exactly as written in the file: `kig.re.`,
with the RFC-mandated trailing dot. That FQDN goes straight into
`records_for("kig.re.")`, the API has no such domain, 404.

## The Design Decision

The deeper problem is inconsistency, not the dot. Today:

- `dmez zone export DOMAIN` — domain is a positional argument
- `dmez zone plan FILE --domain=NAME` — domain is an option
- `dmez zone apply FILE --domain=NAME` — domain is an option

Decision (Konstantin): **domain is consistently an argument, never an
option.** Zone files are provided by flags unless one is required for the
command; a required file becomes a required argument following the domain.

Applied to the command tree:

| Command | New shape | Change |
| ------- | --------- | ------ |
| `zone export` | `dmez zone export DOMAIN [--output=FILE]` | none (already correct; output is optional, stays a flag, defaults to stdout) |
| `zone plan` | `dmez zone plan DOMAIN FILE` | file was the only argument; domain was a flag |
| `zone apply` | `dmez zone apply DOMAIN FILE [modes]` | same |
| `zone validate` | `dmez zone validate FILE` | none (no provider involved, no domain to speak of) |
| `zone fmt` | `dmez zone fmt FILE` | none |

With `domain` required, origin inference is deleted rather than fixed. The
bug becomes structurally impossible: there is nothing left to infer.

## $ORIGIN Becomes a Cross-Check

Deleting the inference does not mean ignoring `$ORIGIN`. Plan and apply now
verify that the zone file agrees with the domain argument, before any API
call is made:

- Normalize both sides: strip one trailing dot, compare case-insensitively.
  (`kig.re` == `kig.re.` == `KIG.RE.`)
- If the file has an `$ORIGIN` and it disagrees with the domain argument,
  fail fast with both values shown. Diffing `foo.com` against
  `bar.com.zone` should be an error, not a surprise apply.
- A zone file without `$ORIGIN` skips the check.

This converts yesterday's bug into a safety feature.

## Swapped-Argument Detection

`dmez zone plan valid.zone example.com` is the muscle-memory mistake the
new argument order invites. Two cheap guards:

- When the zone file path does not exist, say so plainly
  (`Zone file not found: example.com`) instead of an unhandled `Errno::ENOENT`.
- When, additionally, the *domain* argument names an existing file, append:
  `It looks like the arguments are swapped. Usage: dmez zone plan DOMAIN FILE`.

## Out of Scope

- `dme account` argument shapes.
- `validate`/`fmt` error-handling polish beyond what exists.
- Version bump: this is a breaking CLI change one day after 1.0.1 shipped
  (16 downloads). Recommend releasing as **1.1.0** with the README calling
  out the new shapes; the maintainer bumps the version at release time.

## RSpec Requirements

Update `spec/lib/dns_made_easy/cli/zone_aruba_spec.rb`:

- Rewrite every `zone plan` / `zone apply` invocation to
  `dme zone plan example.com valid.zone ...` (domain first, file second).
- Add: plan with origin `example.com.` (trailing dot in file) and domain
  argument `example.com` succeeds — the normalization test.
- Add: plan with a mismatched origin fails, names both values, makes no
  API call.
- Add: plan with swapped arguments fails with the swap hint.
- Add: plan with a missing zone file fails with `Zone file not found`.
- Keep specs in the modern style: nested `describe`/`context`, block-local
  `subject`, concise `it { ... }`, `its(:property) { ... }` where it reads
  better.

## Acceptance Criteria

- `dmez zone plan kig.re kig.re.zone` round-trips against production with
  `No changes.` (verified live, read-only).
- The 1.0.1 failure mode (`zone plan FILE` → 404) can no longer be
  expressed: the CLI rejects the invocation with a usage error.
- Mismatched `$ORIGIN` vs domain argument fails before any API request.
- README zone examples reflect the new shapes.
- Full spec suite passes; rubocop clean.
