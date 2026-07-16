# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'dme CLI', type: :aruba do
  before { setup_aruba }

  describe 'version' do
    subject(:output) { last_command_started.stdout }

    before { run_command_and_stop('dme version') }

    it { is_expected.to eq("#{DnsMadeEasy::VERSION}\n") }
  end

  describe 'help' do
    subject(:output) { last_command_started.stderr }

    before { run_command_and_stop('dme --help') }

    it { is_expected.to include('Commands:') }
    it { is_expected.to include('version') }
  end
end
