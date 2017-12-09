# coding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dnsmadeeasy/version'

DnsMadeEasy::DESCRIPTION = <<-eof
This is a fully-featured DNS API client for DnsMadeEasy.com, that includes
both the Ruby API and (soon to follow – a CLI). This gem used to be called
dnsmadeeasy-rest-api, but the original author Phil Cohen kindly passed on
the RubyGems namespace, and now you can install just plane simple "dnsmadeeasy".
eof

Gem::Specification.new do |spec|
  spec.name          = 'dnsmadeeasy'
  spec.version       = DnsMadeEasy::VERSION
  spec.authors       = ['Konstantin Gredeskoul', 'Arnoud Vermeer', 'Paul Henry', 'James Hart', 'Phil Cohen']
  spec.email         = %w(kigster@gmail.com letuboy@gmail.com hjhart@gmail.com)
  spec.summary       = DnsMadeEasy::DESCRIPTION
  spec.description   = DnsMadeEasy::DESCRIPTION

  spec.homepage      = 'https://github.com/kigster/dnsmadeeasy'
  spec.license       = 'MIT'

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']


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
