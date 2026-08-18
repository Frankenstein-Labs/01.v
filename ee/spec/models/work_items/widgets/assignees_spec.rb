# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Widgets::Assignees, feature_category: :team_planning do
  describe '.allows_multiple_assignees?' do
    subject { described_class.allows_multiple_assignees?(resource_parent) }

    before do
      stub_licensed_features(multiple_issue_assignees: feature_available)
    end

    context 'when resource parent is a group' do
      let(:resource_parent) { build_stubbed(:group) }

      context 'when licensed feature is available' do
        let(:feature_available) { true }

        it { is_expected.to be_truthy }
      end

      context 'when licensed feature is not available' do
        let(:feature_available) { false }

        it { is_expected.to be_falsey }
      end
    end

    context 'when resource parent is a project' do
      let(:resource_parent) { build_stubbed(:project) }

      context 'when licensed feature is available' do
        let(:feature_available) { true }

        it { is_expected.to be_truthy }
      end

      context 'when licensed feature is not available' do
        let(:feature_available) { false }

        it { is_expected.to be_falsey }
      end
    end
  end
end
