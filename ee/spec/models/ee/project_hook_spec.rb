# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectHook, feature_category: :webhooks do
  describe '.available_hooks' do
    it 'returns all available hooks' do
      expect(described_class.available_hooks).to match_array(
        described_class::AVAILABLE_HOOKS + described_class::EE_AVAILABLE_HOOKS)
    end
  end

  describe '.vulnerability_hooks' do
    it 'returns hooks for vulnerability events only' do
      project = build(:project)
      hook = create(:project_hook, project: project, vulnerability_events: true)

      create(:project_hook, project: project, vulnerability_events: false)

      expect(described_class.vulnerability_hooks).to eq([hook])
    end
  end
end
