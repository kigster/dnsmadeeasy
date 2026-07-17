# frozen_string_literal: true

require 'dnsmadeeasy/cli/commands/base'
require 'dnsmadeeasy/cli/input'
require 'dnsmadeeasy/cli/message_helpers'
require 'dnsmadeeasy/zone/aname_flattener'
require 'dnsmadeeasy/zone/apply_executor'
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
            result = DnsMadeEasy::Zone::Parser.new(::File.read(file)).call

            if result.success?
              record_count = result.value!.records.length
              success("Zone file is valid.\nRecords: #{record_count}")
            else
              warning("Zone file is invalid.\n#{result.failure.join("\n")}")
              raise ReportedError, 'zone file is invalid'
            end
          end
        end

        # Formats a standard DNS zone file into canonical output.
        class Format < Base
          desc 'Format a DNS zone file'

          argument :file, required: true, desc: 'Zone file path'

          def call(file:, **)
            result = DnsMadeEasy::Zone::Parser.new(::File.read(file)).call

            if result.success?
              puts DnsMadeEasy::Zone::Serializer.new(result.value!)
              success("Zone file formatted.\nRecords: #{result.value!.records.length}")
            else
              error("Zone file is invalid.\n#{result.failure.join("\n")}")
              raise ReportedError, 'zone file is invalid'
            end
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
          option :strict_rfc, type: :boolean, default: false,
                              desc: 'Flatten ANAME records into resolved A records (RFC-portable output)'

          def call(**options)
            configure_authentication(credentials: options[:credentials], api_key: options[:api_key],
                                     api_secret: options[:api_secret])

            domain = options.fetch(:domain)
            export_ttl = options[:ttl] || 300
            result = DnsMadeEasy::Zone::RemoteAdapter.new(
              DnsMadeEasy.client.records_for(domain),
              domain: domain,
              default_ttl: export_ttl
            ).call
            fail_export(result.failure) if result.failure?

            records_result = export_ready_records(result.value!, strict_rfc: options[:strict_rfc])
            fail_export(records_result.failure) if records_result.failure?

            records, warnings = records_result.value!
            export_records(
              domain,
              records,
              warnings: warnings,
              format: options[:format] || 'rfc',
              output: options[:output],
              ttl: export_ttl,
              include_apex_ns: options[:include_apex_ns]
            )
            success(
              "Zone export complete.\nDomain: #{domain}\nRecords: #{records.length}\n" \
              "Destination: #{options[:output] || 'STDOUT'}"
            )
          end

          private

          def fail_export(errors)
            error("Zone export failed.\n#{errors.join("\n")}")
            raise ReportedError, 'zone export failed'
          end

          def export_ready_records(remote_records, strict_rfc:)
            return Dry::Monads::Success([remote_records.records, remote_records.warnings]) unless strict_rfc

            DnsMadeEasy::Zone::AnameFlattener.new(remote_records.records).call.fmap do |(records, notices)|
              [records, remote_records.warnings + notices]
            end
          end

          def export_records(domain, records, warnings:, format:, output:, ttl:, include_apex_ns:)
            warnings.each { |warning| warn warning }
            zone_text = export_text(domain, records, format: format, ttl: ttl, include_apex_ns: include_apex_ns)

            output ? ::File.write(output, zone_text) : puts(zone_text)
          end

          def export_text(domain, records, format:, ttl:, include_apex_ns:)
            zone_file = zone_file(domain, records, ttl: ttl)

            case format
            when 'json'
              JSON.pretty_generate(export_hash(zone_file))
            when 'yaml'
              export_hash(zone_file).to_yaml
            else
              DnsMadeEasy::Zone::Serializer.new(zone_file, omit_apex_ns: !include_apex_ns).to_s
            end
          end

          def zone_file(domain, records, ttl:)
            DnsMadeEasy::Zone::File.new(
              origin: "#{domain.delete_suffix('.')}.",
              ttl: dominant_ttl(records, fallback: ttl),
              record_set: DnsMadeEasy::Zone::RecordSet.new(records: records)
            )
          end

          # $TTL is the most common record TTL so the export stays faithful
          # while keeping explicit per-record TTLs to a minimum.
          def dominant_ttl(records, fallback:)
            records.map(&:ttl).tally.max_by { |ttl, count| [count, -ttl] }&.first || fallback
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
        end

        # Produces a non-destructive plan comparing a zone file to remote records.
        class Plan < Base
          desc 'Plan DNS changes for a zone file'

          argument :file, required: true, desc: 'Zone file path'

          option :domain, required: false, desc: 'Domain name'
          option :format, values: %w[text json], default: 'text', required: false, desc: 'Plan output format'
          option :diff_ttl, type: :boolean, default: false, desc: 'Treat TTL-only differences as updates'

          def call(file:, domain: nil, format: 'text', diff_ttl: false, credentials: nil, api_key: nil, api_secret: nil, **)
            configure_authentication(credentials: credentials, api_key: api_key, api_secret: api_secret)

            desired_result = DnsMadeEasy::Zone::Parser.new(::File.read(file)).call
            return fail_with('Zone file is invalid', desired_result.failure) if desired_result.failure?

            plan_domain = domain || desired_result.value!.origin
            remote_result = remote_records(plan_domain)
            return fail_with('Remote records are invalid', remote_result.failure) if remote_result.failure?

            plan = DnsMadeEasy::Zone::Diff.new(
              desired_records: desired_result.value!.records,
              remote_records: remote_result.value!.records,
              compare_ttl: diff_ttl
            ).call
            renderer = DnsMadeEasy::Zone::PlanRenderer.new(plan)

            puts(format == 'json' ? renderer.to_json : renderer.to_text)
            success(plan_summary(plan_domain, plan))
          end

          private

          def plan_summary(domain, plan)
            [
              "Zone plan complete for #{domain}.",
              "Creates: #{plan.creates.length}, Updates: #{plan.updates.length}",
              "Skipped creates: #{plan.skipped_creates.length}, Skipped deletes: #{plan.skipped_deletes.length}",
              "Manual review: #{plan.ambiguous.length}"
            ].join("\n")
          end

          def remote_records(domain)
            DnsMadeEasy::Zone::RemoteAdapter.new(DnsMadeEasy.client.records_for(domain), domain: domain).call
          end

          def fail_with(message, errors)
            error("#{message}.\n#{errors.join("\n")}")
            raise ReportedError, message.downcase
          end
        end

        # Applies a reviewed zone plan safely.
        class Apply < Base
          desc 'Apply DNS changes for a zone file'

          argument :file, required: true, desc: 'Zone file path'

          option :domain, required: false, desc: 'Domain name'
          option :yes, aliases: ['y'], type: :boolean, default: false, desc: 'Apply without confirmation prompt'
          option :add_only, aliases: ['a'], type: :boolean, default: false, desc: 'Only add missing records'
          option :delete_only, aliases: ['d'], type: :boolean, default: false, desc: 'Only apply deletions'
          option :merge, aliases: ['m'], type: :boolean, default: true, desc: 'Merge creates and updates'
          option :diff_ttl, type: :boolean, default: false, desc: 'Treat TTL-only differences as updates'

          def call(**options)
            configure_authentication(credentials: options[:credentials], api_key: options[:api_key],
                                     api_secret: options[:api_secret])

            plan_context = build_plan_context(options.fetch(:file), options[:domain], compare_ttl: options[:diff_ttl])
            return fail_with('Zone apply failed', plan_context.failure) if plan_context.failure?

            mode = apply_mode(options)
            executor = DnsMadeEasy::Zone::ApplyExecutor.new(
              client: DnsMadeEasy.client,
              domain: plan_context.value!.fetch(:domain),
              plan: plan_context.value!.fetch(:plan),
              remote_records: plan_context.value!.fetch(:remote_records),
              mode: mode,
              spinner_output: @err
            )
            executable_count = executor.executable_action_count
            confirm!(executable_count) unless options[:yes]

            result = executor.call
            return fail_with('Zone apply failed', result.failure) if result.failure?

            print_apply_summary(plan_context.value!.fetch(:domain), result.value!)
          end

          private

          def build_plan_context(file, domain, compare_ttl: false)
            desired_result = DnsMadeEasy::Zone::Parser.new(::File.read(file)).call
            return desired_result if desired_result.failure?

            plan_domain = domain || desired_result.value!.origin
            remote_result = DnsMadeEasy::Zone::RemoteAdapter.new(DnsMadeEasy.client.records_for(plan_domain),
                                                                 domain: plan_domain).call
            return remote_result if remote_result.failure?

            plan = DnsMadeEasy::Zone::Diff.new(
              desired_records: desired_result.value!.records,
              remote_records: remote_result.value!.records,
              compare_ttl: compare_ttl
            ).call

            Dry::Monads::Success(domain: plan_domain, plan: plan, remote_records: remote_result.value!)
          end

          def apply_mode(options)
            return :add_only if options[:add_only]
            return :delete_only if options[:delete_only]

            :merge
          end

          def confirm!(executable_count)
            warn "Apply #{executable_count} action(s)? Type yes to continue:"
            response = DnsMadeEasy::CLI::Input.stdin.gets.to_s.strip
            return if response == 'yes'

            raise ArgumentError, 'zone apply cancelled'
          end

          def print_apply_summary(domain, result)
            summary = "Zone apply complete for #{domain}.\n" \
                      "Applied: #{result.applied_actions.length}\n" \
                      "Failed: #{result.failed_actions.length}\n" \
                      "Skipped: #{result.skipped_actions.length}"

            result.failed_actions.empty? ? success(summary) : warning(summary)
          end

          def fail_with(message, errors)
            error("#{message}.\n#{errors.join("\n")}")
            raise ReportedError, message.downcase
          end
        end
      end

      register 'zone' do |prefix|
        prefix.register 'validate', Zone::Validate
        prefix.register 'fmt', Zone::Format, aliases: ['format']
        prefix.register 'export', Zone::Export
        prefix.register 'plan', Zone::Plan
        prefix.register 'apply', Zone::Apply
      end
    end
  end
end
