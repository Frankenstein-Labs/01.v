# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::States, feature_category: :workspaces do
  include_context "with constant modules"

  let(:object) { Object.new.extend(described_class) }

  describe '.valid_desired_state?' do
    it 'returns true for a valid desired state' do
      expect(object.valid_desired_state?(states_module::RESTART_REQUESTED)).to be(true)
    end

    it 'returns false for an invalid desired state' do
      expect(object.valid_desired_state?(states_module::FAILED)).to be(false)
    end
  end

  describe '.valid_actual_state?' do
    it 'returns true for a valid actual state' do
      expect(object.valid_actual_state?(states_module::RUNNING)).to be(true)
    end

    it 'returns false for an invalid actual state' do
      expect(object.valid_actual_state?(states_module::RESTART_REQUESTED)).to be(false)
    end
  end
end
