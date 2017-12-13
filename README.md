[![Gem Version](https://badge.fury.io/rb/dnsmadeeasy.svg)](https://badge.fury.io/rb/dnsmadeeasy)
[![Build Status](https://travis-ci.org/kigster/dnsmadeeasy.svg?branch=master)](https://travis-ci.org/kigster/dnsmadeeasy)
[![Maintainability](https://api.codeclimate.com/v1/badges/7a48648b482b5a5c9257/maintainability)](https://codeclimate.com/github/kigster/dnsmadeeasy/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/7a48648b482b5a5c9257/test_coverage)](https://codeclimate.com/github/kigster/dnsmadeeasy/test_coverage)


# DnsMadeEasy — Ruby Client API (Supporting SDK V2.0)

This is a fully featured REST API client for DnsMadeEasy provider. DME is an **excellent** provider, and is highly recommended for their ease of use, very solid API, and great customer support. They also offer free DNS failover with business accounts, which is highly recommended for the arrays of load balancers in front of your app.

## Usage

**DnsMadeEasy** allows you to fetch, create, update DNS records, as long as you know your API key and the secret.

You can find your API Key and Secret on the [Account Settings Page](https://cp.dnsmadeeasy.com/account/info) of their UI.

Once you have the key and the secret, you have several choices:

  1. Perhaps the most conveniently, you can store them in a small YAML file, that must be placed in a specific location within your home folder:  `~/.dnsmadeeasy/credentials.yml`. The file should look like this one below (NOTE: these are not real credentials, btw):

      ```yaml
      # file: ~/.dnsmadeeasy/credentials.yml
      credentials:
        api_key: 2062259f-f666b17-b1fa3b48-042ad4030
        api_secret: 2265bc3-e31ead-95b286312e-c215b6a0
      ```

      With this file existing, you can query right away, by using the shortcut module `DME`, such as         

      ```ruby
      require 'dme'
      DME.domains.data.first.name #=> 'moo.gamespot.com'
      ```

  2. Or, you can directly instantiate a new instance of the `Client` class, by passing your API key and API secrets as arguments:

      ```ruby
      require 'dnsmadeeasy'
      @client = DnsMadeEasy::Api::Client.new(api_key, api_secret)
      ```

      The advantage of this method is that you can query multiple DnsMadeEasy accounts from the same Ruby VM. With other methods, only one account can be connected to.

  3. Or, you can use the `DnsMadeEasy.configure` method to configure the key/secret pair, and then use `DnsMadeEasy` namespace to call the methods:

     ```ruby
     require 'dnsmadeeasy'

     DnsMadeEasy.configure do |config|
       config.api_key = 'XXXX'
       config.api_secret = 'YYYY'
     end

     DnsMadeEasy.domains.data.first.name #=> 'moo.gamespot.com'     
     ```

### Shortcut Module `DME` and `DnsMadeEasy` Namespaces

Since `DnsMadeEasy` is a bit of a mouthful, we decided to offer (in addition) the abbreviated module `DME` that simply forwards all method calls to `DnsMadeEasy`. You can now `require 'dme'` to get all of the DnsMadeEasy client library loaded up, assuming it does not clash with any other `dme` file in your project.

And then you can use `DME.method(*args)` as you would on `DnsMadeEasy.method(*args)` or on the instance of the actual worker-horse class of this library, the gorgeous blone with a very long name: `DnsMadeEasy::Api::Client`.


### Examples

If you are planning on accessing *only one DnsMadeEasy account from the same Ruby VM*, it's recommended that you save your credentials (the API key and the secret) in the above mentioned file `~/.dnsmadeeasy/credentials.yml`.

> **NOTE: DO NOT check that file into your repo!**  
> **NOTE: The examples that follow assume credentials have been read from that file.**

Using the `DME` module (or `DnsMadeEasy` if you prefer) you can access all of your records through the available API method calls, for example:


```ruby
IRB(main):003:0> require 'dme' #=> true
IRB(main):003:0> DME.domains.data.map(&:name)
 ⤷ ["demo.gamespot.systems",
      "dev.gamespot.systems",
             "gamespot.live",
          "gamespot.systems",
     "prod.gamespot.systems"
   ]

# These have been read from the file ~/.dnsmadeeasy/credentials.yml
IRB(main):008:0> DME.api_key
 ⤷ "2062259f-f666b17-b1fa3b48-042ad4030"

IRB(main):009:0> DME.api_secret
 ⤷ "2265bc3-e31ead-95b286312e-c215b6a0"
 
IRB(main):011:0> DME.domain('gamespot.live').delegateNameServers
 ⤷ #<Hashie::Array ["ns-125-c.gandi.net.", "ns-129-a.gandi.net.", "ns-94-b.gandi.net."]>

# Let's inspect the Client — after all, all methods are simply delegated to it:
IRB(main):010:0> @client = DME.client
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
IRB(main):016:0> records = DME.records_for('gamespot.com')

IRB(main):017:0> [ records.totalPages, records.totalRecords ]
 ⤷ [1, 33]
 
IRB(main):016:0> records.data.select{|f| f.type == 'A' }.map(&:name)
 ⤷ ["www", "vpn-us-east1", "vpn-us-east2", "staging", "yourmom"]
 
 IRB(main):026:0> types = records.data.map(&:type)
 ⤷ ["MX", "MX", "TXT", "CNAME", "CNAME", "NS", "NS", "NS", "NS", "NS", "NS", 
     "NS", "NS", "NS", "NS", "A", "NS", "NS", "NS", "NS", "NS", "NS", "NS", 
     "NS", "NS", "NS", "NS", "NS", "CNAME", "A", "A", "A", "A"]

IRB(main):027:0> require 'awesome_print' 
IRB(main):028:0> ap Hash[types.group_by {|x| x}.map {|k,v| [k,v.count]}]
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
> IRB(main):060:0> recs.to_h['data'].last.value
>  ⤷ 54.200.26.233
> IRB(main):061:0> recs.to_hash['data'].last.value
> NoMethodError: undefined method `value' for #<Hash:0x00007fe36fab0f68>
> IRB(main):062:0> recs.to_hash['data'].last['value']
>  ⤷ 54.200.26.233
> ```

For more information on the actual JSON API, please refer to the [following PDF document](http://www.dnsmadeeasy.com/integration/pdf/API-Docv2.pdf).

## Method Calls

Here is the complete of all methods supported by the `DnsMadeEasy::Api::Client`:

* `create_a_record`
* `create_aaaa_record`
* `create_cname_record`
* `create_domain`
* `create_domains`
* `create_httpred_record`
* `create_mx_record`
* `create_ns_record`
* `create_ptr_record`
* `create_record`
* `create_spf_record`
* `create_srv_record`
* `create_txt_record`
* `delete_all_records`
* `delete_domain`
* `delete_record`
* `delete_records`
* `domain`
* `domains`
* `find_all`
* `find_first`
* `find_record_ids`
* `get_id_by_domain`
* `records_for`
* `update_record`
* `update_records`

### CLI Client

This library offers a simple CLI client that maps CLI arguments to method arguments:

```bash
❯ dme [ --yaml | --json ] operation [ arg1, arg2, ... ]
```

For example:

```bash
❯ dme domains moo.com
```

is equivalent to `DME.domains("moo.com")`. You can use any operation listed above, for example:

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

To delete a record by domain name and record id (the record id can be retrieved from `find_record_id`:

```ruby
DME.delete_record        ('test.io', 123)

# To delete multiple records:

DME.delete_records       ('test.io', [123, 143])

# To delete all records in the domain:

DME.delete_all_records   ('test.io')
```

To create a record:

```ruby
DME.create_record        ('test.io', 'woah', 'A', '127.0.0.1', { 'ttl' => '60' })
DME.create_a_record      ('test.io', 'woah', '127.0.0.1', {})
DME.create_aaaa_record   ('test.io', 'woah', '127.0.0.1', {})
DME.create_ptr_record    ('test.io', 'woah', '127.0.0.1', {})
DME.create_txt_record    ('test.io', 'woah', '127.0.0.1', {})
DME.create_cname_record  ('test.io', 'woah', '127.0.0.1', {})
DME.create_ns_record     ('test.io', 'woah', '127.0.0.1', {})
DME.create_spf_record    ('test.io', 'woah', '127.0.0.1', {})
# Arguments are: domain_name, name, priority, value, options = {}
DME.create_mx_record     ('test.io', 'woah', 5, '127.0.0.1', {})
# Arguments are: domain_name, name, priority, weight, port, value, options = {}
DME.create_srv_record    ('test.io', 'woah', 1, 5, 80, '127.0.0.1', {})
# Arguments are: domain_name, name, value, redirectType, description, keywords, title, options = {}
DME.create_httpred_record('test.io', 'woah', '127.0.0.1', 'STANDARD - 302',
                              'a description', 'keywords', 'a title', {})
```

To update a record:

```ruby
DME.update_record        ('test.io', 123, 'woah', 'A', '127.0.1.1',  
                             { 'ttl' => '60' })
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
>Information is not available until an API call has been made

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
 * Phil Cohen, who graciously transferred the ownership of this gem on RubyGems to the current maintainer.


## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/kigster/dnsmadeeasy](https://github.com/kigster/dnsmadeeasy).

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
