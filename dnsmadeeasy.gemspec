# coding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dnsmadeeasy/version'

DnsMadeEasy::DESCRIPTION = <<-eof
This is a fully-featured DNS API client for DnsMadeEasy.com, that includes
both the Ruby API and a corresponding CLI interface. This gem is based on the 
"dnsmadeeasy-rest-api". We also wish to thank the original author Phil Cohen who 
kindly passed on the RubyGems namespace, and now you can install just plain simple
install "dnsmadeeasy" gem. The gem additionally supports storing credentials in the
~/.dnsmadeeasy/credentials.yml file, supports multiple accounts, encryption, and more.
eof

Gem::Specification.new do |spec|
  spec.name          = 'dnsmadeeasy'
  spec.version       = DnsMadeEasy::VERSION
  spec.authors       = ['Konstantin Gredeskoul', 'Arnoud Vermeer', 'Paul Henry', 'James Hart', 'Phil Cohen']
  spec.email         = %w(kigster@gmail.com letuboy@gmail.com hjhart@gmail.com)
  spec.summary       = DnsMadeEasy::DESCRIPTION
  spec.description   = DnsMadeEasy::DESCRIPTION
  spec.post_install_message = <<-EOF

Thank you for using the DnsMadeEasy ruby gem, the Ruby client 
API for DnsMadeEasy.com's SDK v2. Please note that this gem 
comes with a command line utility 'dme' which you can use 
instead of the ruby API if you prefer. Run `dme` with no
arguments to see the help message.

You can store your credentials in a YAML file in your home
directory. For more information, please see README at:
https://github.com/kigster/dnsmadeeasy

  EOF

  spec.homepage      = 'https://github.com/kigster/dnsmadeeasy'
  spec.license       = 'MIT'

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'sym'
  spec.add_dependency 'hashie'
  spec.add_dependency 'colored2'
  spec.add_dependency 'awesome_print'

  spec.add_development_dependency 'yard'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'webmock'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rspec-its'
  spec.add_development_dependency 'rubocop'

  # spec.add_development_dependency 'aruba'
end
