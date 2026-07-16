# DNS Zone Management Specification

## Overview

Extend the existing `dnsmadeeasy` Ruby gem with first-class support for managing DNS zones using standard RFC 1034/1035 zone files.

The objective is to make zone files the source of truth while continuing to use the existing DNS Made Easy API client for all provider interactions.

This feature is intentionally **DNS Made Easy specific**. It does not attempt to become a generic multi-provider framework.

______________________________________________________________________

# Goals

- Use standard DNS zone files.
- Produce deterministic, Git-friendly output.
- Generate human-readable execution plans.
- Apply the minimum set of API changes.
- Be safe by default.
- Be easy for LLMs to generate and modify.

______________________________________________________________________

# Existing Foundation

The gem already provides:

- authentication
- domain lookup
- record enumeration
- create/update/delete operations
- YAML/JSON output
- CLI

The new functionality builds on these capabilities rather than replacing them.

______________________________________________________________________

# Architecture

```
          Zone File
              │
              ▼
     DNS::Zonefile.load
      (dns-zonefile gem)
              │
              ▼
      Internal Record Model
              │
              ├─────────────┐
              │             │
              ▼             ▼
      dme all DOMAIN    Zone File
      (remote state)    Serializer
              │
              ▼
         Diff Engine
              │
              ▼
      Execution Plan
              │
              ▼
     Existing API Client
```

______________________________________________________________________

# Dependency

Use the `dns-zonefile` gem solely for parsing RFC-compliant zone files.

The rest of the implementation should not depend directly on `DNS::Zonefile::*` classes.

Instead:

```
Zone File
    │
    ▼
Parser Adapter
    │
    ▼
DnsMadeEasy::Zone::Record
```

This isolates the rest of the implementation from parser details.

______________________________________________________________________

# Canonical Zone File

Exports should produce a normalized zone file.

Characteristics:

- one zone per file
- explicit owner on every record
- `$ORIGIN`
- `$TTL`
- `@` for zone apex
- deterministic ordering
- normalized whitespace
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

______________________________________________________________________

# New Commands

```
dme zone export DOMAIN
```

Download remote records and emit a canonical zone file.

```
dme zone validate FILE
```

Validate syntax and supported record types.

```
dme zone fmt FILE
```

Rewrite the file into canonical formatting.

```
dme zone plan FILE
```

Compare desired state against the provider and display the planned actions.

```
dme zone apply FILE
```

Execute the planned changes.

______________________________________________________________________

# Internal Record Model

The diff engine operates on an internal provider-neutral record model.

Provider-specific metadata (record IDs, source IDs, etc.) is stored separately and is never serialized into zone files.

______________________________________________________________________

# Diff Semantics

Default behavior:

- create missing records
- update modified records
- never delete records

Future option:

```
dme zone apply FILE --delete
```

removes remote records not present in the zone file (excluding protected provider-managed records).

______________________________________________________________________

# Export Rules

Export should normalize:

- empty owner → `@`
- relative owner names
- TTLs
- whitespace
- ordering

Repeated export of an unchanged zone should produce byte-identical output.

______________________________________________________________________

# Provider-specific Records

HTTPRED cannot be represented in a standard RFC zone file.

Version 1 behavior:

- omit HTTPRED records from exports
- emit a warning listing omitted records

Future versions may support provider-specific comment directives.

______________________________________________________________________

# LLM Workflow

The intended AI workflow is:

```
User request
      │
      ▼
LLM edits zone file
      │
      ▼
dme zone plan
      │
      ▼
Human reviews plan
      │
      ▼
dme zone apply
```

The LLM never calls provider APIs directly.

______________________________________________________________________

# Non-goals

- Multi-provider abstraction
- Inventing a new configuration language
- Replacing existing DNS tooling
- Supporting every obscure BIND extension

The project embraces standard DNS zone files and extends the existing `dnsmadeeasy` gem with a modern declarative workflow.
