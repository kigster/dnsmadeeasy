# frozen_string_literal: true

require 'dry/cli'

module DnsMadeEasy
  module CLI
    module Commands
      extend Dry::CLI::Registry
    end
  end
end

require 'dnsmadeeasy/cli/commands/base'
require 'dnsmadeeasy/cli/commands/version'
