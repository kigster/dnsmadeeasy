# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DnsMadeEasy::Zone::Diff do
  describe '#call' do
    subject(:plan) { described_class.new(desired_records: desired_records, remote_records: remote_records).call }

    let(:apex_a) { DnsMadeEasy::Zone::Record.new(owner: '@', type: 'A', value: '203.0.113.10') }
    let(:www_a) { DnsMadeEasy::Zone::Record.new(owner: 'www', type: 'A', value: '203.0.113.20') }
    let(:changed_www_a) { DnsMadeEasy::Zone::Record.new(owner: 'www', type: 'A', value: '203.0.113.21') }
    let(:remote_only_txt) { DnsMadeEasy::Zone::Record.new(owner: '@', type: 'TXT', value: 'old text') }
    let(:desired_records) { [apex_a] }
    let(:remote_records) { [apex_a] }

    context 'with identical records' do
      it { is_expected.to be_empty }
    end

    context 'with missing remote records' do
      let(:desired_records) { [apex_a, www_a] }

      its(:creates) { is_expected.to contain_exactly(have_attributes(action: 'create', record: www_a)) }
      its(:updates) { is_expected.to be_empty }
      its(:skipped_deletes) { is_expected.to be_empty }
    end

    context 'with unambiguous modified record' do
      let(:desired_records) { [changed_www_a] }
      let(:remote_records) { [www_a] }

      its(:updates) do
        is_expected.to contain_exactly(
          have_attributes(action: 'update', desired_record: changed_www_a, remote_record: www_a)
        )
      end
    end

    context 'with remote-only records' do
      let(:remote_records) { [apex_a, remote_only_txt] }

      its(:skipped_deletes) do
        is_expected.to contain_exactly(
          have_attributes(action: 'skipped_delete', record: remote_only_txt, message: 'Delete skipped by default')
        )
      end
    end

    context 'with a TTL-only difference' do
      let(:desired_records) { [DnsMadeEasy::Zone::Record.new(owner: '@', type: 'A', value: '203.0.113.10', ttl: 300)] }
      let(:remote_records) { [DnsMadeEasy::Zone::Record.new(owner: '@', type: 'A', value: '203.0.113.10', ttl: 120)] }

      it { is_expected.to be_empty }

      context 'with compare_ttl enabled' do
        subject(:plan) do
          described_class.new(desired_records: desired_records, remote_records: remote_records, compare_ttl: true).call
        end

        its(:creates) { is_expected.to be_empty }

        its(:updates) do
          is_expected.to contain_exactly(
            have_attributes(action: 'update', desired_record: have_attributes(ttl: 300))
          )
        end
      end
    end

    context 'with a value change while TTLs are ignored' do
      let(:desired_records) { [DnsMadeEasy::Zone::Record.new(owner: 'www', type: 'A', value: '203.0.113.21', ttl: 300)] }
      let(:remote_records) { [DnsMadeEasy::Zone::Record.new(owner: 'www', type: 'A', value: '203.0.113.20', ttl: 120)] }

      # The update must not modify the remote TTL as a side effect.
      its(:updates) do
        is_expected.to contain_exactly(
          have_attributes(action: 'update', desired_record: have_attributes(value: '203.0.113.21', ttl: 120))
        )
      end
    end

    context 'with apex NS records in the zone file' do
      let(:desired_records) do
        [apex_a, DnsMadeEasy::Zone::Record.new(owner: '@', type: 'NS', value: 'ns0.dnsmadeeasy.com.', ttl: 86_400)]
      end

      its(:creates) { is_expected.to be_empty }
      its(:updates) { is_expected.to be_empty }
      its(:ambiguous) { is_expected.to be_empty }

      its(:skipped_creates) do
        is_expected.to contain_exactly(
          have_attributes(
            action: 'skipped_create',
            record: have_attributes(type: 'NS', owner: '@'),
            message: 'Apex NS records are managed by the DNS provider'
          )
        )
      end
    end

    context 'with matching multi-record groups in different order' do
      let(:desired_records) do
        [
          DnsMadeEasy::Zone::Record.new(owner: '@', type: 'A', value: '151.101.3.52'),
          DnsMadeEasy::Zone::Record.new(owner: '@', type: 'A', value: '151.101.67.52')
        ]
      end
      let(:remote_records) { desired_records.reverse }

      it { is_expected.to be_empty }
    end

    context 'with ambiguous owner/type changes' do
      let(:desired_records) do
        [
          DnsMadeEasy::Zone::Record.new(owner: '@', type: 'TXT', value: 'new one'),
          DnsMadeEasy::Zone::Record.new(owner: '@', type: 'TXT', value: 'new two')
        ]
      end
      let(:remote_records) do
        [
          DnsMadeEasy::Zone::Record.new(owner: '@', type: 'TXT', value: 'old one'),
          DnsMadeEasy::Zone::Record.new(owner: '@', type: 'TXT', value: 'old two')
        ]
      end

      its(:ambiguous) { is_expected.to contain_exactly(have_attributes(action: 'ambiguous')) }
      its(:updates) { is_expected.to be_empty }
    end
  end
end
