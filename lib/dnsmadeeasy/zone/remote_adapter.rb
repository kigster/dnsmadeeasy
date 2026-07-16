# frozen_string_literal: true

require 'dry/monads'
require 'dnsmadeeasy/zone/provider_record'
require 'dnsmadeeasy/zone/record'
require 'dnsmadeeasy/zone/remote_records'

module DnsMadeEasy
  module Zone
    # Converts DNS Made Easy API record hashes into provider-neutral zone records.
    class RemoteAdapter
      include Dry::Monads[:result]

      SUPPORTED_RECORD_TYPES = Types::DNS_RECORD_TYPES.freeze
      SOURCE_ID = 'dns-made-easy'

      def initialize(response, domain:, default_ttl: 300)
        @response = response
        @domain = domain
        @default_ttl = default_ttl
      end

      def call
        provider_records = []
        warnings = []

        remote_records.each do |remote_record|
          if remote_record['type'] == 'HTTPRED'
            warnings << omitted_httpred_warning(remote_record)
          elsif SUPPORTED_RECORD_TYPES.include?(remote_record['type'])
            provider_records << provider_record(remote_record)
          else
            return Failure(["Unsupported DNS Made Easy record type: #{remote_record['type']}"])
          end
        end

        Success(RemoteRecords.new(provider_records: provider_records, warnings: warnings))
      rescue Dry::Struct::Error => e
        Failure([e.message])
      end

      private

      attr_reader :response,
                  :domain,
                  :default_ttl

      def remote_records
        response.fetch('data', [])
      end

      def provider_record(remote_record)
        ProviderRecord.new(
          record: zone_record(remote_record),
          provider_id: remote_record['id'],
          source_id: SOURCE_ID
        )
      end

      def zone_record(remote_record)
        Record.new(
          owner: owner(remote_record),
          type: remote_record['type'],
          value: value(remote_record),
          ttl: remote_record['ttl'] || default_ttl,
          priority: remote_record['mxLevel'] || remote_record['priority'],
          weight: remote_record['weight'],
          port: remote_record['port']
        )
      end

      def owner(remote_record)
        name = remote_record['name'].to_s
        return '@' if name.empty? || name == domain || name == domain.delete_suffix('.')

        name.delete_suffix(".#{domain.delete_suffix('.')}")
      end

      def value(remote_record)
        record_value = remote_record['value']
        return record_value unless remote_record['type'] == 'TXT'
        return record_value unless record_value.start_with?('"') && record_value.end_with?('"')

        record_value[1...-1]
      end

      def omitted_httpred_warning(remote_record)
        record_name = remote_record['name'].to_s.empty? ? '@' : remote_record['name']
        "Omitted HTTPRED record #{record_name} -> #{remote_record['value']}"
      end
    end
  end
end
