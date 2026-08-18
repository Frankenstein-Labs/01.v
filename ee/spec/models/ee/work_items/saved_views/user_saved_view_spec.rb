# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::SavedViews::UserSavedView, feature_category: :planning_views do
  describe '.user_saved_view_limit' do
    context 'when the namespace has the increased_saved_views_limit license' do
      let(:namespace) { build(:group) }

      before do
        stub_licensed_features(increased_saved_views_limit: true)
      end

      it 'returns the correct value' do
        expect(described_class.user_saved_view_limit(namespace)).to eq(100)
      end
    end

    context 'when the namespace does not have the increased_saved_views_limit license' do
      let(:namespace) { build(:group) }

      before do
        stub_licensed_features(increased_saved_views_limit: false)
      end

      it 'returns the correct value' do
        expect(described_class.user_saved_view_limit(namespace)).to eq(5)
      end
    end
  end
end
