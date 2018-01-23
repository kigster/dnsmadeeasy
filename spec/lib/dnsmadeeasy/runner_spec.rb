require 'spec_helper'
require 'dnsmadeeasy/runner'
require 'forwardable'

module DnsMadeEasy
  class Output
    @lines = []
    @exits = []
    class << self
      extend Forwardable
      def_delegators :@lines, :size, :empty?, :<<, :clear, :to_s
      attr_reader :lines, :exits

      def clear
        lines.clear
        exits.clear
      end
    end
  end
end

RSpec.describe DnsMadeEasy::Runner do
  let(:runner) { described_class.new(argv) }
  subject { ::DnsMadeEasy::Output.lines }

  before do
    allow(ENV).to receive(:[]).with('DNSMADEEASY_API_KEY').and_return('123')
    allow(ENV).to receive(:[]).with('DNSMADEEASY_API_SECRET').and_return('123')
    allow(ENV).to receive(:[]).with('DNSMADEEASY_CREDENTIALS_FILE').and_call_original
    allow(ENV).to receive(:[]).with('USER').and_call_original
    ::DnsMadeEasy::Runner.send(:define_method, :puts) do |*args|
      ::DnsMadeEasy::Output.lines << args
    end
    ::DnsMadeEasy::Runner.send(:define_method, :exit) do |*args|
      ::DnsMadeEasy::Output.exits << args.first
    end

    ::DnsMadeEasy::Output.clear
    runner.execute!
  end

  describe 'output with empty args' do
    let(:argv) { %w[--help] }

    it { is_expected.to_not be_empty }

    its(:size) { should be > 5 }
    its(:to_s) { should match /Usage/ }

    it 'should have been called exit' do
      expect(DnsMadeEasy::Output.exits.size).to eq(3)
      expect(DnsMadeEasy::Output.exits).to eq [1,1,1]
    end
  end

  describe 'operations' do
    let(:argv) { %w[op] }

    it { is_expected.to_not be_empty }
    its(:size) { should > 2 }
    its(:to_s) { should match /records_for/ }

    it 'should have been called exit' do
      expect(DnsMadeEasy::Output.exits.size).to eq(2)
      expect(DnsMadeEasy::Output.exits).to eq [0,2]
    end
  end
end
