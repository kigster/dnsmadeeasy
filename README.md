[![Gem Version](https://badge.fury.io/rb/dnsmadeeasy.svg)](https://badge.fury.io/rb/dnsmadeeasy)
[![Build Status](https://travis-ci.org/kigster/dnsmadeeasy.svg?branch=master)](https://travis-ci.org/kigster/dnsmadeeasy)
[![Maintainability](https://api.codeclimate.com/v1/badges/7a48648b482b5a5c9257/maintainability)](https://codeclimate.com/github/kigster/dnsmadeeasy/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/7a48648b482b5a5c9257/test_coverage)](https://codeclimate.com/github/kigster/dnsmadeeasy/test_coverage)


# DnsMadeEasy — Ruby Client API (Supporting SDK V2.0)

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

## Usage

After requiring `dnsmadeeasy` you can either:

 * directly instantiate a new instance of the `DnsMadeEasy::Api::Client` class, 
by passing your API key and API secret, OR:

 * you can use the `DnsMadeEasy.client` method after configuring the key and the secret.
 
### Recommended Usage

If you are not planning on accessing more than one DnsMadeEasy account from the same Ruby VM, you might prefer the following usage since it's a bit simpler:


```ruby
require 'dnsmadeeasy'
DnsMadeEasy.configure do |config|
  config.api_key = 'XXXX'
  config.api_secret = 'YYYY' 
end

@client = ::DnsMadeEasy.client
@client.domain('test.io')
# => Domain Object
```

### Advanced Usage

You can also instantiate a `Client` object with a different set of API key and secret, should you need to manage multiple accounts from within the same Ruby VM. The `DnsMadeEasy.configure` method is not used in this case, and the values passed to the constructor will be used instead.
 
```ruby
require 'dnsmadeeasy/api/client'

api_key    = 'XXXX'
api_secret = 'YYYY'

@client = ::DnsMadeEasy::Api::Client.new(api_key, api_secret)  
```

#### Module Level Access

All return values are the direct JSON responses from DNS Made Easy converted into a Hash.

For more information on the actual JSON API, please refer to the [following PDF document](http://www.dnsmadeeasy.com/integration/pdf/API-Docv2.pdf).

### Managing Domains

To retrieve all domains:

```ruby
@client.domains
```

To retreive the id of a domain by the domain name:

```ruby
@client.get_id_by_domain('test.io')
```

To retrieve the full domain record by domain name:

```ruby
@client.domain('test.io')
```

To create a domain:

```ruby
@client.create_domain('test.io')

# Multiple domains can be created by:
@client.create_domains(%w[test.io moo.re])
```

To delete a domain:

```ruby
@client.delete_domain        ('test.io')
```

### Managing Records

To retrieve all records for a given domain name:

```ruby
@client.records_for          ('test.io')
```

To find the record id for a given domain, name, and type:

This finds the id of the A record 'woah.test.io'.

```ruby
@client.find_record_id       ('test.io', 'woah', 'A')
```

To delete a record by domain name and record id (the record id can be retrieved from `find_record_id`:

```ruby
@client.delete_record        ('test.io', 123)

# To delete multiple records:

@client.delete_records       ('test.io', [123, 143])

# To delete all records in the domain:

@client.delete_all_records   ('test.io')
```

To create a record:

```ruby
@client.create_record        ('test.io', 'woah', 'A', '127.0.0.1', { 'ttl' => '60' })
@client.create_a_record      ('test.io', 'woah', '127.0.0.1', {})
@client.create_aaaa_record   ('test.io', 'woah', '127.0.0.1', {})
@client.create_ptr_record    ('test.io', 'woah', '127.0.0.1', {})
@client.create_txt_record    ('test.io', 'woah', '127.0.0.1', {})
@client.create_cname_record  ('test.io', 'woah', '127.0.0.1', {})
@client.create_ns_record     ('test.io', 'woah', '127.0.0.1', {})
@client.create_spf_record    ('test.io', 'woah', '127.0.0.1', {})
# Arguments are: domain_name, name, priority, value, options = {}
@client.create_mx_record     ('test.io', 'woah', 5, '127.0.0.1', {})
# Arguments are: domain_name, name, priority, weight, port, value, options = {}
@client.create_srv_record    ('test.io', 'woah', 1, 5, 80, '127.0.0.1', {})
# Arguments are: domain_name, name, value, redirectType, description, keywords, title, options = {}
@client.create_httpred_record('test.io', 'woah', '127.0.0.1', 'STANDARD - 302', 
                              'a description', 'keywords', 'a title', {})
```

To update a record:

```ruby
@client.update_record        ('test.io', 123, 'woah', 'A', '127.0.1.1',  
                             { 'ttl' => '60' })
```

To update several records:

```ruby
@client.update_records('test.io', 
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
@client.requests_remaining
#=> 19898
```
> NOTE: Information is not available until an API call has been made

To get the API request total limit after a call:

```ruby
@client.request_limit
#=> 2342
```
>Information is not available until an API call has been made


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
