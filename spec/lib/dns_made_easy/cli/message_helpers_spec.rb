# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe DnsMadeEasy::CLI::MessageHelpers do
  shared_examples 'a boxed stdout helper' do |helper_name, box_method, expected_box|
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

    it 'prints the boxed message to stdout' do
      message_helper

      expect(stdout.string).to eq("#{expected_box}\n")
      expect(stderr.string).to be_empty
    end
  end

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

    it 'prints the boxed message to stderr' do
      message_helper

      expect(stderr.string).to eq("#{expected_box}\n")
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
    it_behaves_like 'a boxed stdout helper', :info, :info, 'info-box'
  end

  describe '.warn' do
    it_behaves_like 'a boxed stderr helper', :warn, :warn, 'warn-box'
  end

  describe '.error' do
    it_behaves_like 'a boxed stderr helper', :error, :error, 'error-box'
  end

  describe '.success' do
    it_behaves_like 'a boxed stdout helper', :success, :success, 'success-box'
  end
end
