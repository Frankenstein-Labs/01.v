# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItemPresenter, feature_category: :team_planning do
  let(:user) { build_stubbed(:user) }
  let(:group) { build_stubbed(:group, :private) }
  let(:work_item_transition) { build_stubbed(:work_item_transition) }
  let(:work_item) { build_stubbed(:work_item, work_item_transition: work_item_transition) }
  let(:epic) { build_stubbed(:epic, group: group) }
  let(:epic_url) { Gitlab::UrlBuilder.build(epic) }

  subject(:presenter) { described_class.new(work_item, current_user: user) }

  describe '#promoted_to_epic_url' do
    before do
      stub_licensed_features(epics: true)
    end

    subject { presenter.promoted_to_epic_url }

    it { is_expected.to be_nil }

    context 'when promoted_to is set' do
      let(:work_item_transition) { build_stubbed(:work_item_transition, promoted_to_epic: epic) }
      let(:work_item) { build_stubbed(:work_item, promoted_to_epic: epic, work_item_transition: work_item_transition) }

      context 'when anonymous' do
        let(:user) { nil }

        it { is_expected.to be_nil }
      end

      context 'with signed in user' do
        before do
          stub_member_access_level(group, access_level => user) if access_level
        end

        context 'when user has no role in namespace' do
          let(:access_level) { nil }

          it { is_expected.to be_nil }
        end

        context 'when user has guest role in namespace' do
          let(:access_level) { :guest }

          it { is_expected.to eq(epic_url) }
        end

        context 'when user has reporter role in namespace' do
          let(:access_level) { :reporter }

          it { is_expected.to eq(epic_url) }
        end

        context 'when user has developer role in namespace' do
          let(:access_level) { :developer }

          it { is_expected.to eq(epic_url) }
        end
      end
    end
  end
end
