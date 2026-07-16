# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DnsMadeEasy::Zone::Parser do
  describe '#call' do
    subject(:result) { described_class.new(zone_text).call }

    let(:zone_text) { File.read(fixture_path) }

    context 'with a valid zone file' do
      let(:fixture_path) { 'spec/fixtures/zones/valid.zone' }

      it { is_expected.to be_success }

      describe 'zone file' do
        subject(:zone_file) { result.value! }

        its(:origin) { is_expected.to eq('example.com.') }
        its(:ttl) { is_expected.to eq(300) }
      end

      describe 'records' do
        subject(:records) { result.value!.records }

        it { is_expected.to all(be_a(DnsMadeEasy::Zone::Record)) }
        it { is_expected.to include(DnsMadeEasy::Zone::Record.new(owner: '@', type: 'A', value: '203.0.113.10')) }
        it { is_expected.to include(DnsMadeEasy::Zone::Record.new(owner: 'www', type: 'CNAME', value: '@')) }
        it { is_expected.to include(DnsMadeEasy::Zone::Record.new(owner: '@', type: 'MX', value: 'mail.example.com.', priority: 10)) }
        it { is_expected.to include(DnsMadeEasy::Zone::Record.new(owner: '@', type: 'TXT', value: 'v=spf1 include:_spf.google.com ~all')) }
      end
    end

    context 'with an invalid zone file' do
      let(:fixture_path) { 'spec/fixtures/zones/invalid.zone' }

      it { is_expected.to be_failure }

      describe 'errors' do
        subject(:errors) { result.failure }

        it { is_expected.not_to be_empty }
      end
    end

    context 'with an unsupported record type' do
      let(:fixture_path) { 'spec/fixtures/zones/unsupported.zone' }

      it { is_expected.to be_failure }

      describe 'errors' do
        subject(:errors) { result.failure }

        it { is_expected.to include('Unsupported DNS record type: CAA') }
      end
    end
  end
end
