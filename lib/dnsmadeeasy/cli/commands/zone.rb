# frozen_string_literal: true

require 'dnsmadeeasy/cli/commands/base'
require 'dnsmadeeasy/cli/message_helpers'
require 'dnsmadeeasy/zone/parser'
require 'dnsmadeeasy/zone/serializer'

module DnsMadeEasy
  module CLI
    # Registered dry-cli command classes.
    module Commands
      # Zone-file management commands.
      module Zone
        # Validates a standard DNS zone file.
        class Validate < Base
          desc 'Validate a DNS zone file'

          argument :file, required: true, desc: 'Zone file path'

          def call(file:, **)
            configure_message_helpers
            result = DnsMadeEasy::Zone::Parser.new(::File.read(file)).call

            if result.success?
              record_count = result.value!.records.length
              MessageHelpers.success("Zone file is valid.\nRecords: #{record_count}")
            else
              MessageHelpers.error("Zone file is invalid.\n#{result.failure.join("\n")}")
              raise ArgumentError, 'zone file is invalid'
            end
          end

          private

          def configure_message_helpers
            MessageHelpers.stdout = @out
            MessageHelpers.stderr = @err
          end
        end

        # Formats a standard DNS zone file into canonical output.
        class Format < Base
          desc 'Format a DNS zone file'

          argument :file, required: true, desc: 'Zone file path'

          def call(file:, **)
            configure_message_helpers
            result = DnsMadeEasy::Zone::Parser.new(::File.read(file)).call

            if result.success?
              puts DnsMadeEasy::Zone::Serializer.new(result.value!)
            else
              MessageHelpers.error("Zone file is invalid.\n#{result.failure.join("\n")}")
              raise ArgumentError, 'zone file is invalid'
            end
          end

          private

          def configure_message_helpers
            MessageHelpers.stdout = @out
            MessageHelpers.stderr = @err
          end
        end
      end

      register 'zone' do |prefix|
        prefix.register 'validate', Zone::Validate
        prefix.register 'fmt', Zone::Format, aliases: ['format']
      end
    end
  end
end
