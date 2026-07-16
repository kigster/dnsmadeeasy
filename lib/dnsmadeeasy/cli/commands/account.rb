# frozen_string_literal: true

require 'dnsmadeeasy/api/client'
require 'dnsmadeeasy/cli/commands/base'

module DnsMadeEasy
  module CLI
    # Registered dry-cli command classes.
    module Commands
      # Dispatches existing DNS Made Easy API operations under `dme account`.
      class Account < Base
        RECORD_TYPES = %w[A AAAA ANAME CNAME HTTPRED MX NS PTR SOA SPF SRV TXT].freeze
        COMMON_OPTION_NAMES = %i[format credentials api_key api_secret record_type].freeze
        RECORD_LIST_OPERATIONS = %w[all records_for].freeze
        OPERATION_METADATA = {
          'all' => {
            usage: 'dme account all DOMAIN_NAME [--record-type=TYPE]',
            arguments: ['DOMAIN_NAME                         # Domain name to list records for'],
            options: ["--record-type=TYPE, -t TYPE       # Optional record type filter: (#{RECORD_TYPES.join('/')})"],
            summary: 'List records for a managed domain'
          },
          'records_for' => {
            usage: 'dme account records_for DOMAIN_NAME [--record-type=TYPE]',
            arguments: ['DOMAIN_NAME                         # Domain name to list records for'],
            options: ["--record-type=TYPE, -t TYPE       # Optional record type filter: (#{RECORD_TYPES.join('/')})"],
            summary: 'List records for a managed domain'
          },
          'domains' => {
            usage: 'dme account domains',
            arguments: [],
            options: [],
            summary: 'List managed domains'
          }
        }.freeze

        desc 'Execute DNS Made Easy account API operation'

        option :list, aliases: ['l'], type: :boolean, default: false, desc: 'List account operations'
        option :list_operations, type: :boolean, default: false, desc: 'List account operations'

        def self.public_operation_names
          DnsMadeEasy::Api::Client.public_operations
        end

        def self.build_operation_command(operation_name)
          operation_class = Class.new(AccountOperation)
          operation_class.operation_name = operation_name
          operation_class.operation_parameters = DnsMadeEasy::Api::Client.instance_method(operation_name).parameters
          operation_class.desc(operation_metadata(operation_name).fetch(:summary))
          operation_class.define_operation_arguments
          operation_class.define_record_type_option if RECORD_LIST_OPERATIONS.include?(operation_name)
          operation_class
        end

        def self.operation_help(operation_name)
          metadata = operation_metadata(operation_name)
          return unknown_operation_help(operation_name) unless metadata

          [
            'Command:',
            "  #{metadata.fetch(:usage)}",
            '',
            'Description:',
            "  #{metadata.fetch(:summary)}",
            *argument_help(metadata),
            *option_help(metadata)
          ].join("\n")
        end

        def self.operation_metadata(operation_name)
          normalized_operation_name = operation_name.to_s
          OPERATION_METADATA[normalized_operation_name] || introspected_operation_metadata(normalized_operation_name)
        end

        def self.introspected_operation_metadata(operation_name)
          return unless public_operation_names.include?(operation_name)

          method_parameters = DnsMadeEasy::Api::Client.instance_method(operation_name).parameters
          required_arguments = method_parameters.filter_map do |parameter_type, parameter_name|
            parameter_name.to_s.upcase if parameter_type == :req
          end

          {
            usage: (['dme account', operation_name] + required_arguments).join(' '),
            arguments: required_arguments.map { |argument_name| "#{argument_name.ljust(35)} # Required" },
            options: [],
            summary: "Execute #{operation_name}"
          }
        end

        def self.unknown_operation_help(operation_name)
          [
            "Error: account operation #{operation_name.inspect} is not valid.",
            'Hint: run `dme account --list` to see valid operations.'
          ].join("\n")
        end

        def self.argument_help(metadata)
          arguments = metadata.fetch(:arguments)
          return [] if arguments.empty?

          ['', 'Arguments:', *arguments.map { |argument| "  #{argument}" }]
        end

        def self.option_help(metadata)
          options = metadata.fetch(:options)
          return [] if options.empty?

          ['', 'Options:', *options.map { |option| "  #{option}" }]
        end

        def call(args: [], list: false, list_operations: false, **)
          reject_unknown_subcommand!(args) unless list || list_operations

          print_operations
        end

        private

        def reject_unknown_subcommand!(args)
          unknown_subcommand = Array(args).first
          return unless unknown_subcommand

          warn "Error: account operation #{unknown_subcommand.inspect} is not valid."
          warn 'Hint: run `dme account --help` to see valid operations.'
          raise ArgumentError, "account operation #{unknown_subcommand.inspect} is not valid"
        end

        def public_operations
          self.class.public_operation_names
        end

        def print_operations
          public_operations.each do |operation_name|
            metadata = self.class.operation_metadata(operation_name)
            summary = metadata.fetch(:summary)
            puts "#{operation_name.ljust(28)} #{summary}"
          end
        end
      end

      # Base command for generated account operation subcommands.
      class AccountOperation < Base
        class << self
          attr_accessor :operation_name,
                        :operation_parameters

          def define_operation_arguments
            required_operation_parameters.each do |parameter_name|
              argument parameter_name, required: true, desc: humanize_parameter_name(parameter_name)
            end
          end

          def define_record_type_option
            option :record_type, aliases: ['t'], values: Account::RECORD_TYPES, required: false,
                                 desc: 'Filter returned records by type'
          end

          def required_operation_parameters
            operation_parameters.filter_map do |parameter_type, parameter_name|
              parameter_name if parameter_type == :req
            end
          end

          def optional_operation_parameters
            operation_parameters.filter_map do |parameter_type, parameter_name|
              parameter_name if parameter_type == :opt && parameter_name != :options
            end
          end

          def humanize_parameter_name(parameter_name)
            parameter_name.to_s.tr('_', ' ')
          end
        end

        def call(format: nil, credentials: nil, api_key: nil, api_secret: nil, record_type: nil, **arguments)
          configure_authentication(credentials: credentials, api_key: api_key, api_secret: api_secret)
          result = DnsMadeEasy.client.public_send(self.class.operation_name, *operation_arguments(arguments))
          result = filter_records_by_type(result, record_type) if record_type && record_list_operation?
          print_result(result, format)
        end

        private

        def operation_arguments(arguments)
          self.class.required_operation_parameters.map { |parameter_name| arguments.fetch(parameter_name) } +
            self.class.optional_operation_parameters.filter_map { |parameter_name| arguments[parameter_name] }
        end

        def record_list_operation?
          Account::RECORD_LIST_OPERATIONS.include?(self.class.operation_name)
        end

        def filter_records_by_type(result, record_type)
          filtered_record_type = record_type.upcase
          return result unless result.respond_to?(:key?) && result.key?('data')

          filtered_result = result.dup
          filtered_result['data'] = result['data'].select { |record| record['type'] == filtered_record_type }
          filtered_result
        end

        def print_result(result, format)
          case result
          when NilClass
            puts 'No records returned.'
          when Hashie::Mash
            print_formatted(result.to_hash, format)
          else
            print_formatted(result, format)
          end
        end
      end

      register 'account', Account do |prefix|
        Account.public_operation_names.each do |operation_name|
          prefix.register operation_name, Account.build_operation_command(operation_name)
        end
      end
    end
  end
end
