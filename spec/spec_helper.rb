require 'bundler/setup'
require 'rspec'
require 'rspec/its'
require 'simplecov'
require 'webmock/rspec'

SimpleCov.start

require 'dnsmadeeasy'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
