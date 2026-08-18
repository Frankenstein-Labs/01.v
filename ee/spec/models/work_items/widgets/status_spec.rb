# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Widgets::Status, feature_category: :team_planning do
  describe '.quick_action_params' do
    subject { described_class.quick_action_params }

    it { is_expected.to match_array([:status]) }
  end

  describe '.quick_action_commands' do
    subject { described_class.quick_action_commands }

    it { is_expected.to match_array([:status]) }
  end
end
