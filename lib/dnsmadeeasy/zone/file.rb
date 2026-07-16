# frozen_string_literal: true

require 'dry/struct'
require 'dnsmadeeasy/types'
require 'dnsmadeeasy/zone/record_set'

module DnsMadeEasy
  module Zone
    # Parsed zone-file document with metadata needed for canonical output.
    class File < Dry::Struct
      transform_keys(&:to_sym)

      attribute :origin, Types::NonEmptyString
      attribute :ttl, Types::Ttl.default(300)
      attribute :record_set, RecordSet

      def records
        record_set.records
      end

      def sorted
        record_set.sorted
      end
    end
  end
end
