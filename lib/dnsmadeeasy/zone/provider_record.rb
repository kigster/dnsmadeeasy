# frozen_string_literal: true

require 'dry/struct'
require 'dnsmadeeasy/types'
require 'dnsmadeeasy/zone/record'

module DnsMadeEasy
  module Zone
    # Associates provider metadata with a provider-neutral DNS record.
    class ProviderRecord < Dry::Struct
      transform_keys(&:to_sym)

      attribute :record, Record
      attribute :provider_id, Types::Coercible::Integer.optional.default(nil)
      attribute :source_id, Types::OptionalString.default(nil)
    end
  end
end
