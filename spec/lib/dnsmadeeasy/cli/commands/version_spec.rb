# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DnsMadeEasy::CLI::Commands::Version do
  describe '#call' do
    subject(:command) { described_class.new }

    let(:stdout) { StringIO.new }

    before do
      command.instance_variable_set(:@out, stdout)
      command.call
    end

    its(:class) { should eq(described_class) }

    describe 'output' do
      subject(:output) { stdout.string }

      it { is_expected.to eq("#{DnsMadeEasy::VERSION}\n") }
    end
  end
end
