# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DnsMadeEasy::Zone::AnameFlattener do
  describe '#call' do
    subject(:result) { described_class.new(records, resolver: resolver).call }

    let(:resolver) { ->(_target) { ['151.101.3.52', '151.101.67.52'] } }
    let(:aname) { DnsMadeEasy::Zone::Record.new(owner: '@', type: 'ANAME', value: 'cdn.example.net.', ttl: 120) }
    let(:cname) { DnsMadeEasy::Zone::Record.new(owner: 'www', type: 'CNAME', value: 'cdn.example.net.') }
    let(:records) { [aname, cname] }

    it { is_expected.to be_success }

    describe 'flattened records' do
      subject(:flattened) { result.value!.first }

      it { is_expected.to include(DnsMadeEasy::Zone::Record.new(owner: '@', type: 'A', value: '151.101.3.52', ttl: 120)) }
      it { is_expected.to include(DnsMadeEasy::Zone::Record.new(owner: '@', type: 'A', value: '151.101.67.52', ttl: 120)) }
      it { is_expected.to include(cname) }
      it { is_expected.not_to include(have_attributes(type: 'ANAME')) }
    end

    describe 'notices' do
      subject(:notices) { result.value!.last }

      it 'reports every conversion' do
        expect(notices).to contain_exactly(
          'Flattened ANAME @ -> cdn.example.net. into A 151.101.3.52, 151.101.67.52 (point-in-time snapshot)'
        )
      end
    end

    context 'without ANAME records' do
      let(:records) { [cname] }

      describe 'records' do
        subject { result.value!.first }

        it { is_expected.to eq([cname]) }
      end

      describe 'notices' do
        subject { result.value!.last }

        it { is_expected.to be_empty }
      end
    end

    context 'when the target does not resolve' do
      let(:resolver) { ->(_target) { [] } }

      it { is_expected.to be_failure }

      describe 'errors' do
        subject { result.failure }

        it { is_expected.to include('Unable to resolve ANAME target cdn.example.net. for --strict-rfc export') }
      end
    end

    context 'when resolution raises' do
      let(:resolver) { ->(_target) { raise Resolv::ResolvError, 'timeout' } }

      it { is_expected.to be_failure }
    end
  end
end
