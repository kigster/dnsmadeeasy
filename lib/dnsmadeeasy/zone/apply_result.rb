# frozen_string_literal: true

require 'dry/struct'
require 'dnsmadeeasy/types'
require 'dnsmadeeasy/zone/plan_action'

module DnsMadeEasy
  module Zone
    # Result of executing a zone plan.
    class ApplyResult < Dry::Struct
      transform_keys(&:to_sym)

      attribute :applied_actions, Types::Array.of(PlanAction).default([].freeze)
      attribute :failed_actions, Types::Array.of(PlanAction).default([].freeze)
      attribute :skipped_actions, Types::Array.of(PlanAction).default([].freeze)

      def success?
        failed_actions.empty?
      end
    end
  end
end
