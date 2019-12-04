# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dnsmadeeasy/version'

# rubocop:todo Naming/HeredocDelimiterCase
DnsMadeEasy::DESCRIPTION = <<~eof
    This is an authoratative and fully-featured API client for the DNS Provider "DnsMadeEasy.com".

    This library offers both a rich Ruby API that you can use to automate DNS record management, as well
    as a rich CLI interface with the command line executable "dme" installed when you install the gem.
    The gem additionally supports storing credentials in the ~/.dnsmadeeasy/credentials.yml
    file, supports multiple accounts, encryption, and more.

    If you are using Chef consider using the "dnsmadeeasy" Chef Cookbook, while uses this gem behind
    the scenes: https://supermarket.chef.io/cookbooks/dnsmadeeasy<br />

    ACKNOWLEDGEMENTS:

    1. This gem is based on the original work contributed by Wanelo.com to the
       now abandonded "dnsmadeeasy-rest-api" client.

    2. We also wish to thank the gem author Phil Cohen who
       kindly yielded the "dnsmadeeasy" RubyGems namespace to this gem.

    3. We also thank Praneeth Are for contributing the support for secondary domains in 0.3.5.
eof

Gem::Specification.new do |spec|
  spec.name          = 'dnsmadeeasy'
  spec.version       = DnsMadeEasy::VERSION
  spec.authors       = ['Konstantin Gredeskoul', 'Arnoud Vermeer', 'Paul Henry', 'James Hart', 'Phil Cohen', 'Praneeth Are']
  spec.email         = %w(kigster@gmail.com letuboy@gmail.com hjhart@gmail.com)
  spec.summary       = DnsMadeEasy::DESCRIPTION
  spec.description   = DnsMadeEasy::DESCRIPTION
  # rubocop:todo Naming/HeredocDelimiterNaming
  spec.post_install_message = <<~EOF
      Thank you for using the DnsMadeEasy ruby gem, the Ruby client
      API for DnsMadeEasy.com's SDK v2. Please note that this gem
      comes with a rich command line utility 'dme' which you can use
      instead of the ruby API if you prefer. Run `dme` with no
      arguments to see the help message.

      You can also store (multi-account) credentials in a YAML file in
      your home directory. For more information, please see README at:
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

  spec.add_dependency 'awesome_print'
  spec.add_dependency 'colored2'
  spec.add_dependency 'hashie'
  spec.add_dependency 'sym'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'relaxed-rubocop'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rspec-its'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'webmock'
  spec.add_development_dependency 'yard'

  # spec.add_development_dependency 'aruba'
end
