# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'dme account', type: :aruba do
  before do
    setup_aruba
    allow(DnsMadeEasy).to receive(:client).and_return(client)
  end

  let(:client) do
    instance_double(
      DnsMadeEasy::Api::Client,
      all: {
        'data' => [
          { 'name' => 'www', 'type' => 'A', 'value' => '203.0.113.10' },
          { 'name' => 'mail', 'type' => 'MX', 'value' => 'mail.example.com.' }
        ]
      },
      domains: { 'totalRecords' => 1, 'data' => [{ 'name' => 'example.com' }] },
      records_for: {
        'data' => [
          { 'name' => 'www', 'type' => 'A', 'value' => '203.0.113.10' },
          { 'name' => 'mail', 'type' => 'MX', 'value' => 'mail.example.com.' }
        ]
      }
    )
  end

  describe 'no operation' do
    subject(:output) { last_command_started.stdout }

    before { run_command_and_stop('dme account') }

    it { is_expected.to include('records_for') }
    it { is_expected.to include('List records for a managed domain') }
  end

  describe 'list option' do
    subject(:output) { last_command_started.stdout }

    before { run_command_and_stop('dme account --list') }

    it { is_expected.to include('domains') }
    it { is_expected.to include('List managed domains') }
  end

  describe 'list operations option' do
    subject(:output) { last_command_started.stdout }

    before { run_command_and_stop('dme account --list-operations') }

    it { is_expected.to include('records_for') }
  end

  describe 'account help' do
    subject(:help_output) { last_command_started.stdout }

    before { run_command_and_stop('dme account --help') }

    it { is_expected.to include('Subcommands:') }
    it { is_expected.to include('all') }
    it { is_expected.to include('domains') }
    it { is_expected.not_to include("\n  operations") }
  end

  describe 'operation help' do
    subject(:output) { last_command_started.stdout }

    before { run_command_and_stop('dme account all --help') }

    it { is_expected.to include('dme account all DOMAIN_NAME') }
    it { is_expected.to include('--record-type=TYPE') }
  end

  describe 'domains' do
    subject(:output) { last_command_started.stdout }

    before { run_command_and_stop('dme account domains --format=json --api-key=cli-key --api-secret=cli-secret') }

    it { is_expected.to include('"totalRecords":1') }
  end

  describe 'records_for' do
    subject(:output) { last_command_started.stdout }

    before do
      run_command_and_stop('dme account records_for example.com --format=json --api-key=cli-key --api-secret=cli-secret')
    end

    it { is_expected.to include('"name":"www"') }
  end

  describe 'all' do
    subject(:output) { last_command_started.stdout }

    before { run_command_and_stop('dme account all example.com --format=json --api-key=cli-key --api-secret=cli-secret') }

    it { is_expected.to include('"name":"www"') }
  end

  describe 'all with record type filter' do
    subject(:output) { last_command_started.stdout }

    before do
      run_command_and_stop(
        'dme account all example.com --record-type=MX --format=json --api-key=cli-key --api-secret=cli-secret'
      )
    end

    it { is_expected.to include('"type":"MX"') }
    it { is_expected.not_to include('"type":"A"') }
  end

  describe 'all without required domain name' do
    subject(:error_output) { last_command_started.stderr }

    before { run_command_and_stop('dme account all --format=json --api-key=cli-key --api-secret=cli-secret') }

    it { is_expected.to include('account all DOMAIN_NAME') }
  end

  describe 'invalid operation' do
    subject(:error_output) { last_command_started.stderr }

    before { run_command_and_stop('dme account bogus') }

    it { is_expected.to include('not valid') }
  end

  describe 'legacy root operation' do
    subject(:error_output) { last_command_started.stderr }

    before { run_command_and_stop('dme domains') }

    it { is_expected.to include('Use `dme account domains`') }
  end

  describe 'root help' do
    subject(:help_output) { last_command_started.stderr }

    before { run_command_and_stop('dme --help') }

    it { is_expected.to include('account') }
    it { is_expected.not_to include('create_a_record') }
    it { is_expected.not_to include('base_uri') }
    it { is_expected.not_to include('all') }
  end
end
