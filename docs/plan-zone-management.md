# Plan: Ruby 4, dry-cli, and Zone File Management

## Context

This gem is currently a compact Ruby API client and CLI for DNS Made Easy. The CLI is implemented by `DnsMadeEasy::Runner`, which forwards arbitrary operation names directly to `DnsMadeEasy.client`.

The requested direction is a major-version refactor:

- drop Ruby 2 support
- support Ruby 4
- bump the gem to `1.0.0`
- replace the current CLI runner with `dry-cli`
- add stronger validation using focused dry-rb gems
- preserve existing API operations under an `account` command namespace
- add declarative zone-file workflows under a new `zone` command namespace

The zone-management specification lives in `docs/spec-zone-management.md`.

## Source Material Reviewed

- Local current implementation:
  - `lib/dnsmadeeasy/api/client.rb`
  - `lib/dnsmadeeasy/runner.rb`
  - `lib/dnsmadeeasy/credentials*.rb`
  - `exe/dme`
  - current specs
- Local reference project:
  - `../githuh/lib/githuh/cli/launcher.rb`
  - `../githuh/lib/githuh/cli/commands/base.rb`
  - `../githuh/spec/support/aruba_helper.rb`
  - `../githuh/spec/spec_helper.rb`
- External references:
  - dry-rb/Hanakai overview and dry CLI/type/validation docs index
  - Konstantin Gredeskoul's CLI + Aruba article
  - `aeden/dns-zonefile` README

## Design Principles

1. Keep `DnsMadeEasy::Api::Client` as the provider boundary.
2. Treat `dry-cli` as command dispatch only, not as business logic.
3. Introduce typed value objects before introducing diff/apply logic.
4. Make every command testable in process through Aruba.
5. Keep zone parsing isolated behind an adapter so `DNS::Zonefile::*` classes do not leak through the implementation.
6. Make `plan` the safety gate for `apply`.
7. Keep deletion opt-in and out of the first implementation unless explicitly requested.
8. Use `tty-spinner` for long-running groups of independent provider operations.

## Parallel Provider Operations

The gem includes `tty-spinner` for visual progress during multi-step provider work. Zone workflows should split independent API work into bounded chunks, execute those chunks with worker threads, and attach one `TTY::Spinner` to each active worker or chunk.

Use `TTY::Spinner::Multi` for managing multiple concurrent thread progress indicators:
https://github.com/piotrmurach/tty-spinner#5-ttyspinnermulti-api

Rules:

- Use bounded concurrency; do not start one unbounded thread per DNS record.
- Only parallelize independent API calls.
- Preserve deterministic final output by collecting results and sorting/rendering after workers finish.
- Keep `plan` rendering deterministic and mostly non-animated; spinners belong to long-running `export` and `apply` execution paths.
- Provide a no-op or fake spinner in specs so test output is stable.
- Aggregate worker errors and report which chunk/action failed.
- Avoid parallel delete behavior until destructive operations are explicitly enabled and tested.

## Zone File Compatibility and Normalization

The `aeden/dns-zonefile` gem is sufficient for version 1 parsing. We are comfortable using it to parse downloaded or standard RFC-style zone files, and we accept its current limitations because this feature does not need to preserve every possible BIND extension or provider-specific behavior.

Export output is not intended to round-trip arbitrary zone-file formatting. Instead, `dme zone export` and `dme zone fmt` produce a normalized, readable, deterministic zone file.

Normalized zone characteristics:

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

Example:

```dns
$ORIGIN example.com.
$TTL 300

@       IN A       203.0.113.10
www     IN CNAME   @

@       IN MX      10 mail.example.com.

@       IN TXT     "v=spf1 include:_spf.google.com ~all"
```

`HTTPRED` cannot be represented in a standard RFC zone file.

Version 1 behavior:

- omit `HTTPRED` records from exports
- emit a warning listing omitted records

Future versions may support provider-specific comment directives for records such as `HTTPRED`, but version 1 should keep the exported zone file standard and predictable.

## Phase 0: Baseline and Version Policy

### Objective

Establish a clean Ruby 4 baseline before changing CLI architecture.

### Work

1. Decide the exact supported Ruby range.
   - Recommended: `spec.required_ruby_version = '>= 3.2', '< 4.1'` initially.
   - If the goal is Ruby 4 only, use `~> 4.0`, matching the `githuh` reference.
   - Do not keep Ruby 2 compatibility constraints.
2. Bump `DnsMadeEasy::VERSION` from `0.4.0` to `1.0.0`.
3. Update the GitHub Actions workflow.
   - Replace Ruby 2.7 with Ruby 4.0.
   - Use current `ruby/setup-ruby`.
   - Enable Bundler cache.
