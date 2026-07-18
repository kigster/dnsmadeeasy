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
        'data' => remote_records_data
      }
    )
  end
  let(:remote_records_data) do
    [
      { 'id' => 1, 'name' => '', 'type' => 'A', 'value' => '203.0.113.10', 'ttl' => 300 },
      { 'id' => 3, 'name' => '', 'type' => 'MX', 'value' => 'mail.example.com.', 'mxLevel' => 10, 'ttl' => 300 },
      { 'id' => 4, 'name' => '', 'type' => 'NS', 'value' => 'ns1.dnsmadeeasy.com.', 'ttl' => 300 },
      { 'id' => 5, 'name' => 'delegated', 'type' => 'NS', 'value' => 'ns1.example.net.', 'ttl' => 300 },
      { 'id' => 6, 'name' => '', 'type' => 'TXT', 'value' => '"v=spf1 include:_spf.google.com ~all"', 'ttl' => 300 },
      { 'id' => 7, 'name' => 'redirect', 'type' => 'HTTPRED', 'value' => 'https://example.com/' }
    ]
  end

  describe 'validate valid zone file' do
    subject(:output) { last_command_started.stderr }

    before { run_command_and_stop('dme zone validate valid.zone') }

    it { is_expected.to include('Zone file is valid.') }
    it { is_expected.to include('Records: 4') }
  end

  describe 'validate invalid zone file' do
    subject(:error_output) { last_command_started.stderr }

    before { run_command_and_stop('dme zone validate invalid.zone') }

    it { is_expected.to include('Zone file is invalid.') }

    # The boxed message must not be duplicated by the launcher's rescue.
    it { is_expected.not_to include('zone file is invalid') }
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

  describe 'export with ANAME records' do
    let(:remote_records_data) do
      super() + [{ 'id' => 8, 'name' => '', 'type' => 'ANAME', 'value' => 'cdn.example.net.', 'ttl' => 300 }]
    end

    context 'without --strict-rfc' do
      subject(:output) { last_command_started.stdout }

      before do
        run_command_and_stop('dme zone export example.com --api-key=cli-key --api-secret=cli-secret')
      end

      it { is_expected.to include('@        IN ANAME   cdn.example.net.') }

      describe 'stderr' do
        subject(:error_output) { last_command_started.stderr }

        it { is_expected.not_to include('Flattened ANAME') }
      end
    end

    context 'with --strict-rfc' do
      subject(:output) { last_command_started.stdout }

      before do
        allow(Resolv::DNS).to receive(:open).and_return(['203.0.113.80'])
        run_command_and_stop('dme zone export example.com --strict-rfc --api-key=cli-key --api-secret=cli-secret')
      end

      it { is_expected.not_to include('ANAME') }
      it { is_expected.to include('@        IN A       203.0.113.80') }

      describe 'stderr' do
        subject(:error_output) { last_command_started.stderr }

        it { is_expected.to include('Flattened ANAME @ -> cdn.example.net. into A 203.0.113.80 (point-in-time snapshot)') }
      end
    end
  end

  describe 'export with --strict-rfc and no ANAME records' do
    subject(:error_output) { last_command_started.stderr }

    before do
      run_command_and_stop('dme zone export example.com --strict-rfc --api-key=cli-key --api-secret=cli-secret')
    end

    it { is_expected.not_to include('Flattened ANAME') }
    it { is_expected.to include('Zone export complete.') }
  end

  describe 'plan text output' do
    subject(:output) { last_command_started.stdout }

    before do
      run_command_and_stop('dme zone plan example.com valid.zone --api-key=cli-key --api-secret=cli-secret')
    end

    it { is_expected.to include('Create') }
    it { is_expected.to include('www CNAME @') }
    it { is_expected.to include('Skipped Deletes') }
    it { is_expected.to include('delegated NS ns1.example.net.') }
  end

  describe 'plan with apex NS records in the zone file' do
    subject(:output) { last_command_started.stdout }

    before do
      write_file('apex-ns.zone', <<~ZONE)
        $ORIGIN example.com.
        $TTL 300

        @        IN A       203.0.113.10
        @        IN NS      ns0.dnsmadeeasy.com.
        @        IN MX      10 mail.example.com.
        @        IN TXT     "v=spf1 include:_spf.google.com ~all"
      ZONE
      run_command_and_stop('dme zone plan example.com apex-ns.zone --api-key=cli-key --api-secret=cli-secret')
    end

    it { is_expected.to include('Skipped Creates') }
    it { is_expected.to include('@ NS ns0.dnsmadeeasy.com. (ttl=300) (Apex NS records are managed by the DNS provider)') }
    it { is_expected.not_to include("Create\n  - @ NS") }
  end

  describe 'plan with a TTL-only difference' do
    subject(:output) { last_command_started.stdout }

    let(:remote_records_data) do
      super().map { |record| record['type'] == 'A' ? record.merge('ttl' => 120) : record }
    end

    context 'when TTLs are ignored by default' do
      before do
        run_command_and_stop('dme zone plan example.com valid.zone --api-key=cli-key --api-secret=cli-secret')
      end

      it { is_expected.not_to include('Update') }
    end

    context 'with --diff-ttl' do
      before do
        run_command_and_stop(
          'dme zone plan example.com valid.zone --diff-ttl --api-key=cli-key --api-secret=cli-secret'
        )
      end

      it { is_expected.to include('@ A 203.0.113.10 (ttl=120) -> @ A 203.0.113.10 (ttl=300)') }
    end
  end

  describe 'plan json output' do
    subject(:parsed_output) { JSON.parse(last_command_started.stdout) }

    before do
      run_command_and_stop(
        'dme zone plan example.com valid.zone --format=json --api-key=cli-key --api-secret=cli-secret'
      )
    end

    its(['creates']) { is_expected.to include(include('action' => 'create')) }
    its(['skipped_deletes']) { is_expected.to include(include('action' => 'skipped_delete')) }
  end

  describe 'apply add-only' do
    subject(:output) do
      expect(client).to receive(:create_record).with('example.com', 'www', 'CNAME', '@', hash_including('ttl' => 300))

      run_command_and_stop(
        'dme zone apply example.com valid.zone --add-only --yes --api-key=cli-key --api-secret=cli-secret'
      )

      last_command_started.stderr
    end

    it { is_expected.to include('Applied: 1') }
    it { is_expected.to include('Failed: 0') }
    it { is_expected.to include('Skipped: 2') }
  end

  describe 'apply delete-only' do
    subject(:output) do
      expect(client).to receive(:delete_record).with('example.com', 5)
      expect(client).not_to receive(:delete_record).with('example.com', 4)

      run_command_and_stop(
        'dme zone apply example.com valid.zone --delete-only --yes --api-key=cli-key --api-secret=cli-secret'
      )

      last_command_started.stderr
    end

    it { is_expected.to include('Applied: 1') }
    it { is_expected.to include('Failed: 0') }
    it { is_expected.to include('Skipped: 2') }
  end

  describe 'apply without confirmation' do
    subject(:error_output) do
      expect(client).not_to receive(:create_record)

      run_command_and_stop('dme zone apply example.com valid.zone --api-key=cli-key --api-secret=cli-secret')

      last_command_started.stderr
    end

    it { is_expected.to include('Apply 1 action(s)? Type yes to continue:') }
    it { is_expected.to include('zone apply cancelled') }
  end

  describe 'plan normalizes the domain argument for the API' do
    subject(:error_output) do
      # The 1.0.1 bug shipped "kig.re." (trailing-dot FQDN) to the API and got
      # a 404; the argument must reach the client dot-free and downcased. Any
      # other argument raises, which fails the command and thus the example.
      allow(client).to receive(:records_for).and_raise('records_for called with a non-normalized domain')
      allow(client).to receive(:records_for).with('example.com').and_return('data' => remote_records_data)

      run_command_and_stop('dme zone plan EXAMPLE.COM. valid.zone --api-key=cli-key --api-secret=cli-secret')

      last_command_started.stderr
    end

    it { is_expected.to include('Zone plan complete for example.com') }
  end

  describe 'plan with a mismatched $ORIGIN' do
    subject(:error_output) do
      expect(client).not_to receive(:records_for)

      run_command_and_stop('dme zone plan other.example valid.zone --api-key=cli-key --api-secret=cli-secret')

      last_command_started.stderr
    end

    it { is_expected.to include('Domain and zone file disagree.') }
    it { is_expected.to include('Domain argument: other.example') }
    it { is_expected.to include('Zone file $ORIGIN: example.com.') }
    it { is_expected.not_to include('arguments are swapped') }
  end

  describe 'plan with swapped arguments' do
    subject(:error_output) do
      expect(client).not_to receive(:records_for)

      run_command_and_stop('dme zone plan valid.zone example.com --api-key=cli-key --api-secret=cli-secret')

      last_command_started.stderr
    end

    it { is_expected.to include('Zone file not found: example.com') }
    it { is_expected.to include('It looks like the arguments are swapped. Usage: dmez zone plan DOMAIN FILE') }
  end

  describe 'plan with a missing zone file' do
    subject(:error_output) do
      run_command_and_stop('dme zone plan example.com missing.zone --api-key=cli-key --api-secret=cli-secret')

      last_command_started.stderr
    end

    it { is_expected.to include('Zone file not found: missing.zone') }
    it { is_expected.not_to include('arguments are swapped') }
  end

  describe 'apply with a mismatched $ORIGIN' do
    subject(:error_output) do
      expect(client).not_to receive(:records_for)
      expect(client).not_to receive(:create_record)

      run_command_and_stop('dme zone apply other.example valid.zone --yes --api-key=cli-key --api-secret=cli-secret')

      last_command_started.stderr
    end

    it { is_expected.to include('Domain and zone file disagree.') }
    it { is_expected.to include('Zone file $ORIGIN: example.com.') }
  end
end
