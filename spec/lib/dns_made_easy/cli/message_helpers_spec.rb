# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe DnsMadeEasy::CLI::MessageHelpers do
  shared_examples 'a boxed stderr helper' do |helper_name, box_method, expected_box|
    subject(:message_helper) { described_class.public_send(helper_name, message) }

    let(:message) { "First line\nSecond line" }

    before do
      allow(TTY::Box).to receive(box_method).and_return(expected_box)
    end

    it { is_expected.to eq(expected_box) }

    it 'passes the message and standard box options' do
      expect(TTY::Box).to receive(box_method).with(message, border: { type: :thick }, width: 85)

      message_helper
    end

    it 'prints the boxed message to stderr after a blank line, keeping stdout clean' do
      message_helper

      expect(stderr.string).to eq("\n#{expected_box}\n")
      expect(stdout.string).to be_empty
    end
  end

  let(:stdout) { StringIO.new }
  let(:stderr) { StringIO.new }

  before do
    described_class.stdout = stdout
    described_class.stderr = stderr
  end

  after do
    described_class.stdout = $stdout
    described_class.stderr = $stderr
  end

  describe '.info' do
    it_behaves_like 'a boxed stderr helper', :info, :info, 'info-box'
  end

  describe '.warn' do
    it_behaves_like 'a boxed stderr helper', :warn, :warn, 'warn-box'
  end

  describe '.error' do
    it_behaves_like 'a boxed stderr helper', :error, :error, 'error-box'
  end

  describe '.success' do
    it_behaves_like 'a boxed stderr helper', :success, :success, 'success-box'
  end

  describe '.kv' do
    it 'right-aligns the key to 30 characters' do
      expect(described_class.kv('Records', 4)).to eq('                       Records: 4')
    end
  end

  describe 'when included into a command' do
    subject(:command) { command_class.new }

    let(:command_class) do
      Class.new do
        include DnsMadeEasy::CLI::MessageHelpers

        attr_reader :err

        def initialize
          @err = StringIO.new
        end
      end
    end

    it 'prints success boxes to the instance @err stream' do
      command.success('all done')

      expect(command.err.string).to include('all done')
    end

    it 'exposes the boxed warn as #warning' do
      command.warning('careful now')

      expect(command.err.string).to include('careful now')
    end

    it 'falls back to the module stderr without an @err stream' do
      instance = Class.new { include DnsMadeEasy::CLI::MessageHelpers }.new
      instance.info('module fallback')

      expect(stderr.string).to include('module fallback')
    end
  end
end
