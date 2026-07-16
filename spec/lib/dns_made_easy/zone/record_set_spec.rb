# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DnsMadeEasy::Zone::RecordSet do
  describe '#sorted' do
    subject(:sorted_records) { record_set.sorted }

    let(:record_set) { described_class.new(records: records) }
    let(:apex_a_record) { DnsMadeEasy::Zone::Record.new(owner: '@', type: 'A', value: '203.0.113.10') }
    let(:www_record) { DnsMadeEasy::Zone::Record.new(owner: 'www', type: 'CNAME', value: '@') }
    let(:apex_mx_record) do
      DnsMadeEasy::Zone::Record.new(owner: '@', type: 'MX', value: 'mail.example.com.', priority: 10)
    end
    let(:records) { [www_record, apex_mx_record, apex_a_record] }

    it { is_expected.to eq([apex_a_record, apex_mx_record, www_record]) }
  end

  describe '#include?' do
    subject(:record_set) { described_class.new(records: [record]) }

    let(:record) { DnsMadeEasy::Zone::Record.new(owner: '@', type: 'A', value: '203.0.113.10') }

    it { is_expected.to include(record) }
  end
end
