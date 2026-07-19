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
          ambiguous: []
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
        group_creates = group_deltas.flat_map { |delta| delta.fetch(:creates) }
        (missing_desired_records + group_creates).map do |record|
          PlanAction.new(action: 'create', record: record)
        end
      end

      def update_actions
        group_deltas.flat_map do |delta|
          delta.fetch(:updates).map do |desired, remote|
            PlanAction.new(
              action: 'update',
              desired_record: update_payload(desired, remote),
              remote_record: remote
            )
          end
        end
      end

      # When TTLs are not compared, an update must not modify the remote TTL
      # as a side effect, so the desired record inherits it.
      def update_payload(desired, remote)
        return desired if compare_ttl

        desired.new(ttl: remote.ttl)
      end

      def skipped_delete_actions
        group_deletes = group_deltas.flat_map { |delta| delta.fetch(:deletes) }
        (remote_only_records + group_deletes).map do |record|
          PlanAction.new(action: 'skipped_delete', record: record, message: 'Delete skipped by default')
        end
      end

      # Individual records within an RRset carry no identity — only the set of
      # values is meaningful in DNS. Within a changed (owner, type) group,
      # records whose values match on both sides are unchanged; the rest are
      # paired in sorted-value order as updates. Excess desired records become
      # creates; excess remote records become (skipped) deletes. The end state
      # is exact regardless of how records are paired.
      def group_deltas
        @group_deltas ||= changed_identity_pairs.values.map do |pair|
          desired_changed = multiset_subtract(pair.fetch(:desired), pair.fetch(:remote)).sort_by(&:value)
          remote_changed  = multiset_subtract(pair.fetch(:remote), pair.fetch(:desired)).sort_by(&:value)
          paired          = [desired_changed.length, remote_changed.length].min

          {
            updates: desired_changed.first(paired).zip(remote_changed.first(paired)),
            creates: desired_changed.drop(paired),
            deletes: remote_changed.drop(paired)
          }
        end
      end

      # Records from +records+ that have no value-level counterpart in
      # +others+, honoring duplicates (a multiset difference).
      def multiset_subtract(records, others)
        remaining = comparison_keys(others).tally
        records.reject do |record|
          key = comparison_key(record)
          next false unless remaining[key].to_i.positive?

          remaining[key] -= 1
          true
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
