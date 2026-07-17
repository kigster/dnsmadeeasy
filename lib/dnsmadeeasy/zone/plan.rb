# frozen_string_literal: true

require 'dry/struct'
require 'dnsmadeeasy/types'
require 'dnsmadeeasy/zone/plan_action'

module DnsMadeEasy
  module Zone
    # Diff result describing intended changes without applying them.
    class Plan < Dry::Struct
      transform_keys(&:to_sym)

      attribute :creates, Types::Array.of(PlanAction).default([].freeze)
      attribute :updates, Types::Array.of(PlanAction).default([].freeze)
      attribute :skipped_creates, Types::Array.of(PlanAction).default([].freeze)
      attribute :skipped_deletes, Types::Array.of(PlanAction).default([].freeze)
      attribute :ambiguous, Types::Array.of(PlanAction).default([].freeze)

      def actions
        [creates, updates, skipped_creates, skipped_deletes, ambiguous].flatten.sort_by(&:sort_key)
      end

      def empty?
        actions.empty?
      end
    end
  end
end