4. Add or update dependencies.
   - Runtime:
     - `dry-cli`
     - `dry-struct`
     - `dry-types`
     - `dry-validation`
     - `dns-zonefile`
     - `tsort`, because `sym` warns that `tsort` will no longer be bundled by default in Ruby 4.1
     - `tty-spinner`
   - Development:
     - `aruba`
5. Run the current suite.

### Acceptance Criteria

- `bundle exec rspec` passes on Ruby 4.
- CI targets Ruby 4.
- Version reports `1.0.0`.
- Ruby 2 support is explicitly removed from gem metadata and CI.

## Phase 1: Introduce dry-cli Shell Without Changing Behavior

### Objective

Add a dry-cli launcher and command registry while preserving the current user-visible behavior as much as possible.

### Proposed Files

```text
lib/dnsmadeeasy/cli/launcher.rb
lib/dnsmadeeasy/cli/commands/base.rb
lib/dnsmadeeasy/cli/commands/version.rb
lib/dnsmadeeasy/cli/commands/account.rb
spec/support/aruba_helper.rb
spec/lib/dnsmadeeasy/cli/launcher_spec.rb
spec/lib/dnsmadeeasy/cli/commands/version_spec.rb
spec/lib/dnsmadeeasy/cli/commands/account_spec.rb
```

### Work

1. Add `DnsMadeEasy::CLI::Commands` as a `Dry::CLI::Registry`.
2. Add `DnsMadeEasy::CLI::Launcher`.
   - Accept `argv`, `stdin`, `stdout`, `stderr`, and optional `kernel`.
   - Send all command output through injected streams.
   - Do not call raw `STDOUT`, `STDERR`, or `Kernel.exit` from command classes.
3. Update `exe/dme` to instantiate the launcher:

```ruby
DnsMadeEasy::CLI::Launcher.new(ARGV.dup).execute!
```

4. Add `Base < Dry::CLI::Command`.
   - Centralize authentication setup.
   - Centralize output format helpers.
   - Centralize client creation.
   - Support common options:
     - `--credentials-file`
     - `--account`
     - `--sandbox`
     - `--format=json|json_pretty|yaml|pp`
     - `--verbose`
5. Add Aruba in-process test setup based on `../githuh`.
6. Keep `DnsMadeEasy::Runner` temporarily.
   - Mark it internal/deprecated.
   - Use it as an implementation reference while migrating commands.

### Acceptance Criteria

- `dme --help` is handled by dry-cli.
- `dme version` prints `1.0.0`.
- Aruba can run `dme` in-process.
- Existing library specs still pass.

## Phase 2: Move Existing API Operations Under `account`

### Objective

Create the compatibility namespace for existing API operations:

```text
dme account <operation> [args...] [--format=...]
```

Examples:

```text
dme account domains
dme account domain example.com
dme account records_for example.com
dme account create_a_record example.com www 203.0.113.10
```

The user proposal used `dme account create_record A ...`; the existing API shape is `create_record DOMAIN NAME TYPE VALUE`. Keep the existing method shape first. Add friendlier aliases later if needed.

### Work

1. Implement `DnsMadeEasy::CLI::Commands::Account`.
2. Use `DnsMadeEasy::Api::Client.public_operations` to validate allowed operation names.
3. Treat the operation name as an argument, not a generated class per API method.
   - This minimizes refactoring.
   - It avoids generating dozens of tiny command classes with no separate behavior.
4. Forward remaining CLI arguments to the client method.
5. Preserve existing output formats.
6. Preserve useful failure behavior:
   - unknown operation: print valid operations
   - wrong arity: print method signature when discoverable
   - API failures: non-zero exit and readable error
7. Add a hidden or explicit compatibility shim if needed:
   - Option A: keep old `dme domains` behavior through a root fallback command.
   - Option B: make `dme domains` fail with a clear migration hint.
   - Recommended for `1.0.0`: fail with a migration hint because this is a major version.

### Acceptance Criteria

- `dme account operations` lists supported API operations.
- `dme account records_for example.com --format=json` works with a mocked client in specs.
- Existing runner specs are replaced by Aruba specs.
- `DnsMadeEasy::Runner` can be deleted after parity is covered.

## Phase 3: Add Typed Domain Model for DNS Records

### Objective

Create a provider-neutral internal record model used by export, parse, diff, plan, and apply.

### Proposed Files

```text
lib/dnsmadeeasy/types.rb
lib/dnsmadeeasy/zone/record.rb
lib/dnsmadeeasy/zone/record_key.rb
lib/dnsmadeeasy/zone/record_set.rb
lib/dnsmadeeasy/zone/domain_name.rb
lib/dnsmadeeasy/zone/ttl.rb
```

