# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe DnsMadeEasy::CLI::Launcher do
  describe '#execute!' do
    subject(:execute) { launcher.execute! }

    let(:stdin) { StringIO.new }
    let(:stdout) { StringIO.new }
    let(:stderr) { StringIO.new }
    let(:launcher) { described_class.new(argv, stdin, stdout, stderr) }

    context 'with version argument' do
      let(:argv) { %w[version] }

      before { execute }

      describe 'stdout' do
        subject(:output) { stdout.string }

        it { is_expected.to eq("#{DnsMadeEasy::VERSION}\n") }
      end

      describe 'stderr' do
        subject(:error_output) { stderr.string }

        it { is_expected.to eq('') }
      end
    end
  end
end
