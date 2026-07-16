# frozen_string_literal: true

require 'dry/monads'
require 'dnsmadeeasy/zone/apply_result'
require 'tty-spinner'

module DnsMadeEasy
  module Zone
    # Executes safe plan actions against DNS Made Easy.
    class ApplyExecutor
      include Dry::Monads[:result]

      MODES = %i[merge add_only delete_only].freeze
      DEFAULT_MAX_THREADS = 4

      def initialize(client:, domain:, plan:, remote_records:, mode: :merge, spinner_factory: nil, spinner_output: $stderr,
                     max_threads: DEFAULT_MAX_THREADS)
        @client = client
        @domain = domain
        @plan = plan
        @remote_records = remote_records
        @mode = mode
        @spinner_factory = spinner_factory || default_spinner_factory(spinner_output)
        @max_threads = [max_threads.to_i, 1].max
      end

      def executable_action_count
        executable_actions.length
      end

      def call
        return Failure(["Unsupported apply mode: #{mode}"]) unless MODES.include?(mode)

        applied_actions, failed_actions = execute_actions(executable_actions)

        Success(ApplyResult.new(
                  applied_actions: applied_actions,
                  failed_actions: failed_actions,
                  skipped_actions: skipped_actions
                ))
      end

      private

      attr_reader :client,
                  :domain,
                  :plan,
                  :remote_records,
                  :mode,
                  :spinner_factory,
                  :max_threads

      def executable_actions
        sort_actions(
          case mode
          when :add_only
            plan.creates
          when :delete_only
            deletable_actions
          else
            plan.creates + plan.updates
          end
        )
      end

      def skipped_actions
        plan.actions - executable_actions
      end

      def execute_actions(actions)
        return [[], []] if actions.empty?

        applied_actions = []
        failed_actions = []
        outcome_mutex = Mutex.new
        spinner_group = spinner_factory.call("Applying #{actions.length} DNS action(s)")

        action_chunks(actions).each_with_index do |chunk, index|
          register_chunk(spinner_group, chunk, index, outcome_mutex, applied_actions, failed_actions)
        end

        spinner_group.auto_spin

        [ordered_actions(applied_actions), ordered_actions(failed_actions)]
      end

      def register_chunk(spinner_group, chunk, index, outcome_mutex, applied_actions, failed_actions)
        spinner_group.register("[:spinner] worker #{index + 1}: #{chunk.length} action(s)") do |spinner|
          failed = execute_chunk(chunk, outcome_mutex, applied_actions, failed_actions)
          failed ? spinner.error : spinner.success
        end
      end

      def execute_chunk(chunk, outcome_mutex, applied_actions, failed_actions)
        failed = false
        chunk.each do |indexed_action|
          failed = true if execute_indexed_action(indexed_action, outcome_mutex, applied_actions, failed_actions)
        end
        failed
      end

      def execute_indexed_action(indexed_action, outcome_mutex, applied_actions, failed_actions)
        execute_action(indexed_action.fetch(:action))
        outcome_mutex.synchronize { applied_actions << indexed_action }
        false
      rescue StandardError
        outcome_mutex.synchronize { failed_actions << indexed_action }
        true
      end

      def action_chunks(actions)
        indexed_actions = actions.each_with_index.map { |action, index| { action: action, index: index } }
        worker_count = [indexed_actions.length, max_threads].min
        chunk_size = (indexed_actions.length.to_f / worker_count).ceil
        indexed_actions.each_slice(chunk_size).to_a
      end

      def ordered_actions(indexed_actions)
        indexed_actions.sort_by { |indexed_action| indexed_action.fetch(:index) }.map { |indexed_action| indexed_action.fetch(:action) }
      end

      def execute_action(action)
        case action.action
        when 'create'
          create_record(action.record)
        when 'update'
          update_record(action)
        when 'skipped_delete'
          delete_record(action.record)
        end
      end

      def create_record(record)
        client.create_record(domain, api_owner(record), record.type, record.value, record_options(record))
      end

      def update_record(action)
        provider_id = provider_id_for(action.remote_record)
        client.update_record(domain, provider_id, api_owner(action.desired_record), action.desired_record.type,
                             action.desired_record.value, record_options(action.desired_record))
      end

      def delete_record(record)
        client.delete_record(domain, provider_id_for(record))
      end

      def provider_id_for(record)
        provider_record = remote_records.provider_records.find { |candidate| candidate.record == record }
        raise KeyError, "No provider id for #{record.owner} #{record.type}" unless provider_record&.provider_id

        provider_record.provider_id
      end

      def deletable_actions
        plan.skipped_deletes.reject { |action| protected_delete?(action.record) }
      end

      def sort_actions(actions)
        actions.sort_by(&:sort_key)
      end

      def protected_delete?(record)
        record.type == 'SOA' || (record.owner == '@' && record.type == 'NS')
      end

      def api_owner(record)
        record.owner == '@' ? '' : record.owner
      end

      def record_options(record)
        options = { 'ttl' => record.ttl }
        options['mxLevel'] = record.priority if record.type == 'MX'
        options.merge!('priority' => record.priority, 'weight' => record.weight, 'port' => record.port) if record.type == 'SRV'
        options.compact
      end

      def default_spinner_factory(spinner_output)
        lambda do |message|
          TTY::Spinner::Multi.new(
            "[:spinner] #{message}",
            output: spinner_output,
            clear: true,
            hide_cursor: true
          )
        end
      end
    end
  end
end
