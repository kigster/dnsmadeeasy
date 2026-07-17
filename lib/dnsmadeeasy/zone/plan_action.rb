# frozen_string_literal: true

require 'dry/struct'
require 'dnsmadeeasy/types'
require 'dnsmadeeasy/zone/record'

module DnsMadeEasy
  module Zone
    # A single proposed zone-management action.
    class PlanAction < Dry::Struct
      transform_keys(&:to_sym)

      ACTION_TYPES = %w[create update skipped_create skipped_delete ambiguous].freeze

      attribute :action, Types::StrictString.enum(*ACTION_TYPES)
      attribute :record, Record.optional.default(nil)
      attribute :remote_record, Record.optional.default(nil)
      attribute :desired_record, Record.optional.default(nil)
      attribute :message, Types::OptionalString.default(nil)

      def sort_key
        [
          ACTION_TYPES.index(action),
          (record || desired_record || remote_record)&.sort_key || []
        ]
      end
    end
  end
end
