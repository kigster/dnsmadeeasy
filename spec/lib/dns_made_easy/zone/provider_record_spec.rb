# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DnsMadeEasy::Zone::ProviderRecord do
  describe '#initialize' do
    subject(:provider_record) { described_class.new(record: record, provider_id: provider_id, source_id: source_id) }

    let(:record) { DnsMadeEasy::Zone::Record.new(owner: 'www', type: 'A', value: '203.0.113.10') }
    let(:provider_id) { 12_345 }
    let(:source_id) { 'dns-made-easy' }

    its(:record) { is_expected.to eq(record) }
    its(:provider_id) { is_expected.to eq(12_345) }
    its(:source_id) { is_expected.to eq('dns-made-easy') }

    describe 'record equality' do
      subject(:records_equal) { provider_record.record == other_provider_record.record }

      let(:other_provider_record) do
        described_class.new(record: record, provider_id: 67_890, source_id: 'other-source')
      end

      it { is_expected.to be(true) }
    end
  end
end
