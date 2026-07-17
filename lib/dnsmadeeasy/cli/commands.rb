# frozen_string_literal: true

require 'dry/cli'

module DnsMadeEasy
  module CLI
    module Commands
      extend Dry::CLI::Registry
    end
  end
end

require 'dnsmadeeasy/cli/message_helpers'
require 'dnsmadeeasy/cli/reported_error'
require 'dnsmadeeasy/cli/commands/base'
require 'dnsmadeeasy/cli/commands/version'
require 'dnsmadeeasy/cli/commands/account'
require 'dnsmadeeasy/cli/commands/zone'
require 'dnsmadeeasy/cli/commands/legacy_operation'
