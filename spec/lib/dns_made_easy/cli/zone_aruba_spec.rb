# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'yaml'

RSpec.describe 'dme zone', type: :aruba do
  before do
    setup_aruba
    allow(DnsMadeEasy).to receive(:client).and_return(client)
    write_file('valid.zone', File.read('spec/fixtures/zones/valid.zone'))
    write_file('formatted.zone', File.read('spec/fixtures/zones/formatted.zone'))
    write_file('invalid.zone', File.read('spec/fixtures/zones/invalid.zone'))
    write_file('unsupported.zone', File.read('spec/fixtures/zones/unsupported.zone'))
  end

  let(:client) do
    instance_double(
      DnsMadeEasy::Api::Client,
      records_for: {
        'data' => [
          { 'id' => 1, 'name' => '', 'type' => 'A', 'value' => '203.0.113.10', 'ttl' => 300 },
          { 'id' => 3, 'name' => '', 'type' => 'MX', 'value' => 'mail.example.com.', 'mxLevel' => 10, 'ttl' => 300 },
          { 'id' => 4, 'name' => '', 'type' => 'NS', 'value' => 'ns1.dnsmadeeasy.com.', 'ttl' => 300 },
          { 'id' => 5, 'name' => 'delegated', 'type' => 'NS', 'value' => 'ns1.example.net.', 'ttl' => 300 },
          { 'id' => 6, 'name' => '', 'type' => 'TXT', 'value' => 'v=spf1 include:_spf.google.com ~all', 'ttl' => 300 },
          { 'id' => 7, 'name' => 'redirect', 'type' => 'HTTPRED', 'value' => 'https://example.com/' }
        ]
      }
    )
  end

  describe 'validate valid zone file' do
    subject(:output) { last_command_started.stdout }

    before { run_command_and_stop('dme zone validate valid.zone') }

    it { is_expected.to include('Zone file is valid.') }
    it { is_expected.to include('Records: 4') }
  end

  describe 'validate invalid zone file' do
    subject(:error_output) { last_command_started.stderr }

    before { run_command_and_stop('dme zone validate invalid.zone') }

    it { is_expected.to include('Zone file is invalid.') }
  end

  describe 'validate unsupported zone file' do
    subject(:error_output) { last_command_started.stderr }

    before { run_command_and_stop('dme zone validate unsupported.zone') }

    it { is_expected.to include('Unsupported DNS record type: CAA') }
  end

  describe 'fmt valid zone file' do
    subject(:output) { last_command_started.stdout }

    before { run_command_and_stop('dme zone fmt valid.zone') }

    it { is_expected.to eq(File.read('spec/fixtures/zones/formatted.zone')) }
  end

  describe 'format alias' do
    subject(:output) { last_command_started.stdout }

    before { run_command_and_stop('dme zone format formatted.zone') }

    it { is_expected.to eq(File.read('spec/fixtures/zones/formatted.zone')) }
  end

  describe 'export' do
    subject(:output) { last_command_started.stdout }

    before do
      run_command_and_stop('dme zone export example.com --api-key=cli-key --api-secret=cli-secret')
    end

    it { is_expected.to include('$ORIGIN example.com.') }
    it { is_expected.to include('@        IN A       203.0.113.10') }
    it { is_expected.to include('delegated IN NS      ns1.example.net.') }
    it { is_expected.not_to include('HTTPRED') }
    it { is_expected.not_to include('ns1.dnsmadeeasy.com') }
  end

  describe 'export warnings' do
    subject(:error_output) { last_command_started.stderr }

    before do
      run_command_and_stop('dme zone export example.com --api-key=cli-key --api-secret=cli-secret')
    end

    it { is_expected.to include('Omitted HTTPRED record redirect -> https://example.com/') }
  end

  describe 'export with apex NS records' do
    subject(:output) { last_command_started.stdout }

    before do
      run_command_and_stop('dme zone export example.com --include-apex-ns --api-key=cli-key --api-secret=cli-secret')
    end

    it { is_expected.to include('@        IN NS      ns1.dnsmadeeasy.com.') }
  end

  describe 'export to output file' do
    subject(:output_file) { read('export.zone') }

    before do
      run_command_and_stop('dme zone export example.com --output=export.zone --api-key=cli-key --api-secret=cli-secret')
    end

    it { is_expected.to include('$ORIGIN example.com.') }
    it { is_expected.to include('@        IN A       203.0.113.10') }
  end

  describe 'export as json' do
    subject(:parsed_output) { JSON.parse(last_command_started.stdout) }

    before do
      run_command_and_stop('dme zone export example.com -f json --api-key=cli-key --api-secret=cli-secret')
    end

    its(['origin']) { is_expected.to eq('example.com.') }
    its(['ttl']) { is_expected.to eq(300) }
    its(['records']) { is_expected.to include('owner' => '@', 'type' => 'A', 'value' => '203.0.113.10', 'ttl' => 300) }
  end

  describe 'export as yaml' do
    subject(:parsed_output) { YAML.safe_load(last_command_started.stdout) }

    before do
      run_command_and_stop('dme zone export example.com --format=yaml --api-key=cli-key --api-secret=cli-secret')
    end

    its(['origin']) { is_expected.to eq('example.com.') }
    its(['ttl']) { is_expected.to eq(300) }
    its(['records']) { is_expected.to include('owner' => '@', 'type' => 'A', 'value' => '203.0.113.10', 'ttl' => 300) }
  end

  describe 'plan text output' do
    subject(:output) { last_command_started.stdout }

    before do
      run_command_and_stop('dme zone plan valid.zone --domain=example.com --api-key=cli-key --api-secret=cli-secret')
    end

    it { is_expected.to include('Create') }
    it { is_expected.to include('www CNAME @') }
    it { is_expected.to include('Skipped Deletes') }
    it { is_expected.to include('delegated NS ns1.example.net.') }
  end

  describe 'plan json output' do
    subject(:parsed_output) { JSON.parse(last_command_started.stdout) }

    before do
      run_command_and_stop(
        'dme zone plan valid.zone --domain=example.com --format=json --api-key=cli-key --api-secret=cli-secret'
      )
    end

    its(['creates']) { is_expected.to include(include('action' => 'create')) }
    its(['skipped_deletes']) { is_expected.to include(include('action' => 'skipped_delete')) }
  end
end
