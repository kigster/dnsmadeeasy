# frozen_string_literal: true

require 'dnsmadeeasy/api/client'
require 'dnsmadeeasy/cli/commands/base'

module DnsMadeEasy
  module CLI
    # Registered dry-cli command classes.
    module Commands
      # Provides a migration hint for pre-1.0 root-level API operations.
      class LegacyOperation < Base
        desc 'Show migration hint for legacy root-level API operation'

        def initialize(operation_name)
          super()
          @operation_name = operation_name
        end

        def call(**)
          warn "Use `dme account #{@operation_name}` for this API operation."
          raise ArgumentError, "legacy root operation #{@operation_name.inspect} moved under account"
        end
      end

      DnsMadeEasy::Api::Client.public_operations.each do |operation_name|
        register operation_name, LegacyOperation.new(operation_name), hidden: true
      end
    end
  end
end
