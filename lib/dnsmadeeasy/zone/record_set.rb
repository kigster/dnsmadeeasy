# frozen_string_literal: true

require 'dry/struct'
require 'dnsmadeeasy/zone/record'

module DnsMadeEasy
  module Zone
    # Deterministically ordered collection of zone records.
    class RecordSet < Dry::Struct
      transform_keys(&:to_sym)

      attribute :records, Types::Array.of(Record).default([].freeze)

      def sorted
        records.sort_by(&:sort_key)
      end

      def include?(record)
        records.include?(record)
      end
    end
  end
end
