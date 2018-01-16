[![Gem Version](https://badge.fury.io/rb/dnsmadeeasy.svg)](https://badge.fury.io/rb/dnsmadeeasy)
[![Build Status](https://travis-ci.org/kigster/dnsmadeeasy.svg?branch=master)](https://travis-ci.org/kigster/dnsmadeeasy)
[![Maintainability](https://api.codeclimate.com/v1/badges/7a48648b482b5a5c9257/maintainability)](https://codeclimate.com/github/kigster/dnsmadeeasy/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/7a48648b482b5a5c9257/test_coverage)](https://codeclimate.com/github/kigster/dnsmadeeasy/test_coverage)


# DnsMadeEasy — Ruby Client API (Supporting SDK V2.0)

This is a fully featured REST API client for DnsMadeEasy provider. DME is an **excellent** provider, and is highly recommended for their ease of use, very solid API, and great customer support. They also offer free DNS failover with business accounts, which is highly recommended for the arrays of load balancers in front of your app.

## Usage

**DnsMadeEasy** allows you to fetch, create, update DNS records, as long as you know your API key and the secret.

### Setting up Credentials

You can find your API Key and Secret on the [Account Settings Page](https://cp.dnsmadeeasy.com/account/info) of their UI.

Once you have the key and the secret, you have several choices:

  1. You can directly instantiate a new instance of the `Client` class, by passing your API key and API secrets as arguments:

      ```ruby
      require 'dnsmadeeasy'
      @client = DnsMadeEasy::Api::Client.new(api_key, api_secret)
      ```

  2. Or, you can use the `DnsMadeEasy.configure` method to configure the key/secret pair, and then use `DnsMadeEasy` namespace to call the methods:

     ```ruby
     require 'dnsmadeeasy'

     DnsMadeEasy.configure do |config|
       config.api_key = 'XXXX'
       config.api_secret = 'YYYY'
     end

     DnsMadeEasy.domains.data.first.name #=> 'moo.gamespot.com'     
     ```
  
  3. Configuring API keys as above is easy, and can be done using environment variables. Alternatively, it may be convenient to store credentials in a YAML file. 

     * If filename is not specified, there is default location where this file is searched, which is `~/.dnsmadeeasy/credentials.yml`.
     * If filename is provided, it will be read, and must conform to the following format:
   
     **Simple Credentials Format**

      ```yaml
      # file: ~/.dnsmadeeasy/credentials.yml
      credentials:
          api_key: 2062259f-f666b17-b1fa3b48-042ad4030
          api_secret: 2265bc3-e31ead-95b286312e-c215b6a0
      ```

     **Multi-Account Credentials Format**
     
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
   
  3. Finally, you can use `DME.credentials_from_file` method that, unlike the method above, uses hash arguments:
  
     ```ruby
     @creds = DnsMadeEasy.credentials_from_file(file: 'my-creds.yml', 
                                             account: 'production', 
                                      encryption_key: 'MY_KEY')
     @creds.api_key    # => ...
     @creds.api_secret # => ...
     ```     

     Method above simply returns the credentials instance, but does not "save" it as the default credentials like `configure_from_file`. Therefore, if you need to access multiple accounts at the same time, this method will help you maintain multiple credentials at the same time.

___

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

Whenever you require `dme` you also import the `DnsMadeEasy` namespace.  **The opposite is not true.** 

So if you DO have a name clash with another top-level module `DME`, simply do `require 'dnsmadeeasy'` and none of the `DME` module namespace will be loaded.

In a nutshell you have three ways to access all methods provided by the [`DnsMadeEasy::Api::Client`](http://www.rubydoc.info/gems/dnsmadeeasy/DnsMadeEasy/Api/Client) class:

 1. Instantiate and use the client class directly,
 2. Use the top-level module `DnsMadeEasy` with `require 'dnsmadeeasy'`
 3. Use the shortened top-level module `DME` with `require 'dnsmadeeasy/dme'`
   
      
### Examples

Whether or not you are accessing a single account or multiple, it is recommended that you save your credentials (the API key and the secret) encrypted in the above mentioned file `~/.dnsmadeeasy/credentials.yml` (or any file of you preference).
___

> **NOTE:**
> 
> * DO NOT check that file into your repo! 
> * If you use encryption, do not check in your key!  
___

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

> NOTE: `to_hash` converts the entire object to a regular hash, including the deeply nested hashes, while `to_h` only converts the primary object, but not the nested hashes. Here is an example below — in the first instance where we call `to_h` we are still able to call `.value` on the nested object, because only the top-level `Mash` has been converted into a `Hash`. In the second example, this call fails, because this method does not exist, and the value must be accessed via the square brackets:
> 
> ```ruby
> IRB > recs.to_h['data'].last.value
>  ⤷ "54.200.26.233"
> IRB > recs.to_hash['data'].last.value
> "NoMethodError: undefined method `value` for #<Hash:0x00007fe36fab0f68>"
> IRB > recs.to_hash['data'].last['value']
>  ⤷ "54.200.26.233"
> ```

For more information on the actual JSON API, please refer to the [following PDF document](http://www.dnsmadeeasy.com/integration/pdf/API-Docv2.pdf).

## Available Actions

Here is the complete of all methods supported by the `DnsMadeEasy::Api::Client`:

#### Domains

* `create_domain`
* `create_domains`
* `delete_domain`
* `domain`
* `domains`
* `get_id_by_domain`

#### Records

* `records_for`
* `all`
* `base_uri`
* `create_a_record`
* `create_aaaa_record`
* `create_cname_record`
* `create_httpred_record`
* `create_mx_record`
* `create_ns_record`
* `create_ptr_record`
* `create_record`
* `create_spf_record`
* `create_srv_record`
* `create_txt_record`
* `delete_all_records`
* `delete_record`
* `delete_records`
* `find_all`
* `find_first`
* `find_record_ids`


<a name="encryption"></a>

### Encryption

It was mentioned above that the credentials YAML file may contain encrypted values. This facility is provided by the encryption gem [Sym](https://github.com/kigster/sym). 

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

## CLI Client

This library offers a simple CLI client `dme` that maps the command line arguments to method arguments for corresponding actions:

```bash
❯ dme --help
Usage:
  # Execute an API call:
  dme [ --json | --yaml ] operation [ arg1 arg2 ... ]

  # Print suported operations:
  dme op[erations]

Credentials:
  Store your credentials in a YAML file
  /Users/kig/.dnsmadeeasy/credentials.yml as follows:

  credentials:
    api_key: XXXX
    api_secret: YYYY

Examples:
   dme domain moo.com
   dme --json domain moo.com
   dme find_all moo.com A www
   dme find_first moo.com CNAME vpn-west
   dme --yaml find_first moo.com CNAME vpn-west
```

You can run `dme operations` to see the supported list of operations:

```bash
❯ dme op
Actions:
  Checkout the README and RubyDoc for the arguments to each operation,
  which is basically a method on a DnsMadeEasy::Api::Client instance.
  http://www.rubydoc.info/gems/dnsmadeeasy/DnsMadeEasy/Api/Client

Valid Operations Are:
  all
  base_uri
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
  create_spf_record
  create_srv_record
  create_txt_record
  delete_all_records
  delete_domain
  delete_record
  delete_records
  domain
  domains
  find_all
  find_first
  find_record_ids
  get_id_by_domain
  records_for
  update_record
  update_records
```

For example:

```bash
❯ dme domains moo.com
```

is equivalent to `DME.domains("moo.com")`. You can use any operation listed above, and output the result in either `YAML` or `JSON` (in addition to the default "awesome_print"), for example:

```bash
❯ dme --yaml find_all moo.com www CNAME
---
- dynamicDns: false
  failed: false
  gtdLocation: DEFAULT
  hardLink: false
  ttl: 60
  failover: false
  monitor: false
  sourceId: 5861234
  source: 1
  name: www
  value: ec2-54-202-251-7.us-west-2.compute.amazonaws.com
  id: 43509989
  type: CNAME
```

### Managing Domains

> NOTE: below we can be using `@client` instantiated with given key and secret, or 
> `DME` or `DnsMadeEasy` module.

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
> NOTE: Information is not available until an API call has been made

To get the API request total limit after a call:

```ruby
DME.request_limit
#=> 2342
```
> NOTE: Information is not available until an API call has been made


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'dnsmadeeasy'
```

And then execute:

```
$ bundle
```

Or install it yourself:

```
$ gem install dnsmadeeasy
```


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exe rspec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, up date the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Acknowledgements

The current maintainer [Konstantin Gredeskoul](https://github.com/kigster) wishes to thank:

 * Arnoud Vermeer for the original `dnsmadeeasy-rest-api` gem
 * Andre Arko, Paul Henry, James Hart formerly of [Wanelo](wanelo.com) fame, for bringing the REST API gem up to the level.
 * Phil Cohen, who graciously transferred the ownership of the name of this gem on RubyGems.org to the current maintainer.


## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/kigster/dnsmadeeasy](https://github.com/kigster/dnsmadeeasy).

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).


