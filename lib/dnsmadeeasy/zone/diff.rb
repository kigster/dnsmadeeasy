# frozen_string_literal: true

require 'dnsmadeeasy/zone/plan'

module DnsMadeEasy
  module Zone
    # Builds a conservative execution plan from desired and remote record sets.
    # TTL-only differences are ignored unless compare_ttl is true.
    class Diff
      def initialize(desired_records:, remote_records:, compare_ttl: false)
        @provider_managed_records, @desired_records = desired_records.partition { |record| provider_managed?(record) }
        @remote_records = remote_records
        @compare_ttl = compare_ttl
      end

      def call
        Plan.new(
          creates: create_actions,
          updates: update_actions,
          skipped_creates: skipped_create_actions,
          skipped_deletes: skipped_delete_actions,
          ambiguous: ambiguous_actions
        )
      end

      private

      attr_reader :desired_records,
                  :provider_managed_records,
                  :remote_records,
                  :compare_ttl

      # Apex NS records are owned by DNS Made Easy: the API neither returns
      # nor accepts them, so they are excluded from the diff and reported.
      def provider_managed?(record)
        record.owner == '@' && record.type == 'NS'
      end

      def skipped_create_actions
        provider_managed_records.map do |record|
          PlanAction.new(action: 'skipped_create', record: record,
                         message: 'Apex NS records are managed by the DNS provider')
        end
      end

      def create_actions
        missing_desired_records.map { |record| PlanAction.new(action: 'create', record: record) }
      end

      def update_actions
        changed_identity_pairs.filter_map do |_identity, pair|
          next unless pair.fetch(:desired).one? && pair.fetch(:remote).one?

          PlanAction.new(
            action: 'update',
            desired_record: update_payload(pair),
            remote_record: pair.fetch(:remote).first
          )
        end
      end

      # When TTLs are not compared, an update must not modify the remote TTL
      # as a side effect, so the desired record inherits it.
      def update_payload(pair)
        desired = pair.fetch(:desired).first
        return desired if compare_ttl

        desired.new(ttl: pair.fetch(:remote).first.ttl)
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
            message: 'Multiple records share the same owner/type identity ' \
                     "(desired: #{pair.fetch(:desired).length}, remote: #{pair.fetch(:remote).length})"
          )
        end
      end

      def missing_desired_records
        desired_records.reject { |record| remote_keys.include?(comparison_key(record)) } - changed_desired_records
      end

      def remote_only_records
        remote_records.reject { |record| desired_keys.include?(comparison_key(record)) } - changed_remote_records
      end

      def changed_desired_records
        changed_identity_pairs.values.flat_map { |pair| pair.fetch(:desired) }
      end

      def changed_remote_records
        changed_identity_pairs.values.flat_map { |pair| pair.fetch(:remote) }
      end

      def changed_identity_pairs
        @changed_identity_pairs ||= desired_by_identity.each_with_object({}) do |(identity, desired_group), pairs|
          remote_group = remote_by_identity.fetch(identity, [])
          next if remote_group.empty? || same_record_multiset?(desired_group, remote_group)

          pairs[identity] = { desired: desired_group, remote: remote_group }
        end
      end

      # Groups match regardless of order: the API returns records in
      # arbitrary order while zone files are sorted.
      def same_record_multiset?(desired_group, remote_group)
        comparison_keys(desired_group).tally == comparison_keys(remote_group).tally
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

      def desired_keys
        @desired_keys ||= comparison_keys(desired_records)
      end

      def remote_keys
        @remote_keys ||= comparison_keys(remote_records)
      end

      def comparison_keys(records)
        records.map { |record| comparison_key(record) }
      end

      def comparison_key(record)
        key = [record.owner, record.type, record.value, record.priority, record.weight, record.port]
        compare_ttl ? key << record.ttl : key
      end
    end
  end
end