### Recommended dry-rb Usage

1. `dry-types`
   - DNS name type
   - TTL type
   - record type enum
   - non-empty string type
   - priority/weight/port integer types
2. `dry-struct`
   - immutable record value objects
   - execution plan objects
3. `dry-validation`
   - command input validation
   - zone-level validation that needs cross-field rules

### Initial Record Types

Support the standard records already represented by the existing client:

- `A`
- `AAAA`
- `CNAME`
- `MX`
- `NS`
- `PTR`
- `SPF`
- `SRV`
- `TXT`

Explicitly omit `HTTPRED` from zone files because it is provider-specific and cannot be represented in a standard zone file.

### Internal Model Sketch

```ruby
module DnsMadeEasy
  module Zone
    class Record < Dry::Struct
      attribute :owner, Types::String
      attribute :type, Types::RecordType
      attribute :value, Types::String
      attribute :ttl, Types::Integer.constrained(gteq: 0)
      attribute :priority, Types::Integer.optional
      attribute :weight, Types::Integer.optional
      attribute :port, Types::Integer.optional
    end
  end
end
```

Do not include provider IDs in `Record`. Store remote metadata separately.

### Acceptance Criteria

- Unit tests can construct valid records.
- Invalid record types fail fast.
- Record equality ignores provider metadata.
- Records are sortable deterministically.

## Phase 4: Zone File Parser Adapter

### Objective

Use `dns-zonefile` only at the parsing boundary.

The parser adapter should rely on `dns-zonefile` as sufficient for downloaded or standard zone files. Any unsupported syntax should become an explicit validation error rather than leaking parser internals into the rest of the application.

### Proposed Files

```text
lib/dnsmadeeasy/zone/parser.rb
lib/dnsmadeeasy/zone/parser_adapter.rb
lib/dnsmadeeasy/zone/parse_result.rb
spec/fixtures/zones/example.com.zone
spec/lib/dnsmadeeasy/zone/parser_spec.rb
```

### Work

1. Add `dns-zonefile`.
2. Implement a parser adapter around:

```ruby
DNS::Zonefile.load(zone_string, origin)
```

3. Convert all returned records immediately into `DnsMadeEasy::Zone::Record`.
4. Normalize:
   - empty owner to `@`
   - origin-qualified owner names
   - TTL inheritance
   - TXT quoting
   - MX priority
   - SRV priority, weight, and port
5. Reject or warn on unsupported records.
6. Treat parser exceptions as command validation failures.

### Acceptance Criteria

- `zone validate FILE` can parse a fixture zone file.
- `DNS::Zonefile::*` objects never leave the parser adapter.
- Unsupported records produce actionable validation output.

## Phase 5: Canonical Zone Serializer and Formatter

### Objective

Produce deterministic, Git-friendly zone-file output.

### Proposed Files

```text
lib/dnsmadeeasy/zone/serializer.rb
lib/dnsmadeeasy/zone/formatter.rb
spec/lib/dnsmadeeasy/zone/serializer_spec.rb
spec/lib/dnsmadeeasy/zone/formatter_spec.rb
```

### Rules

The serializer emits the normalized zone-file format described in `Zone File Compatibility and Normalization`.

1. Emit one zone per file.
2. Emit `$ORIGIN`.
3. Emit `$TTL`.
4. Emit explicit owner on every record.
5. Use `@` for apex records.
6. Omit provider-managed SOA.
7. Omit apex NS records by default.
8. Preserve delegated NS records.
9. Sort deterministically:
   - owner
   - type priority group
   - priority
   - value
   - ttl
10. Normalize whitespace.

### Commands

```text
dme zone validate FILE
dme zone fmt FILE
```

Use `fmt` as the canonical command name, matching the spec. Optionally add `format` as an alias.

### Acceptance Criteria

- Parse then serialize then parse returns equivalent records.
- Formatting an already formatted zone is byte-identical.
- `dme zone fmt FILE --check` can be added later without changing internals.

## Phase 6: Remote Record Adapter

### Objective

Convert DNS Made Easy API responses into the same internal record model used by zone files.

### Proposed Files

```text
lib/dnsmadeeasy/zone/provider_record.rb
lib/dnsmadeeasy/zone/remote_reader.rb
spec/lib/dnsmadeeasy/zone/remote_reader_spec.rb
```

### Work

1. Use the existing API client:

```ruby
client.records_for(domain)
```

2. Convert `Hashie::Mash` responses into internal records plus provider metadata.
3. Keep metadata such as record ID separate:

