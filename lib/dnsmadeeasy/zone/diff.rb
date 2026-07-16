# frozen_string_literal: true

require 'dnsmadeeasy/zone/plan'

module DnsMadeEasy
  module Zone
    # Builds a conservative execution plan from desired and remote record sets.
    class Diff
      def initialize(desired_records:, remote_records:)
        @desired_records = desired_records
        @remote_records = remote_records
      end

      def call
        Plan.new(
          creates: create_actions,
          updates: update_actions,
          skipped_deletes: skipped_delete_actions,
          ambiguous: ambiguous_actions
        )
      end

      private

      attr_reader :desired_records,
                  :remote_records

      def create_actions
        missing_desired_records.map { |record| PlanAction.new(action: 'create', record: record) }
      end

      def update_actions
        changed_identity_pairs.filter_map do |_identity, pair|
          next unless pair.fetch(:desired).one? && pair.fetch(:remote).one?

          PlanAction.new(
            action: 'update',
            desired_record: pair.fetch(:desired).first,
            remote_record: pair.fetch(:remote).first
          )
        end
      end

      def skipped_delete_actions
        remote_only_records.map do |record|
          PlanAction.new(action: 'skipped_delete', record: record, message: 'Delete skipped by default')
        end
      end

      def ambiguous_actions
        changed_identity_pairs.filter_map do |_identity, pair|
          next if pair.fetch(:desired).one? && pair.fetch(:remote).one?

          PlanAction.new(
            action: 'ambiguous',
            desired_record: pair.fetch(:desired).first,
            remote_record: pair.fetch(:remote).first,
            message: 'Multiple records share the same owner/type identity'
          )
        end
      end

      def missing_desired_records
        desired_records - remote_records - changed_desired_records
      end

      def remote_only_records
        remote_records - desired_records - changed_remote_records
      end

      def changed_desired_records
        changed_identity_pairs.values.flat_map { |pair| pair.fetch(:desired) }
      end

      def changed_remote_records
        changed_identity_pairs.values.flat_map { |pair| pair.fetch(:remote) }
      end

      def changed_identity_pairs
        desired_by_identity.each_with_object({}) do |(identity, desired_group), pairs|
          remote_group = remote_by_identity.fetch(identity, [])
          next if remote_group.empty? || desired_group == remote_group

          pairs[identity] = { desired: desired_group, remote: remote_group }
        end
      end

      def desired_by_identity
        @desired_by_identity ||= desired_records.group_by { |record| identity(record) }
      end

      def remote_by_identity
        @remote_by_identity ||= remote_records.group_by { |record| identity(record) }
      end

      def identity(record)
        [record.owner, record.type]
      end
    end
  end
end
