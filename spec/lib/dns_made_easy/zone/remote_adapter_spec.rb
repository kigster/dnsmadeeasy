# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DnsMadeEasy::Zone::RemoteAdapter do
  describe '#call' do
    subject(:result) { described_class.new(response, domain: domain, default_ttl: 300).call }

    let(:domain) { 'example.com' }
    let(:response) do
      {
        'data' => [
          { 'id' => 1, 'name' => '', 'type' => 'A', 'value' => '203.0.113.10', 'ttl' => 300 },
          { 'id' => 2, 'name' => 'www', 'type' => 'CNAME', 'value' => '@' },
          { 'id' => 3, 'name' => '', 'type' => 'MX', 'value' => 'mail.example.com.', 'mxLevel' => 10 },
          { 'id' => 4, 'name' => '_dmarc', 'type' => 'TXT', 'value' => '"v=DMARC1; p=none;"' },
          { 'id' => 4, 'name' => 'redirect', 'type' => 'HTTPRED', 'value' => 'https://example.com/' }
        ]
      }
    end

    it { is_expected.to be_success }

    describe 'remote records' do
      subject(:remote_records) { result.value! }

      its(:warnings) { is_expected.to include('Omitted HTTPRED record redirect -> https://example.com/') }

      describe 'records' do
        subject(:records) { remote_records.records }

        it { is_expected.to include(DnsMadeEasy::Zone::Record.new(owner: '@', type: 'A', value: '203.0.113.10')) }
        it { is_expected.to include(DnsMadeEasy::Zone::Record.new(owner: 'www', type: 'CNAME', value: '@')) }
        it { is_expected.to include(DnsMadeEasy::Zone::Record.new(owner: '@', type: 'MX', value: 'mail.example.com.', priority: 10)) }
        it { is_expected.to include(DnsMadeEasy::Zone::Record.new(owner: '_dmarc', type: 'TXT', value: 'v=DMARC1; p=none;')) }
        it { is_expected.not_to include(have_attributes(type: 'HTTPRED')) }
      end

      describe 'provider record' do
        subject(:provider_record) { remote_records.provider_records.first }

        its(:provider_id) { is_expected.to eq(1) }
        its(:source_id) { is_expected.to eq('dns-made-easy') }
      end
    end

    context 'with an unsupported provider record type' do
      let(:response) { { 'data' => [{ 'id' => 5, 'name' => '@', 'type' => 'CAA', 'value' => '0 issue "letsencrypt.org"' }] } }

      it { is_expected.to be_failure }

      describe 'errors' do
        subject(:errors) { result.failure }

        it { is_expected.to include('Unsupported DNS Made Easy record type: CAA') }
      end
    end
  end
end
