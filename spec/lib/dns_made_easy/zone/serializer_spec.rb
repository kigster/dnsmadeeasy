# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DnsMadeEasy::Zone::Serializer do
  describe '#to_s' do
    subject(:serialized_zone) { described_class.new(zone_file).to_s }

    let(:zone_file) do
      DnsMadeEasy::Zone::File.new(origin: 'example.com.', ttl: 300, record_set: record_set)
    end
    let(:record_set) { DnsMadeEasy::Zone::RecordSet.new(records: records) }
    let(:records) do
      [
        DnsMadeEasy::Zone::Record.new(owner: 'www', type: 'CNAME', value: '@'),
        DnsMadeEasy::Zone::Record.new(owner: '@', type: 'TXT', value: '"v=spf1 include:_spf.google.com ~all"'),
        DnsMadeEasy::Zone::Record.new(owner: '@', type: 'MX', value: 'mail.example.com.', priority: 10),
        DnsMadeEasy::Zone::Record.new(owner: '@', type: 'A', value: '203.0.113.10')
      ]
    end

    it { is_expected.to eq(File.read('spec/fixtures/zones/formatted.zone')) }

    context 'with apex and delegated NS records' do
      let(:records) do
        [
          DnsMadeEasy::Zone::Record.new(owner: '@', type: 'NS', value: 'ns1.dnsmadeeasy.com.'),
          DnsMadeEasy::Zone::Record.new(owner: 'delegated', type: 'NS', value: 'ns1.example.net.')
        ]
      end

      it { is_expected.not_to include('@        IN NS') }
      it { is_expected.to include('delegated IN NS      ns1.example.net.') }
    end

    context 'with records whose TTL differs from the zone TTL' do
      let(:records) do
        [
          DnsMadeEasy::Zone::Record.new(owner: 'click', type: 'CNAME', value: 'links1.resend-dns.com.', ttl: 120),
          DnsMadeEasy::Zone::Record.new(owner: '@', type: 'A', value: '203.0.113.10')
        ]
      end

      it { is_expected.to include('click    120 IN CNAME   links1.resend-dns.com.') }
      it { is_expected.to include('@        IN A       203.0.113.10') }
    end
  end

  describe 'idempotency' do
    subject(:reformatted_zone) do
      first_parse_result = DnsMadeEasy::Zone::Parser.new(File.read('spec/fixtures/zones/formatted.zone')).call
      serialized_zone = described_class.new(first_parse_result.value!).to_s
      second_parse_result = DnsMadeEasy::Zone::Parser.new(serialized_zone).call

      described_class.new(second_parse_result.value!).to_s
    end

    it { is_expected.to eq(File.read('spec/fixtures/zones/formatted.zone')) }
  end

  describe 'per-record TTL round-trip' do
    subject(:second_pass) { described_class.new(DnsMadeEasy::Zone::Parser.new(first_pass).call.value!).to_s }

    let(:zone_file) { DnsMadeEasy::Zone::File.new(origin: 'example.com.', ttl: 300, record_set: record_set) }
    let(:record_set) do
      DnsMadeEasy::Zone::RecordSet.new(
        records: [
          DnsMadeEasy::Zone::Record.new(owner: 'click', type: 'CNAME', value: 'links1.resend-dns.com.', ttl: 120),
          DnsMadeEasy::Zone::Record.new(owner: 'send', type: 'TXT', value: 'v=spf1 include:amazonses.com ~all', ttl: 120),
          DnsMadeEasy::Zone::Record.new(owner: '@', type: 'A', value: '203.0.113.10')
        ]
      )
    end
    let(:first_pass) { described_class.new(zone_file).to_s }

    it { is_expected.to eq(first_pass) }
    it { is_expected.to include('click    120 IN CNAME   links1.resend-dns.com.') }
    it { is_expected.to include('send     120 IN TXT     "v=spf1 include:amazonses.com ~all"') }
  end
end
