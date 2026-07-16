# frozen_string_literal: true

require 'dry/struct'
require 'dnsmadeeasy/types'
require 'dnsmadeeasy/zone/provider_record'
require 'dnsmadeeasy/zone/record_set'

module DnsMadeEasy
  module Zone
    # Provider records plus non-fatal warnings from remote conversion.
    class RemoteRecords < Dry::Struct
      transform_keys(&:to_sym)

      attribute :provider_records, Types::Array.of(ProviderRecord).default([].freeze)
      attribute :warnings, Types::Array.of(Types::StrictString).default([].freeze)

      def records
        provider_records.map(&:record)
      end

      def record_set
        RecordSet.new(records: records)
      end
    end
  end
end
