# frozen_string_literal: true

require 'json'

module DnsMadeEasy
  module Zone
    # Renders zone plans for humans and automation.
    class PlanRenderer
      def initialize(plan)
        @plan = plan
      end

      def to_text
        return "No changes.\n" if plan.empty?

        [
          section('Create', plan.creates),
          section('Update', plan.updates),
          section('Skipped Deletes', plan.skipped_deletes),
          section('Manual Review', plan.ambiguous)
        ].reject(&:empty?).join("\n")
      end

      def to_json(*)
        JSON.pretty_generate(plan_hash)
      end

      private

      attr_reader :plan

      def section(title, actions)
        return '' if actions.empty?

        ([title] + actions.sort_by(&:sort_key).map { |action| "  - #{action_line(action)}" }).join("\n")
      end

      def action_line(action)
        case action.action
        when 'create'
          record_line(action.record)
        when 'update'
          "#{record_line(action.remote_record)} -> #{record_line(action.desired_record)}"
        when 'skipped_delete'
          "#{record_line(action.record)} (#{action.message})"
        when 'ambiguous'
          "#{record_line(action.remote_record)} -> #{record_line(action.desired_record)} (#{action.message})"
        end
      end

      def record_line(record)
        [record.owner, record.type, record.value].compact.join(' ')
      end

      def plan_hash
        {
          creates: plan.creates.map { |action| action_hash(action) },
          updates: plan.updates.map { |action| action_hash(action) },
          skipped_deletes: plan.skipped_deletes.map { |action| action_hash(action) },
          ambiguous: plan.ambiguous.map { |action| action_hash(action) }
        }
      end

      def action_hash(action)
        {
          action: action.action,
          record: record_hash(action.record),
          remote_record: record_hash(action.remote_record),
          desired_record: record_hash(action.desired_record),
          message: action.message
        }.compact
      end

      def record_hash(record)
        return unless record

        {
          owner: record.owner,
          type: record.type,
          value: record.value,
          ttl: record.ttl,
          priority: record.priority,
          weight: record.weight,
          port: record.port
        }.compact
      end
    end
  end
end
