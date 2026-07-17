# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DnsMadeEasy::Zone::Record do
  describe '#initialize' do
    subject(:record) { described_class.new(attributes) }

    let(:attributes) do
      {
        owner: '@',
        type: 'A',
        value: '203.0.113.10',
        ttl: 300
      }
    end

    its(:owner) { is_expected.to eq('@') }
    its(:type) { is_expected.to eq('A') }
    its(:value) { is_expected.to eq('203.0.113.10') }
    its(:ttl) { is_expected.to eq(300) }
    its(:priority) { is_expected.to be_nil }

    context 'with missing ttl' do
      let(:attributes) do
        {
          owner: 'www',
          type: 'CNAME',
          value: '@'
        }
      end

      its(:ttl) { is_expected.to eq(300) }
    end

    context 'with invalid type' do
      let(:attributes) do
        {
          owner: '@',
          type: 'HTTPRED',
          value: 'https://example.com',
          ttl: 300
        }
      end

      it { expect { record }.to raise_error(Dry::Struct::Error, /invalid type/) }
    end

    context 'with invalid ttl' do
      let(:attributes) do
        {
          owner: '@',
          type: 'A',
          value: '203.0.113.10',
          ttl: -1
        }
      end

      it { expect { record }.to raise_error(Dry::Struct::Error, /invalid type/) }
    end

    context 'with missing owner' do
      let(:attributes) do
        {
          type: 'A',
          value: '203.0.113.10',
          ttl: 300
        }
      end

      it { expect { record }.to raise_error(Dry::Struct::Error) }
    end
  end

  describe '#sort_key' do
    subject(:sort_key) { record.sort_key }

    let(:record) do
      described_class.new(
        owner: '@',
        type: 'MX',
        value: 'mail.example.com.',
        ttl: 300,
        priority: 10
      )
    end

    it { is_expected.to eq(['', 4, 'MX', 10, -1, -1, 'mail.example.com.', 300]) }
  end
end
