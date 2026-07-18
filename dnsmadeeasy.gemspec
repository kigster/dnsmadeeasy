# frozen_string_literal: true

# vim: ft=ruby

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dnsmadeeasy/version'

# rubocop:todo Naming/HeredocDelimiterCase
DnsMadeEasy::DESCRIPTION = <<~eof
  This gem ships "dmez" — a Terraform-style command line tool for the
  DNS provider DnsMadeEasy.com — together with an authoritative,
  fully-featured Ruby client for their REST API v2.0.

  The dmez CLI manages your zones as standard DNS zone files with the
  familiar read -> plan -> apply loop: "dmez zone export" writes a
  canonical, TTL-lossless zone file with fixed aligned columns;
  "dmez zone plan" diffs it against the live records (conservatively:
  deletes are skipped by default and ambiguous record groups are
  flagged for manual review); "dmez zone apply" executes the plan in
  merge, add-only, or delete-only mode. Zone files can also be
  validated and formatted, ANAME records are preserved as first-class
  citizens (with optional --strict-rfc flattening on export), and
  every account API operation is available under "dmez account".

  The Ruby API supports storing credentials in
  ~/.dnsmadeeasy/credentials.yml, including multiple accounts and
  sym-encrypted values.

  ACKNOWLEDGEMENTS:

  1. This gem is based on the original work contributed by Wanelo.com to the
     now abandonded "dnsmadeeasy-rest-api" client.

  2. We also wish to thank the gem author Phil Cohen who
     kindly yielded the "dnsmadeeasy" RubyGems namespace to this gem.

  3. We also thank Praneeth Are for contributing the support for
     secondary domains in 0.3.5.
eof

Gem::Specification.new do |spec|
  spec.name          = 'dnsmadeeasy'
  spec.version       = DnsMadeEasy::VERSION
  spec.authors       = ['Konstantin Gredeskoul', 'Arnoud Vermeer', 'Paul Henry', 'James Hart', 'Phil Cohen',
                        'Praneeth Are']
  spec.email         = %w[kigster@gmail.com letuboy@gmail.com hjhart@gmail.com]
  spec.summary       = DnsMadeEasy::DESCRIPTION
  spec.description   = DnsMadeEasy::DESCRIPTION
  spec.post_install_message = <<~EOF
    Thank you for installing the DnsMadeEasy ruby gem, which ships
    the 'dmez' CLI — manage your DNS zones as plain zone files with
    a Terraform-style workflow:

      dmez zone export yourdomain.com --output=yourdomain.com.zone
      dmez zone plan   yourdomain.com yourdomain.com.zone
      dmez zone apply  yourdomain.com yourdomain.com.zone

    Run `dmez --help` to see all commands (the old 'dme' executable
    is deprecated). A full Ruby API client is included as well, with
    (multi-account) credentials support via a YAML file in your home
    directory. For more information, please see the README at:
    https://github.com/kigster/dnsmadeeasy
  EOF

  spec.homepage      = 'https://github.com/kigster/dnsmadeeasy'
  spec.license       = 'MIT'
  spec.required_ruby_version = '~> 4.0'

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end

  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'awesome_print'
  spec.add_dependency 'colored2'
  spec.add_dependency 'dns-zonefile'
  spec.add_dependency 'dry-cli'
  spec.add_dependency 'dry-monads'
  spec.add_dependency 'dry-struct'
  spec.add_dependency 'dry-types'
  spec.add_dependency 'hashie'
  spec.add_dependency 'sym'
  spec.add_dependency 'tsort'
  spec.add_dependency 'tty-box'
  spec.add_dependency 'tty-spinner'

  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'relaxed-rubocop'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rspec-its'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'webmock'
  spec.add_development_dependency 'yard'

  spec.add_development_dependency 'aruba'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
