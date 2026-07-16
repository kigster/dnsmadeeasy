# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers
RSpec.describe DnsMadeEasy::Zone::ApplyExecutor do
  describe '#call' do
    subject(:result) do
      described_class.new(
        client: client,
        domain: domain,
        plan: plan,
        remote_records: remote_records,
        mode: mode,
        spinner_factory: spinner_factory
      ).call
    end

    let(:domain) { 'example.com' }
    let(:client) { instance_double(DnsMadeEasy::Api::Client) }
    let(:spinner_factory) { ->(_) { spinner_group } }
    let(:spinner_group) { fake_spinner_group_class.new }
    let(:fake_spinner_group_class) do
      Class.new do
        def initialize
          @jobs = []
        end

        def register(*, &block)
          @jobs << block
        end

        def auto_spin
          @jobs.each { |job| job.call(fake_spinner) }
        end

        private

        def fake_spinner
          @fake_spinner ||= Class.new do
            def success; end

            def error; end
          end.new
        end
      end
    end
    let(:mode) { :merge }
    let(:apex_a) { DnsMadeEasy::Zone::Record.new(owner: '@', type: 'A', value: '203.0.113.10', ttl: 300) }
    let(:www_cname) { DnsMadeEasy::Zone::Record.new(owner: 'www', type: 'CNAME', value: '@', ttl: 300) }
    let(:old_www_a) { DnsMadeEasy::Zone::Record.new(owner: 'www', type: 'A', value: '203.0.113.20', ttl: 300) }
    let(:new_www_a) { DnsMadeEasy::Zone::Record.new(owner: 'www', type: 'A', value: '203.0.113.21', ttl: 300) }
    let(:apex_ns) { DnsMadeEasy::Zone::Record.new(owner: '@', type: 'NS', value: 'ns1.dnsmadeeasy.com.', ttl: 300) }
    let(:delegated_ns) { DnsMadeEasy::Zone::Record.new(owner: 'delegated', type: 'NS', value: 'ns1.example.net.', ttl: 300) }
    let(:create_action) { DnsMadeEasy::Zone::PlanAction.new(action: 'create', record: www_cname) }
    let(:update_action) do
      DnsMadeEasy::Zone::PlanAction.new(action: 'update', remote_record: old_www_a, desired_record: new_www_a)
    end
    let(:apex_ns_delete_action) { DnsMadeEasy::Zone::PlanAction.new(action: 'skipped_delete', record: apex_ns) }
    let(:delegated_ns_delete_action) { DnsMadeEasy::Zone::PlanAction.new(action: 'skipped_delete', record: delegated_ns) }
    let(:plan) do
      DnsMadeEasy::Zone::Plan.new(
        creates: [create_action],
        updates: [update_action],
        skipped_deletes: [apex_ns_delete_action, delegated_ns_delete_action]
      )
    end
    let(:remote_records) do
      DnsMadeEasy::Zone::RemoteRecords.new(
        provider_records: [
          DnsMadeEasy::Zone::ProviderRecord.new(record: old_www_a, provider_id: 20),
          DnsMadeEasy::Zone::ProviderRecord.new(record: apex_ns, provider_id: 30),
          DnsMadeEasy::Zone::ProviderRecord.new(record: delegated_ns, provider_id: 40)
        ]
      )
    end

    before do
      allow(client).to receive(:create_record)
      allow(client).to receive(:update_record)
      allow(client).to receive(:delete_record)
    end

    context 'with merge mode' do
      it { is_expected.to be_success }

      it 'creates missing records' do
        expect(client).to receive(:create_record).with(domain, 'www', 'CNAME', '@', hash_including('ttl' => 300))

        result
      end

      it 'updates changed records' do
        expect(client).to receive(:update_record).with(
          domain,
          20,
          'www',
          'A',
          '203.0.113.21',
          hash_including('ttl' => 300)
        )

        result
      end

      it 'does not delete records' do
        expect(client).not_to receive(:delete_record)

        result
      end

      describe 'apply result' do
        subject(:apply_result) { result.value! }

        its(:applied_actions) { is_expected.to contain_exactly(create_action, update_action) }
        its(:skipped_actions) { is_expected.to contain_exactly(apex_ns_delete_action, delegated_ns_delete_action) }
        its(:failed_actions) { is_expected.to be_empty }
      end
    end

    context 'with add-only mode' do
      let(:mode) { :add_only }

      it 'creates missing records' do
        expect(client).to receive(:create_record).with(domain, 'www', 'CNAME', '@', hash_including('ttl' => 300))

        result
      end

      it 'does not update records' do
        expect(client).not_to receive(:update_record)

        result
      end

      it 'does not delete records' do
        expect(client).not_to receive(:delete_record)

        result
      end
    end

    context 'with delete-only mode' do
      let(:mode) { :delete_only }

      it 'deletes delegated records while preserving protected apex NS records' do
        expect(client).to receive(:delete_record).with(domain, 40)
        expect(client).not_to receive(:delete_record).with(domain, 30)

        result
      end
    end

    context 'with an unsupported mode' do
      let(:mode) { :unsupported }

      it { is_expected.to be_failure }
      its(:failure) { is_expected.to include('Unsupported apply mode: unsupported') }
    end

    context 'when an API call fails' do
      before do
        allow(client).to receive(:create_record).and_raise(StandardError, 'api failed')
      end

      describe 'apply result' do
        subject(:apply_result) { result.value! }

        its(:applied_actions) { is_expected.to contain_exactly(update_action) }
        its(:failed_actions) { is_expected.to contain_exactly(create_action) }
      end
    end
  end

  describe '#executable_action_count' do
    subject(:executor) do
      described_class.new(client: client, domain: domain, plan: plan, remote_records: remote_records, mode: mode)
    end

    let(:client) { instance_double(DnsMadeEasy::Api::Client) }
    let(:domain) { 'example.com' }
    let(:mode) { :merge }
    let(:record) { DnsMadeEasy::Zone::Record.new(owner: 'www', type: 'CNAME', value: '@') }
    let(:plan) do
      DnsMadeEasy::Zone::Plan.new(creates: [DnsMadeEasy::Zone::PlanAction.new(action: 'create', record: record)])
    end
    let(:remote_records) { DnsMadeEasy::Zone::RemoteRecords.new }

    its(:executable_action_count) { is_expected.to eq(1) }
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
