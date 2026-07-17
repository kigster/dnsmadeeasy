# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ruby gem (`dnsmadeeasy`) — a REST API client and CLI for the DnsMadeEasy DNS provider (API v2.0). Requires Ruby ~> 4.0. Version 1.0 is **not backwards compatible** with 0.x: the executable was renamed from `dme` to `dmez` (`exe/dme` is now a deprecation stub), and the headline feature is a Terraform-style `export → plan → apply` workflow over standard DNS zone files.

## Commands

```bash
bin/setup                    # install dependencies (bundle install)
bundle exec rspec            # run all tests (order is random; WebMock blocks real HTTP)
bundle exec rspec spec/lib/dns_made_easy/zone/diff_spec.rb        # single spec file
bundle exec rspec spec/lib/dns_made_easy/zone/diff_spec.rb:42     # single example by line
bundle exec rubocop          # lint (inherits .rubocop_todo.yml; rubocop-rspec plugin)
bundle exec rake spec        # rake alias for the test suite
bundle exec rake build       # build gem (also runs the `permissions` task first)
bundle exec rake install     # install gem locally
bundle exec rake doc         # YARD docs
bin/console                  # IRB with the gem loaded
```

CI (`.github/workflows/ruby.yml`) runs `rspec` and `rubocop` on Ruby 4.0 — both must pass.

Running the tests writes a coverage badge to `docs/badges/coverage_badge.svg` via SimpleCov (see `spec/spec_helper.rb`).

## Architecture

The gem is built on the dry-rb stack: `dry-cli` (CLI), `dry-struct`/`dry-types` (value objects), `dry-monads` (`Success`/`Failure` results). Shared types live in `lib/dnsmadeeasy/types.rb` (`Types::RecordType`, `Types::Ttl`, `DNS_RECORD_TYPES`, etc.).

### Three ways callers reach the API

1. `DnsMadeEasy::Api::Client` — the actual REST client (`lib/dnsmadeeasy/api/client.rb`): HMAC-SHA1-signed requests against production or sandbox base URLs (constants in `lib/dnsmadeeasy.rb`), returning `Hashie::Mash` objects. All domain/record/secondary-domain/ip-set operations live here.
1. `DnsMadeEasy` module — holds default credentials and a memoized client; `method_missing` forwards any client method (`DnsMadeEasy.domains`, etc.).
1. `DME` — an optional shorthand module (`lib/dnsmadeeasy/dme.rb`, `lib/dme.rb`) that forwards to `DnsMadeEasy`. Only loaded via `require 'dme'` or `require 'dnsmadeeasy/dme'`, never by default.

Error classes are defined in `lib/dnsmadeeasy.rb` (all inherit `DnsMadeEasy::Error`).

### Credentials (`lib/dnsmadeeasy/credentials*.rb`)

Resolution supports: explicit key/secret, `DNSMADEEASY_API_KEY`/`DNSMADEEASY_API_SECRET` env vars, `~/.dnsmadeeasy/credentials.yml` (single or multi-account YAML with a `default_account` flag), INI format, and values encrypted with the `sym` gem (`encryption_key` may be a file path, keychain name, or env var name). Fixtures for all formats are in `spec/fixtures/`.

### CLI (`exe/dmez` → `lib/dnsmadeeasy/cli/`)

`CLI::Launcher` wraps a `Dry::CLI` registry (`cli/commands.rb`) and takes injected stdin/stdout/stderr/kernel so specs can run it in-process. Commands:

- `dmez account <operation>` — legacy pass-through to client methods, delegating to `DnsMadeEasy::Runner` (`lib/dnsmadeeasy/runner.rb`), which formats output as json/yaml/pp.
- `dmez zone export|validate|fmt|plan|apply` — the zone-file workflow (`cli/commands/zone.rb`).

### Zone subsystem (`lib/dnsmadeeasy/zone/`) — the plan/apply pipeline

Provider-neutral value objects (`Record`, `RecordSet`, `File`, `ProviderRecord`) are dry-structs. Pipeline stages all return `Dry::Monads` `Success`/`Failure` (Failure carries an array of message strings):

1. `Parser` — zone-file text → `Zone::File`, using the `dns-zonefile` gem. Injects a synthetic SOA when the file lacks one (SOA is otherwise ignored — supported types are in `Parser::SUPPORTED_RECORD_CLASSES`).
1. `Serializer` — `Zone::File` → canonical formatted zone text (used by `export` and `fmt`).
1. `RemoteAdapter` — DME API record hashes → `RemoteRecords` (`ProviderRecord`s + warnings). HTTPRED records are omitted with a warning; unknown types are a hard `Failure`.
1. `Diff` — desired vs. remote record sets → `Plan` with `creates` / `updates` / `skipped_deletes` / `ambiguous` `PlanAction`s. Deliberately conservative: deletes are skipped by default, and identity collisions (multiple records sharing owner/type) become `ambiguous` rather than guessed at.
1. `PlanRenderer` — human-readable plan output for the CLI.
1. `ApplyExecutor` — executes plan actions against the client in modes `:merge` (default), `:add_only`, `:delete_only`, with a thread pool and injectable tty-spinner factory; returns an `ApplyResult`.

## Testing conventions

- RSpec with `rspec-its`; heavy use of `subject`, `let`, and one-line `its(:attr) { is_expected.to ... }` expectations.
- WebMock is on for everything — API client specs stub HTTP; no real network calls.
- CLI specs use Aruba in **in-process** mode (`Aruba.configure` in `spec_helper.rb` sets `main_class = DnsMadeEasy::CLI::Launcher`) — `*_aruba_spec.rb` files exercise full command runs without spawning processes.
- Spec paths are split between two trees for historical reasons: newer zone/CLI specs under `spec/lib/dns_made_easy/`, older specs under `spec/lib/dnsmadeeasy/`. Follow the tree that already contains the spec for the code you touch.
