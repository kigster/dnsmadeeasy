# frozen_string_literal: true

require 'json'
require 'spec_helper'

RSpec.describe DnsMadeEasy::Zone::PlanRenderer do
  let(:renderer) { described_class.new(plan) }
  let(:record) { DnsMadeEasy::Zone::Record.new(owner: '@', type: 'A', value: '203.0.113.10') }
  let(:changed_record) { DnsMadeEasy::Zone::Record.new(owner: '@', type: 'A', value: '203.0.113.11') }

  describe '#to_text' do
    subject(:text) { renderer.to_text }

    context 'with an empty plan' do
      let(:plan) { DnsMadeEasy::Zone::Plan.new }

      it { is_expected.to eq("No changes.\n") }
    end

    context 'with actions' do
      let(:plan) do
        DnsMadeEasy::Zone::Plan.new(
          creates: [DnsMadeEasy::Zone::PlanAction.new(action: 'create', record: record)],
          updates: [
            DnsMadeEasy::Zone::PlanAction.new(
              action: 'update',
              remote_record: record,
              desired_record: changed_record
            )
          ]
        )
      end

      it { is_expected.to include("Create\n  - @ A 203.0.113.10") }
      it { is_expected.to include("Update\n  - @ A 203.0.113.10 -> @ A 203.0.113.11") }
    end
  end

  describe '#to_json' do
    subject(:json) { JSON.parse(renderer.to_json) }

    let(:plan) do
      DnsMadeEasy::Zone::Plan.new(creates: [DnsMadeEasy::Zone::PlanAction.new(action: 'create', record: record)])
    end

    its(['creates']) do
      is_expected.to include(
        'action' => 'create',
        'record' => { 'owner' => '@', 'type' => 'A', 'value' => '203.0.113.10', 'ttl' => 300 }
      )
    end
  end
end