```ruby
ProviderRecord = Struct.new(:record, :provider_id, keyword_init: true)
```

or a `Dry::Struct` equivalent.

4. Omit `HTTPRED` from exports and emit warnings.
5. Filter provider-managed SOA and apex NS according to serializer rules.

### Acceptance Criteria

- Remote records convert to internal records with IDs preserved separately.
- HTTPRED records are reported but omitted from zone serialization.
- Export fixtures do not include provider IDs.

## Phase 7: `zone export`

### Objective

Download remote provider records and emit a canonical zone file.

### Command

```text
dme zone export DOMAIN [--output=FILE] [--ttl=300] [--include-apex-ns]
```

### Work

1. Fetch remote records.
2. Convert via remote adapter.
3. Serialize canonical zone file.
4. Write to stdout by default.
5. Write to file when `--output` is provided.
6. Print warnings to stderr, not stdout, so stdout remains pipe-safe.
7. Use threaded chunks and `TTY::Spinner` when export requires multiple independent provider calls.

### Acceptance Criteria

- Export of the same mocked records is byte-identical across runs.
- HTTPRED omission warning appears on stderr.
- Stdout contains only zone-file content.

## Phase 8: Diff Engine and Execution Plan

### Objective

Compare desired zone-file state with remote state and produce a human-readable plan.

### Proposed Files

```text
lib/dnsmadeeasy/zone/diff.rb
lib/dnsmadeeasy/zone/plan.rb
lib/dnsmadeeasy/zone/plan_action.rb
lib/dnsmadeeasy/zone/plan_renderer.rb
spec/lib/dnsmadeeasy/zone/diff_spec.rb
spec/lib/dnsmadeeasy/zone/plan_renderer_spec.rb
```

### Semantics

Default behavior:

- create missing records
- update modified records
- never delete records

Future behavior:

- `--delete` allows removal of remote records absent from the zone file, excluding protected records.

### Record Identity

Use a stable identity key:

```text
owner + type + routing fields
```

For simple records, `owner + type` may not be sufficient because multiple TXT, MX, NS, and A records can coexist. The diff engine should model record sets, not assume one record per owner/type.

Recommended approach:

- compare sets by full record content for creates/deletes
- compare update candidates only where DNS Made Easy requires update instead of delete/create
- prefer create/delete pair over ambiguous update when multiple records share owner/type

This is the part where sloppy code becomes a DNS outage generator, so do not invent clever matching without tests.

### Command

```text
dme zone plan FILE [--domain=DOMAIN] [--format=text|json]
```

If `$ORIGIN` is present, `--domain` is optional. If no `$ORIGIN` exists, require `--domain`.

### Acceptance Criteria

- Plan output is deterministic.
- Creates, updates, and skipped deletes are separately listed.
- Ambiguous updates are either resolved safely or reported as requiring manual intervention.
- `plan --format=json` is machine-readable for later automation.

## Phase 9: `zone apply`

### Objective

Execute a reviewed plan using the existing API client.

### Command

```text
dme zone apply FILE [--domain=DOMAIN] [--yes] [--delete]
```

### Work

1. Reuse the same planner used by `zone plan`.
2. Refuse to apply destructive actions unless `--delete` is present.
3. Require confirmation unless `--yes` is present.
4. Execute creates and updates through existing client methods.
5. Execute deletes only when explicitly enabled.
6. Print a final summary.
7. Split independent API operations into bounded worker-thread chunks and display a `TTY::Spinner` for each active worker/chunk.

### Safety Rules

- Never delete by default.
- Never delete provider-managed SOA.
- Never delete apex NS unless an explicit future option allows it.
- Fail before partial application if validation fails.
- Consider ordering:
  - create replacement records before deleting old records where safe
  - avoid CNAME conflicts by detecting incompatible desired state before apply
- Parallelize only independent actions after dependency/conflict checks.
- Keep execution summaries deterministic even when worker completion order varies.

### Acceptance Criteria

- `apply` uses exactly the plan generated from current remote state.
- `apply` can run against a mocked client in specs.
- Confirmation is tested through Aruba.
- Partial failures report completed and failed actions.
- Threaded execution has specs for successful chunks and failed chunks.
- Spinner behavior is covered through injected fake/no-op spinner objects.

## Phase 10: Documentation and Migration Notes

### Work

1. Update README from old flat CLI to namespaced CLI.
2. Document Ruby support and 1.0.0 breaking changes.
3. Add examples:

```text
dme account domains
dme account records_for example.com
dme zone export example.com > example.com.zone
dme zone validate example.com.zone
dme zone fmt example.com.zone
dme zone plan example.com.zone
dme zone apply example.com.zone --yes
```

