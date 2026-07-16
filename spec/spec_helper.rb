# frozen_string_literal: true

require 'bundler/setup'
require 'rspec'
require 'rspec/its'
require 'simplecov'
require 'webmock/rspec'
require 'aruba/rspec'

SimpleCov.start

require 'dnsmadeeasy'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include Aruba::Api
end

Aruba.configure do |config|
  config.command_launcher = :in_process
  config.main_class = DnsMadeEasy::CLI::Launcher
end
