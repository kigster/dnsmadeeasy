# frozen_string_literal: true

require 'dry/struct'
require 'dnsmadeeasy/types'

module DnsMadeEasy
  module Zone
    # Provider-neutral DNS record value object.
    class Record < Dry::Struct
      transform_keys(&:to_sym)

      attribute :owner, Types::NonEmptyString
      attribute :type, Types::RecordType
      attribute :value, Types::NonEmptyString
      attribute :ttl, Types::Ttl.default(300)
      attribute :priority, Types::OptionalInteger.default(nil)
      attribute :weight, Types::OptionalInteger.default(nil)
      attribute :port, Types::OptionalInteger.default(nil)

      def sort_key
        [
          normalized_owner,
          type_order,
          type,
          priority || -1,
          weight || -1,
          port || -1,
          value,
          ttl
        ]
      end

      private

      def normalized_owner
        owner == '@' ? '' : owner
      end

      def type_order
        Types::DNS_RECORD_TYPES.index(type) || Types::DNS_RECORD_TYPES.length
      end
    end
  end
end
