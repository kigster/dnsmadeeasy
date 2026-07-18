# ADnsMadeEasy (`dmez`)

[![Gem Version](https://badge.fury.io/rb/dnsmadeeasy.svg?icon=si%3Arubygems)](https://badge.fury.io/rb/dnsmadeeasy)&nbsp;![coverage](docs/badges/coverage_badge.svg)&nbsp;![Gem Total Downloads](https://img.shields.io/gem/dt/dnsmadeeasy?style=for-the-badge&logoSize=auto)


## Ruby Client API Library Supporting Rest API SDK V2.0

### Gem Version 1.0 Supporting Zone Exports, Formatting, Plan, Apply



> [!IMPORTANT]
>
> This gem is not backwards compatible with the previous version. It has been updated to work with DNS zone files and follow Terraform's pattern of the `read` → `plan` → `apply` loop. The old `dme` executable is deprecated in favor of `dmez`.

------

This gem ships two things:

1. The **`dmez` command line tool** — manage your DNS Made Easy zones as standard zone files with a Terraform-style `export` → `plan` → `apply` workflow, plus direct access to every account API operation.
1. A **fully featured Ruby client** for the DNS Made Easy REST API V2.0.

DME is an **excellent** provider, and is highly recommended for their ease of use, very solid API, and great customer support. They also offer free DNS failover with business accounts, which is highly recommended for the arrays of load balancers in front of your app.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'dnsmadeeasy'
```

And then execute `bundle`, or install it yourself:

```console
gem install dnsmadeeasy
```

## The `dmez` CLI

```bash
$ dmez --help
Commands:
  dmez account [ARGUMENT|SUBCOMMAND]  # Execute DNS Made Easy account API operation
  dmez version                        # Print version
  dmez zone [SUBCOMMAND]              # Zone file commands
```

Every command exits `0` on success and `1` on failure, and **stdout carries only payload** (zone files, plan output) — all status boxes, warnings, and progress go to stderr. Piping and redirection are always safe, and every successful operation ends with a green summary box on stderr telling you what was done.

### CLI Credentials

You can find your API Key and Secret on the [Account Settings Page](https://cp.dnsmadeeasy.com/account/info) of the DME UI. The CLI resolves credentials in this order:

1. Explicit flags: `--api-key=KEY --api-secret=SECRET`
1. An INI file passed via `--credentials=PATH`
1. Environment variables `DNSMADEEASY_API_KEY` and `DNSMADEEASY_API_SECRET`
1. A default INI file: `~/.dnsmadeeasy/credentials.ini` (or `./.dnsmadeeasy/credential.ini`)

The INI format is two lines:

```ini
dns_dnsmadeeasy_api_key = 06cb6d10-63ca-013f-380b-66219a96f4e3
dns_dnsmadeeasy_secret_key = 14b9eb80-63ca-013f-380c-66219a96f4e3
```

(The Ruby API additionally supports multi-account YAML files with optional encryption — see [Ruby API](#ruby-api) below.)

### Zone Management: `dmez zone`

This is the flagship feature of version 1.0: your DME zones become plain text files you can diff, review, version-control, and apply — the same `read` → `plan` → `apply` loop you know from Terraform.

```bash
$ dmez zone --help
Commands:
  dmez zone apply DOMAIN FILE   # Apply DNS changes for a zone file
  dmez zone export DOMAIN       # Export DNS Made Easy records as a canonical zone file
  dmez zone fmt FILE            # Format a DNS zone file
  dmez zone plan DOMAIN FILE    # Plan DNS changes for a zone file
  dmez zone validate FILE       # Validate a DNS zone file
```

#### `dmez zone export`

Exports the live records of a domain as a canonical, normalized zone file:

```bash
dmez zone export example.com --output=example.com.zone
```

A real-world export looks like this:

```dns
$ORIGIN example.com.
$TTL 60

@        300 IN A       151.101.3.52
@        300 IN A       151.101.67.52
@        300 IN ANAME   t.sni.global.fastly.net.
*        300 IN CNAME   t.sni.global.fastly.net.
_acme-challenge IN CNAME   validation-abc123.acme-validations.example.net.
dev      IN A       127.0.0.1
mail._domainkey IN CNAME   mail.domainkey.abc123.mailprovider.example.net.
ssh      300 IN A       203.0.113.22

@        IN MX      10 mail.protonmail.ch.
@        IN MX      20 mailsec.protonmail.ch.

_imaps._tcp 1800 IN SRV     0 1 993 imap.fastmail.com.
_submission._tcp 1800 IN SRV     0 1 587 smtp.fastmail.com.

@        IN TXT     "v=spf1 include:_spf.protonmail.ch ~all"
@        IN TXT     "google-site-verification=abc123def456"
_dmarc   IN TXT     "v=DMARC1; p=quarantine"
```

Things to notice:

- **`$TTL` is derived from your records** — it is set to the most common record TTL, and only records that deviate carry an explicit TTL (the `300` and `1800` above). The export is TTL-lossless: re-parsing it yields exactly the TTLs the provider reported.
- **ANAME records are preserved as ANAME.** ANAME is not a standard DNS record type (it exists only inside providers), and DME's own zone export *flattens* ANAMEs into resolved A-record snapshots — which go stale as soon as the target rotates. `dmez` keeps them first-class so the file remains a faithful, apply-able representation of your account. If you need an RFC-portable file (for BIND, or to migrate providers), pass `--strict-rfc` to the `dmez zone export` command: ANAMEs are flattened into their currently resolved A records, and a warning is printed for each conversion — if and only if a conversion happened.
- **Apex NS records are omitted by default** since DME manages them; pass `--include-apex-ns` to include them.
- Records are sorted and grouped deterministically, so exports diff cleanly in git.

Options: `--format=rfc|json|yaml` (default `rfc`), `--output=FILE`, `--ttl=N` (default TTL for records the provider returns without one), `--include-apex-ns`, `--strict-rfc`.

#### `dmez zone validate`

Parses a zone file and reports whether it is usable, with parse errors when it is not:

```bash
$ dmez zone validate example.com.zone
╔ OK ════════════════════════════════════════╗
║ Zone file is valid.                        ║
║ Records: 18                                ║
╚════════════════════════════════════════════╝
```

Any valid zone file parses as-is — including raw exports from DNS providers with fully-qualified owners, tab separation, per-record TTLs, and SOA records (SOA is ignored, since DME manages it). You do **not** need to run `fmt` first.

#### `dmez zone fmt`

Rewrites any valid zone file into the canonical format shown above (stdout):

```bash
dmez zone fmt provider-export.zone > example.com.zone
```

#### `dmez zone plan`

The heart of the workflow: compares a zone file (desired state) against the live records (actual state) and prints what would change — without changing anything.

```bash
$ dmez zone plan example.com example.com.zone
No changes.
```

When there are differences, the plan groups them into sections:

```text
Create
  - www CNAME @ (ttl=300)
Update
  - send TXT v=spf1 include:example.net ~all (ttl=60) -> send TXT v=spf1 include:example.org ~all (ttl=60)
Skipped Creates
  - @ NS ns0.dnsmadeeasy.com. (ttl=86400) (Apex NS records are managed by the DNS provider)
Skipped Deletes
  - old CNAME retired.example.net. (ttl=300) (Delete skipped by default)
Manual Review
  - @ A 151.101.131.52 (ttl=300) -> @ A 140.248.151.52 (ttl=300) (Multiple records share the same owner/type identity (desired: 5, remote: 4))
```

- **Create** — records in the file but not in the account.
- **Update** — records whose value changed (matched by owner and type).
- **Skipped Creates** — apex NS records from the file; DME manages these and the API will not create them.
- **Skipped Deletes** — records in the account but not in the file. Deletes never happen by default; see `apply --delete-only`.
- **Manual Review** — multiple records share the same owner/type identity and cannot be paired one-to-one (for example five apex `A` records in the file versus four in the account). The plan refuses to guess.

Options: `--format=text|json`, `--diff-ttl`.

The domain is always the first argument, and the zone file's `$ORIGIN` is cross-checked against it (trailing dot and case are ignored): if the file says `$ORIGIN other.example.` while you passed `example.com`, the command fails before a single API call is made. Diffing the wrong domain against the wrong file should be an error, not a surprise apply.

#### TTL Handling

`zone plan` and `zone apply` **ignore TTL-only differences by default**: a record whose only deviation from the remote is its TTL is considered unchanged, and value updates preserve the remote TTL. Pass `--diff-ttl` to treat TTLs as part of the record — TTL-only differences then become updates, and applied records take the TTL from the zone file:

```bash
$ dmez zone plan example.com example.com.zone --diff-ttl
Update
  - click CNAME links.cdn.example.net. (ttl=120) -> click CNAME links.cdn.example.net. (ttl=300)
```

#### `dmez zone apply`

Executes the plan against DNS Made Easy. You will be shown the number of actions and asked to confirm (skip the prompt with `--yes`):

```bash
$ dmez zone apply example.com example.com.zone
Apply 3 action(s)? Type yes to continue:
yes
╔ ✔ OK ══════════════════════════════════════╗
║ Zone apply complete for example.com.       ║
║ Applied: 3                                 ║
║ Failed: 0                                  ║
║ Skipped: 2                                 ║
╚════════════════════════════════════════════╝
```

Three modes control the blast radius:

| Mode            | Flag                  | Behavior                                                                   |
| --------------- | --------------------- | -------------------------------------------------------------------------- |
| Merge (default) | `--merge`             | Applies creates and updates; never deletes.                                |
| Add only        | `--add-only`, `-a`    | Only creates missing records.                                              |
| Delete only     | `--delete-only`, `-d` | Only deletes records absent from the file (SOA and apex NS are protected). |

Actions run concurrently (4 workers) with progress spinners on stderr, so stdout stays clean for scripting.

#### A Complete Workflow

Setting up transactional email for a subdomain, start to finish:

```bash
# 1. Read: export current state
dmez zone export mail.example.com --output=mail.example.com.zone

# 2. Edit: add the records your email provider asks for
$EDITOR mail.example.com.zone

# 3. Validate and review the plan
dmez zone validate mail.example.com.zone
dmez zone plan mail.example.com mail.example.com.zone

# 4. Apply (add-only is the safest mode for additive changes)
dmez zone apply mail.example.com mail.example.com.zone --add-only --yes

# 5. Verify: re-running plan should now be a no-op
dmez zone plan mail.example.com mail.example.com.zone
# => No changes.
```

The edited file from step 2 might look like:

```dns
$ORIGIN mail.example.com.
$TTL 300

click    IN CNAME   links.mailer.example.net.

@        IN MX      10 inbound-smtp.us-east-1.amazonaws.com.
send     IN MX      10 feedback-smtp.us-east-1.amazonses.com.

_dmarc   IN TXT     "v=DMARC1; p=none;"
mailer._domainkey IN TXT     "p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC7abc123...AQAB"
send     IN TXT     "v=spf1 include:amazonses.com ~all"
```

> [!NOTE]
> TXT and SPF values are stored unquoted internally and quoted exactly once in zone files — regardless of whether the DME API returns them with embedded quotes. You never need to worry about double-quoting.

### Account Operations: `dmez account`

The `account` command exposes every operation of the underlying API client (the complete list of the legacy CLI):

```bash
❯ dmez account --list
all
base_url
create_a_record
create_aaaa_record
create_cname_record
create_domain
create_domains
create_httpred_record
create_mx_record
create_ns_record
create_ptr_record
create_record
create_secondary_domain
create_secondary_domains
create_secondary_ip_set
create_spf_record
create_srv_record
create_txt_record
delete_all_records
delete_domain
delete_record
delete_records
delete_secondary_domain
delete_secondary_ip_set
domain
domains
find_all
find_first
find_record_ids
get_id_by_domain
get_id_by_secondary_domain
records_for
secondary_domain
secondary_domains
secondary_ip_set
secondary_ip_sets
update_record
update_records
update_secondary_domains
update_secondary_ip_set
```

Run `dmez account <operation> --help` for the signature of any operation, and pass `--format=json|json_pretty|yaml|pp` to control the output format:

```bash
dmez account domains --format=json_pretty
dmez account records_for example.com
dmez account create_a_record example.com www 203.0.113.10
```

<a name="ruby-api"></a>

## Ruby API

**DnsMadeEasy** allows you to fetch, create, update DNS records from Ruby, as long as you know your API key and the secret.

### Setting up Credentials

Once you have the key and the secret, you have several choices:

#### Credentials Methods for Both: CLI and Ruby API

> [!NOTE]
>
> Credentials used in these examples are random UUIDs generated specifically for these examples and are not actual valid API keys and a secret.

- Set environment variables `DNSMADEEASY_API_KEY` and `DNSMADEEASY_API_SECRET`

- Put a `credentials.ini` file in the `~/.dnsmadeeasy` folder in your home, or in the current directory. The file's format is very simple:

  ```ini
  dns_dnsmadeeasy_api_key = 06cb6d10-63ca-013f-380b-66219a96f4e3
  dns_dnsmadeeasy_secret_key = 14b9eb80-63ca-013f-380c-66219a96f4e3
  ```

- If you prefer the YAML format, place the credentials into the file `~/.dnsmadeeasy/credentials.yml`:

  ```yaml
  # file: ~/.dnsmadeeasy/credentials.yml
  credentials:
    api_key: 06cb6d10-63ca-013f-380b-66219a96f4e3
    api_secret: 14b9eb80-63ca-013f-380c-66219a96f4e3
  ```

- Or set environment variable `DNSMADEEASY_CREDENTIALS_FILE` to whatever path your credentials live. Either YAML or INI format will be supported.

#### Credentials Methods Ruby API Only

- You can directly instantiate a new instance of the `Client` class, by passing your API key and API secrets as arguments:

  ```ruby
  require 'dnsmadeeasy'
  @client = DnsMadeEasy::Api::Client.new(api_key, api_secret)
  ```

- Or, you can use the `DnsMadeEasy.configure` method to configure the key/secret pair, and then use `DnsMadeEasy` namespace to call the methods:

  ```ruby
  require 'dnsmadeeasy'
  
  DnsMadeEasy.configure do |config|
    config.api_key = 'XXXX'
    config.api_secret = 'YYYY'
  end
  
  DnsMadeEasy.domains.data.first.name #=> 'moo.gamespot.com'
  ```

### Multi-Account Credentials File Format

Below you see two accounts, with production key and secret being encrypted. See [further below](#encryption) about encrypting your key and secrets.

```yaml
accounts:
  - name: development
    default_account: true
    credentials:
      api_key: 12345678-a8f8-4466-ffff-2324aaaa9098
      api_secret: 43009899-abcc-ffcc-eeee-09f809808098
  - name: production
    credentials:
      api_key: "BAhTOh1TeW06OkRhdGE6OldyYXBwZXJT............"
      api_secret: "BAhTOh1TeW06OkRhdGE6OldyYXBwZ............"
      encryption_key: spec/fixtures/sym.key
```

You can use the following method to access both simple and multi-account YAML configurations:

```ruby
require 'dnsmadeeasy'
DnsMadeEasy.configure_from_file(file, account = nil, encryption_key = nil)

# for example:
DnsMadeEasy.configure_from_file('config/dme.yaml', 'production')
DnsMadeEasy.domains #=> [ ... ]

# or with encrypted key passed as an argument to decrypt YAML values:
DnsMadeEasy.configure_from_file(
    'config/dme.yaml',
    'production',
    ENV['PRODUCTION_KEY'])
```

Finally, you can use `DME.credentials_from_file` method that, unlike the method above, uses hash arguments:

```ruby
@creds = DnsMadeEasy.credentials_from_file(file: 'my-creds.yml',
                                        account: 'production',
                                 encryption_key: 'MY_KEY')
@creds.api_key    # => ...
@creds.api_secret # => ...
```

Method above simply returns the credentials instance, but does not "save" it as the default credentials like `configure_from_file`. Therefore, if you need to access multiple accounts at the same time, this method will help you maintain multiple credentials at the same time.

Once you configure the keys, you can also use the shortcut module to save you some typing:

```ruby
require 'dnsmadeeasy/dme'
DME.domains.data.first.name #=> 'moo.gamespot.com'
```

This has the advantage of being much shorter, but might conflict with existing modules in your Ruby VM.
In this case, just do not require `dnsmadeeasy/dme` and only require `dnsmadeeasy`, and you'll be fine.
Otherwise, using `DME` is identical to using `DnsMadeEasy`, assuming you required `dnsmadeeasy/dme` file.

### Which Namespace to Use? What is `DME` versus `DnsMadeEasy`?

Since `DnsMadeEasy` is a bit of a mouthful, we decided to offer (in addition to the standard `DnsMadeEasy` namespace) the abbreviated module `DME` that simply forwards all messages to the module `DnsMadeEasy`. If in your Ruby VM there is no conflicting top-level class `DME`, then you can `require 'dnsmadeeasy/dme'` to get all of the DnsMadeEasy client library functionality without having to type the full name once. You can even do `require 'dme'`.

Whenever you require `dme` you also import the `DnsMadeEasy` namespace. **The opposite is not true.**

So if you DO have a name clash with another top-level module `DME`, simply do `require 'dnsmadeeasy'` and none of the `DME` module namespace will be loaded.

In a nutshell you have three ways to access all methods provided by the [`DnsMadeEasy::Api::Client`](http://www.rubydoc.info/gems/dnsmadeeasy/DnsMadeEasy/Api/Client) class:

1. Instantiate and use the client class directly,
1. Use the top-level module `DnsMadeEasy` with `require 'dnsmadeeasy'`
1. Use the shortened top-level module `DME` with `require 'dnsmadeeasy/dme'`

### Examples

Whether or not you are accessing a single account or multiple, it is recommended that you save your credentials (the API key and the secret) encrypted in the above mentioned file `~/.dnsmadeeasy/credentials.yml` (or any file of you preference).

>  [!WARNING]
>
> _**DO NOT check that file into your repo! If you use encryption, do not check in your key!**_

The examples that follow assume credentials have already been configured, and so we explore the API.

Using the `DME` module (or `DnsMadeEasy` if you prefer) you can access all of your records through the available API method calls, for example:

```ruby
IRB > require 'dme' #=> true
# Or you can also do
IRB > require 'dnsmadeeasy/dme' #=> true
IRB > DME.domains.data.map(&:name)
 ⤷ ["demo.gamespot.systems",
      "dev.gamespot.systems",
             "gamespot.live",
          "gamespot.systems",
     "prod.gamespot.systems"
   ]

# These have been read from the file ~/.dnsmadeeasy/credentials.yml
IRB > DME.api_key
 ⤷ "2062259f-f666b17-b1fa3b48-042ad4030"

IRB > DME.api_secret
 ⤷ "2265bc3-e31ead-95b286312e-c215b6a0"

IRB > DME.domain('gamespot.live').delegateNameServers
 ⤷ #<Hashie::Array ["ns-125-c.gandi.net.", "ns-129-a.gandi.net.", "ns-94-b.gandi.net."]>

# Let's inspect the Client — after all, all methods are simply delegated to it:
IRB > @client = DME.client
 ⤷ #<DnsMadeEasy::Api::Client:0x00007fb6b416a4c8
    @api_key="2062259f-f666b17-b1fa3b48-042ad4030",
    @api_secret="2265bc3-e31ead-95b286312e-c215b6a0",
    @options={},
    @requests_remaining=149,
    @request_limit=150,
    @base_uri="https://api.dnsmadeeasy.com/V2.0">
```

Next, let's fetch a particular domain, get it's records and compute the counts for each record type, such as 'A', 'NS', etc.

```ruby
IRB > records = DME.records_for('gamespot.com')
IRB > [ records.totalPages, records.totalRecords ]
 ⤷ [1, 33]
IRB > records.data.select{|f| f.type == 'A' }.map(&:name)
 ⤷ ["www", "vpn-us-east1", "vpn-us-east2", "staging", "yourmom"]
IRB > types = records.data.map(&:type)
 ⤷ [....]
IRB > require 'awesome_print'
IRB > ap Hash[types.group_by {|x| x}.map {|k,v| [k,v.count]}]
{
       "MX" => 2,
      "TXT" => 1,
    "CNAME" => 3,
       "NS" => 22,
        "A" => 5
}
```

### Return Value Types

All public methods of this library return a Hash-like object, that is actually an instance of the class [`Hashie::Mash`](https://github.com/intridea/hashie). `Hashie::Mash` supports the very useful ability to reach deeply nested hash values via a chain of method calls instead of using a train of square brackets. You can always convert it to a regular hash either `to_hash` or `to_h` on an instance of a `Hashie::Mash` to get a pure hash representation.

> [!NOTE]
>
> `to_hash` converts the entire object to a regular hash, including the deeply nested hashes, while `to_h` only converts the primary object, but not the nested hashes. Here is an example below -- in the first instance where we call `to_h` we are still able to call `.value` on the nested object, because only the top-level `Mash` has been converted into a `Hash`. In the second example, this call fails, because this method does not exist, and the value must be accessed via the square brackets:



```ruby
IRB > recs.to_h['data'].last.value
 ⤷ "54.200.26.233"
IRB > recs.to_hash['data'].last.value
"NoMethodError: undefined method `value` for #<Hash:0x00007fe36fab0f68>"
IRB > recs.to_hash['data'].last['value']
 ⤷ "54.200.26.233"
```

For more information on the actual JSON API, please refer to the [following PDF document](http://www.dnsmadeeasy.com/integration/pdf/API-Docv2.pdf).

### Available Actions

Here is the complete list of all methods supported by the `DnsMadeEasy::Api::Client`:

#### Domains

- `create_domain`
- `create_domains`
- `delete_domain`
- `domain`
- `domains`
- `get_id_by_domain`

#### Records

- `records_for`
- `all`
- `base_uri`
- `create_a_record`
- `create_aaaa_record`
- `create_cname_record`
- `create_httpred_record`
- `create_mx_record`
- `create_ns_record`
- `create_ptr_record`
- `create_record`
- `create_spf_record`
- `create_srv_record`
- `create_txt_record`
- `delete_all_records`
- `delete_record`
- `delete_records`
- `find_all`
- `find_first`
- `find_record_ids`

#### Secondary Domains

- `secondary_domain`
- `secondary_domains`
- `get_id_by_secondary_domain`
- `create_secondary_domain`
- `create_secondary_domains`
- `update_secondary_domains`
- `delete_secondary_domain`

#### Secondary IpSets

- `secondary_ip_set`
- `secondary_ip_sets`
- `create_secondary_ip_set`
- `update_secondary_ip_set`
- `delete_secondary_ip_set`

### Managing Domains

> [!NOTE]
>
> Below we can be using `@client` instantiated with given key and secret, or `DME` or `DnsMadeEasy` module.

To retrieve all domains:

```ruby
require 'dnsmadeeasy/dme'
DME.domains
```

To retreive the id of a domain by the domain name:

```ruby
DME.get_id_by_domain('test.io')
```

To retrieve the full domain record by domain name:

```ruby
DME.domain('test.io')
```

To create a domain:

```ruby
DME.create_domain('test.io')
# Multiple domains can be created by:
DME.create_domains(%w[test.io moo.re])
```

To delete a domain:

```ruby
DME.delete_domain        ('test.io')
```

### Managing Secondary Domains

To retrieve all secondary domains:

```ruby
DME.secondary_domains
```

To retrieve secondary domain by id:

```ruby
DME.secondary_domain(domain_id)
```

To retrieve the id of a domain by the secondary domain name:

```ruby
DME.get_id_by_secondary_domain('test.io')
```

To create a secondary domain:

```ruby
# IP_SET_ID is id of ip_set you want to associate domain with
DME.create_secondary_domain('test.io', IP_SET_ID)

# Multiple domains can be created by:
DME.create_secondary_domains(%w[test.io moo.re], IP_SET_ID)
```

To update a secondary domain:

```ruby
# IP_SET_ID is id of ip_set you want to associate
# DOMAIN_ID is id of domain
DME.update_secondary_domains([DOMAIN_ID], IP_SET_ID)
```

To delete a secondary domain:

```ruby
DME.delete_secondary_domain('test.io')
```

### Managing Secondary IpSets

To retrieve all secondary IpSets:

```ruby
DME.secondary_ip_sets
```

To retrieve single ipSet:

```ruby
DME.secondary_ip_set(IP_SET_ID)
```

To create an ipSet:

```ruby
# IP_LIST is list of ips to be associated with this ip_set, like %w[8.8.8.8, 1.1.1.1]
DME.create_secondary_ip_set('ip-set-name', IP_LIST)
```

To update an ipSet:

```ruby
DME.update_secondary_ip_set(IP_SET_ID, 'ip-list-name', IP_LIST)
```

To delete an ipSet:

```ruby
DME.delete_secondary_ip_set(IP_SET_ID)
```

### Managing Records

To retrieve all records for a given domain name:

```ruby
DME.all('test.io')
```

To find the record id for a given domain, name, and type:

This finds all of the IDs matching 'woah.test.io' type 'A':

```ruby
DME.find_record_ids      ('test.io', 'woah', 'A')
# => [ 234234, 2342345 ]
```

```ruby
# To delete a record by domain name and record id (the record id can be retrieved from `find_record_id`:
DME.delete_record        ('test.io', 123)
# To delete multiple records:
DME.delete_records       ('test.io', [123, 143])
# To delete all records in the domain:
DME.delete_all_records   ('test.io')
```

To create records of various types:

```ruby
# The generic method:
DME.create_record        ('test.io', 'woah', 'A', '127.0.0.1', { 'ttl' => '60' })

# Specialized methods:
DME.create_a_record      ('test.io', 'woah', '127.0.0.1', {})
DME.create_aaaa_record   ('test.io', 'woah', '127.0.0.1', {})
DME.create_ptr_record    ('test.io', 'woah', '127.0.0.1', {})
DME.create_txt_record    ('test.io', 'woah', '127.0.0.1', {})
DME.create_cname_record  ('test.io', 'woah', '127.0.0.1', {})
DME.create_ns_record     ('test.io', 'woah', '127.0.0.1', {})
DME.create_spf_record    ('test.io', 'woah', '127.0.0.1', {})
```

#### Specialized Record Types

Below are the method calls for `MX`, `SRV`, and `HTTPRED` types:

```ruby
# Arguments are: domain_name, name, priority, value, options = {}
DME.create_mx_record     ('test.io', 'woah', 5, '127.0.0.1', {})
# Arguments are: domain_name, name, priority, weight, port, value, options = {}
DME.create_srv_record    ('test.io', 'woah', 1, 5, 80, '127.0.0.1', {})
# Arguments are: domain_name, name, value, redirectType,
DME.create_httpred_record('test.io', 'woah', '127.0.0.1', 'STANDARD - 302',
                               # description, keywords, title, options = {}
                              'a description', 'keywords', 'a title', {})
```

To update a record:

```ruby
DME.update_record('test.io', 123, 'woah', 'A', '127.0.1.1',  { 'ttl' => '60' })
```

To update several records:

```ruby
DME.update_records('test.io',
  [
    { 'id'   => 123,
      'name' => 'buddy',
      'type' => 'A',
      'value'=> '127.0.0.1'
    }
  ], { 'ttl' => '60' })
```

To get the number of API requests remaining after a call:

```ruby
DME.requests_remaining
#=> 19898
```



> [!NOTE]
> Information is not available until an API call has been made.

To get the API request total limit after a call:

```ruby
DME.request_limit
#=> 2342

```

<a name="encryption"></a>

### Encryption

It was mentioned above that the credentials YAML file may contain encrypted values. This facility is provided by the encryption gem [Sym](https://github.com/kigster/sym).

> [!IMPORTANT]
>
> There is a much better encryption facility called `sopsy` written in Rust. We highly recommend you use `sopsy` for encrypting your secrets, as it mints private keys on a Mac inside Appple Enclave hardware chip. For more information please see [sopsy's website](https://sopsy-cli.dev) or the [Github Project](https://github.com/kigster/sopsy).

------

In order to encrypt your values, you need to perform the following steps:

```bash
gem install sym

# let's generate a new key and save it to a file:
sym -g -o my.key

# if you are on Mac OS-X, you can import the key into the KeyChain.
# this creates an entry in the keychain named 'my.key' that can be used later.
sym -g -x my.key
```

Once you have the key generated, first, **make sure to never commit this to any repo!**. You can use 1Password for it, or something like that.

Let's encrypt our actual API key:

```bash
api_key="12345678-a8f8-4466-ffff-2324aaaa9098"
api_secret="43009899-abcc-ffcc-eeee-09f809808098"
sym -ck my.key -e -s "${api_key}"
# => prints the encrypted value

# On a mac, you can copy it to clipboard:
sym -ck my.key -e -s "${api_secret}" | pbcopy
```

Now, you place the encrypted values in the YAML file, and you can save "my.key" as the value against `encryption_key:` at the same level as the `api_key` and `api_secret` in the YAML file. This value can either point to a file path, or be a keychain name, or even a name of an environment variable. For full details, please see [sym documentation](https://github.com/kigster/sym#using-sym-with-the-command-line).

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec rspec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Acknowledgements

The current maintainer [Konstantin Gredeskoul](https://github.com/kigster) wishes to thank:

- *Arnoud Vermeer* for the original `dnsmadeeasy-rest-api` gem
- *Andre Arko, Paul Henry, James Hart* formerly of [Wanelo](wanelo.com) fame, for bringing the REST API gem up to the level.
- *Phil Cohen*, who graciously transferred the ownership of the name of this gem on RubyGems.org to the current maintainer.

## Contributing

Bug reports and pull requests are welcome on GitHub at <https://github.com/kigster/dnsmadeeasy>.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