4. Add a migration section:

```text
dme domains
# becomes
dme account domains
```

5. Document unsupported records:
   - `HTTPRED` omitted from standard zone files
   - future provider-specific directives may be added

### Acceptance Criteria

- README examples are covered by Aruba smoke specs where practical.
- The old command style is either removed with a clear message or documented as unsupported in 1.0.0.

## Proposed Implementation Order

1. Runtime baseline:
   - version `1.0.0`
   - Ruby 4 support
   - dependencies
   - CI
2. dry-cli launcher:
   - command registry
   - version command
   - Aruba in-process setup
3. `account` command:
   - existing API operation forwarding
   - output formats
   - delete `Runner` once parity exists
4. zone model:
   - dry types
   - dry structs
   - validation contracts
5. parser and serializer:
   - `validate`
   - `fmt`
6. remote adapter and export:
   - `export`
7. diff and plan:
   - `plan`
8. apply:
   - confirmation
   - execution
   - failure reporting
9. documentation and examples.

## Test Strategy

### Unit Specs

- typed record validation
- parser adapter
- serializer
- remote adapter
- diff engine
- plan renderer

### CLI Specs

Use Aruba in-process tests for:

- `dme --help`
- `dme version`
- `dme account operations`
- `dme account records_for example.com`
- `dme zone validate FILE`
- `dme zone fmt FILE`
- `dme zone export DOMAIN`
- `dme zone plan FILE`
- `dme zone apply FILE --yes`

### API Specs

Keep WebMock around existing client tests. Do not hit real DNS Made Easy in automated tests.

### Live Integration Specs

There is one real DNS Made Easy domain available for opt-in integration testing:

- Domain: `isdue.today`
- DNS Made Easy domain ID: `8218117`

This domain is real but not currently in use. Live specs may use it to verify actual provider behavior for export, plan, and apply.

Rules:

- Never run live integration specs in default CI.
- Gate them behind an explicit environment variable such as `DNSMADEEASY_LIVE_TESTS=1`.
- Require real credentials through the existing credential mechanisms.
- Scope mutations to predictable test records, for example `_dnsmadeeasy-test.isdue.today`.
- Clean up records created by the test.
- Never modify apex records, NS records, SOA records, MX records, or any record not created by the test run.
- Make live specs idempotent so a failed run can be retried safely.

### Golden Files

Use fixture zone files and expected output files for:

- canonical formatting
- export output
- plan text output
- plan JSON output

## Open Decisions

1. Ruby support:
   - Ruby 4 only, or Ruby 3.2+ plus Ruby 4?
   - Recommendation: Ruby 4 only if this gem is primarily for current internal use; Ruby 3.2+ if public gem compatibility matters.
2. Backward CLI compatibility:
   - Should `dme domains` continue working as an alias for `dme account domains`?
   - Recommendation: no, because this is a major version and the new command tree should be unambiguous.
3. Zone-file SOA handling:
   - Should `validate` permit SOA but `fmt/export` omit it?
   - Recommendation: parse and validate SOA if present, but never apply SOA changes in version 1.
4. Multiple records with same owner/type:
   - Should updates be represented as delete/create unless there is a single unambiguous remote candidate?
   - Recommendation: yes.
5. Apex NS behavior:
   - Should `export --include-apex-ns` exist in version 1?
   - Recommendation: yes for visibility, but default remains omit.

## Risks

1. `dns-zonefile` may not support every zone-file construct users expect.
   - Mitigation: keep adapter isolated and surface precise validation errors.
2. DNS Made Easy record semantics may not map perfectly to RFC zone records.
   - Mitigation: keep provider metadata separate and document omissions.
3. Diffing DNS records can be deceptively dangerous.
   - Mitigation: default to no deletes, deterministic plans, and conservative ambiguity handling.
4. CLI refactor can accidentally break existing automation.
   - Mitigation: major version bump, migration docs, and Aruba tests.
5. `sym` may produce Ruby 4.1 dependency warnings.
   - Mitigation: add `tsort` explicitly and consider replacing `sym` later.

## Definition of Done

- Gem version is `1.0.0`.
- Ruby 2 support is removed.
- CI runs on Ruby 4.
- CLI is dry-cli based and testable with Aruba.
- Existing account operations are available under `dme account`.
- Zone commands exist:
  - `export`
  - `validate`
  - `fmt`
  - `plan`
  - `apply`
- Zone files are canonical and deterministic.
- Apply is safe by default and never deletes without explicit opt-in.
- README documents the new command tree and migration path.
