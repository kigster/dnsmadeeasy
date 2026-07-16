# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'dme zone', type: :aruba do
  before do
    setup_aruba
    write_file('valid.zone', File.read('spec/fixtures/zones/valid.zone'))
    write_file('invalid.zone', File.read('spec/fixtures/zones/invalid.zone'))
    write_file('unsupported.zone', File.read('spec/fixtures/zones/unsupported.zone'))
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
end
