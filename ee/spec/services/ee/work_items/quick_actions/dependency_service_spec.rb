# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::QuickActions::DependencyService, feature_category: :team_planning do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:issue) { create(:issue, project: project) }

  subject(:service) { described_class.new(issue, user, project) }

  before_all do
    project.add_reporter(user)
  end

  describe '#can_block?' do
    context 'when blocked_issues feature is available' do
      before do
        stub_licensed_features(blocked_issues: true)
      end

      it 'returns true' do
        expect(service.can_block?).to be(true)
      end
    end

    context 'when blocked_issues feature is not available' do
      before do
        stub_licensed_features(blocked_issues: false)
      end

      it 'returns false' do
        expect(service.can_block?).to be(false)
      end
    end

    context 'when user lacks permission' do
      let_it_be(:other_user) { create(:user) }

      subject(:service) { described_class.new(issue, other_user, project) }

      before do
        stub_licensed_features(blocked_issues: true)
      end

      it 'returns false' do
        expect(service.can_block?).to be(false)
      end
    end
  end
end
