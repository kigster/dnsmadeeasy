# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe DnsMadeEasy::CLI::Commands::Account do
  describe '#call' do
    subject(:command) { described_class.new }

    let(:stdout) { StringIO.new }
    let(:stderr) { StringIO.new }
    let(:client) do
      instance_double(
        DnsMadeEasy::Api::Client,
        all: { 'data' => [{ 'name' => 'www', 'type' => 'A', 'value' => '203.0.113.10' }] },
        domains: { 'totalRecords' => 1, 'data' => [{ 'name' => 'example.com' }] },
        records_for: {
          'data' => [
            { 'name' => 'www', 'type' => 'A', 'value' => '203.0.113.10' },
            { 'name' => 'mail', 'type' => 'MX', 'value' => 'mail.example.com.' }
          ]
        }
      )
    end

    before do
      command.instance_variable_set(:@out, stdout)
      command.instance_variable_set(:@err, stderr)
      allow(DnsMadeEasy).to receive(:client).and_return(client)
    end

    context 'with no operation' do
      before { command.call }

      describe 'stdout' do
        subject(:output) { stdout.string }

        it { is_expected.to include('records_for') }
        it { is_expected.to include('List records for a managed domain') }
      end
    end

    context 'with list option' do
      before { command.call(list: true) }

      describe 'stdout' do
        subject(:output) { stdout.string }

        it { is_expected.to include('domains') }
        it { is_expected.to include('List managed domains') }
      end
    end
  end

  describe '.build_operation_command' do
    subject(:command) { operation_command_class.new }

    let(:operation_command_class) { described_class.build_operation_command(operation_name) }
    let(:stdout) { StringIO.new }
    let(:stderr) { StringIO.new }
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

    before do
      command.instance_variable_set(:@out, stdout)
      command.instance_variable_set(:@err, stderr)
      allow(DnsMadeEasy).to receive(:client).and_return(client)
    end

    context 'with no-argument operation' do
      let(:operation_name) { 'domains' }

      before do
        command.call(format: 'json', api_key: 'cli-key', api_secret: 'cli-secret')
      end

      describe 'stdout' do
        subject(:output) { stdout.string }

        it { is_expected.to include('"totalRecords":1') }
        it { is_expected.to include('"example.com"') }
      end

      describe 'configured credentials' do
        subject(:configured_credentials) { [DnsMadeEasy.api_key, DnsMadeEasy.api_secret] }

        it { is_expected.to eq(%w[cli-key cli-secret]) }
      end
    end

    context 'with domain-name operation' do
      let(:operation_name) { 'records_for' }

      before do
        command.call(domain_name: 'example.com', format: 'json', api_key: 'cli-key', api_secret: 'cli-secret')
      end

      describe 'stdout' do
        subject(:output) { stdout.string }

        it { is_expected.to include('"name":"www"') }
        it { is_expected.to include('"type":"A"') }
      end
    end

    context 'with record type filter' do
      let(:operation_name) { 'records_for' }

      before do
        command.call(domain_name: 'example.com', format: 'json', record_type: 'MX', api_key: 'cli-key',
                     api_secret: 'cli-secret')
      end

      describe 'stdout' do
        subject(:output) { stdout.string }

        it { is_expected.to include('"type":"MX"') }
        it { is_expected.not_to include('"type":"A"') }
      end
    end

    context 'with all alias operation' do
      let(:operation_name) { 'all' }

      before do
        command.call(domain_name: 'example.com', format: 'json', api_key: 'cli-key', api_secret: 'cli-secret')
      end

      describe 'stdout' do
        subject(:output) { stdout.string }

        it { is_expected.to include('"name":"www"') }
      end
    end

    context 'with environment credentials' do
      let(:operation_name) { 'domains' }

      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:[]).with('DNSMADEEASY_API_KEY').and_return('env-key')
        allow(ENV).to receive(:[]).with('DNSMADEEASY_API_SECRET').and_return('env-secret')
        allow(ENV).to receive(:fetch).with('DNSMADEEASY_API_KEY').and_return('env-key')
        allow(ENV).to receive(:fetch).with('DNSMADEEASY_API_SECRET').and_return('env-secret')
        allow(ENV).to receive(:fetch).with('DNSMADEEASY_API_KEY', nil).and_return('env-key')
        allow(ENV).to receive(:fetch).with('DNSMADEEASY_API_SECRET', nil).and_return('env-secret')

        command.call(format: 'json')
      end

      describe 'configured credentials' do
        subject(:configured_credentials) { [DnsMadeEasy.api_key, DnsMadeEasy.api_secret] }

        it { is_expected.to eq(%w[env-key env-secret]) }
      end
    end

    context 'with credentials file' do
      let(:operation_name) { 'domains' }
      let(:credentials_file) { 'tmp/account-credentials.ini' }

      before do
        FileUtils.mkdir_p('tmp')
        File.write(credentials_file, "dns_dnsmadeeasy_api_key=file-key\n")
        File.write(credentials_file, "dns_dnsmadeeasy_secret_key=file-secret\n", mode: 'a')

        command.call(credentials: credentials_file, format: 'json')
      end

      describe 'configured credentials' do
        subject(:configured_credentials) { [DnsMadeEasy.api_key, DnsMadeEasy.api_secret] }

        it { is_expected.to eq(%w[file-key file-secret]) }
      end
    end
  end
end
