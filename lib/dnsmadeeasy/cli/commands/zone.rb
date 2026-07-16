# frozen_string_literal: true

require 'dnsmadeeasy/cli/commands/base'
require 'dnsmadeeasy/cli/message_helpers'
require 'dnsmadeeasy/zone/diff'
require 'json'
require 'dnsmadeeasy/zone/parser'
require 'dnsmadeeasy/zone/plan_renderer'
require 'dnsmadeeasy/zone/remote_adapter'
require 'dnsmadeeasy/zone/serializer'
require 'yaml'

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

        # Exports DNS Made Easy records as canonical zone-file text.
        class Export < Base
          desc 'Export DNS Made Easy records as a canonical zone file'

          argument :domain, required: true, desc: 'Domain name'

          option :format, aliases: ['f'], values: %w[rfc json yaml], required: false,
                          desc: 'Export format: rfc, json, or yaml'
          option :output, required: false, desc: 'Output file path'
          option :ttl, required: false, desc: 'Default TTL for records missing provider TTL'
          option :include_apex_ns, type: :boolean, default: false, desc: 'Include apex NS records'

          def call(**options)
            configure_message_helpers
            configure_authentication(credentials: options[:credentials], api_key: options[:api_key],
                                     api_secret: options[:api_secret])

            domain = options.fetch(:domain)
            export_ttl = options[:ttl] || 300
            result = DnsMadeEasy::Zone::RemoteAdapter.new(
              DnsMadeEasy.client.records_for(domain),
              domain: domain,
              default_ttl: export_ttl
            ).call

            if result.success?
              export_records(
                domain,
                result.value!,
                format: options[:format] || 'rfc',
                output: options[:output],
                ttl: export_ttl,
                include_apex_ns: options[:include_apex_ns]
              )
            else
              MessageHelpers.error("Zone export failed.\n#{result.failure.join("\n")}")
              raise ArgumentError, 'zone export failed'
            end
          end

          private

          def export_records(domain, remote_records, format:, output:, ttl:, include_apex_ns:)
            remote_records.warnings.each { |warning| warn warning }
            zone_text = export_text(domain, remote_records, format: format, ttl: ttl, include_apex_ns: include_apex_ns)

            output ? ::File.write(output, zone_text) : puts(zone_text)
          end

          def export_text(domain, remote_records, format:, ttl:, include_apex_ns:)
            zone_file = zone_file(domain, remote_records, ttl: ttl)

            case format
            when 'json'
              JSON.pretty_generate(export_hash(zone_file))
            when 'yaml'
              export_hash(zone_file).to_yaml
            else
              DnsMadeEasy::Zone::Serializer.new(zone_file, omit_apex_ns: !include_apex_ns).to_s
            end
          end

          def zone_file(domain, remote_records, ttl:)
            DnsMadeEasy::Zone::File.new(
              origin: "#{domain.delete_suffix('.')}.",
              ttl: ttl,
              record_set: remote_records.record_set
            )
          end

          def export_hash(zone_file)
            {
              'origin' => zone_file.origin,
              'ttl' => zone_file.ttl,
              'records' => zone_file.sorted.map { |record| record_hash(record) }
            }
          end

          def record_hash(record)
            {
              'owner' => record.owner,
              'type' => record.type,
              'value' => record.value,
              'ttl' => record.ttl,
              'priority' => record.priority,
              'weight' => record.weight,
              'port' => record.port
            }.compact
          end

          def configure_message_helpers
            MessageHelpers.stdout = @out
            MessageHelpers.stderr = @err
          end
        end

        # Produces a non-destructive plan comparing a zone file to remote records.
        class Plan < Base
          desc 'Plan DNS changes for a zone file'

          argument :file, required: true, desc: 'Zone file path'

          option :domain, required: false, desc: 'Domain name'
          option :format, values: %w[text json], default: 'text', required: false, desc: 'Plan output format'

          def call(file:, domain: nil, format: 'text', credentials: nil, api_key: nil, api_secret: nil, **)
            configure_message_helpers
            configure_authentication(credentials: credentials, api_key: api_key, api_secret: api_secret)

            desired_result = DnsMadeEasy::Zone::Parser.new(::File.read(file)).call
            return fail_with('Zone file is invalid', desired_result.failure) if desired_result.failure?

            plan_domain = domain || desired_result.value!.origin
            remote_result = remote_records(plan_domain)
            return fail_with('Remote records are invalid', remote_result.failure) if remote_result.failure?

            plan = DnsMadeEasy::Zone::Diff.new(
              desired_records: desired_result.value!.records,
              remote_records: remote_result.value!.records
            ).call
            renderer = DnsMadeEasy::Zone::PlanRenderer.new(plan)

            puts(format == 'json' ? renderer.to_json : renderer.to_text)
          end

          private

          def remote_records(domain)
            DnsMadeEasy::Zone::RemoteAdapter.new(DnsMadeEasy.client.records_for(domain), domain: domain).call
          end

          def fail_with(message, errors)
            MessageHelpers.error("#{message}.\n#{errors.join("\n")}")
            raise ArgumentError, message.downcase
          end

          def configure_message_helpers
            MessageHelpers.stdout = @out
            MessageHelpers.stderr = @err
          end
        end
      end

      register 'zone' do |prefix|
        prefix.register 'validate', Zone::Validate
        prefix.register 'fmt', Zone::Format, aliases: ['format']
        prefix.register 'export', Zone::Export
        prefix.register 'plan', Zone::Plan
      end
    end
  end
end
