# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User applies parent filter', :js, feature_category: :planning_views do
  include FilteredSearchHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :public, group: group, developers: user) }

  let_it_be(:parent_epic) { create(:work_item, :epic, namespace: group, title: 'Parent epic') }
  let_it_be(:child_epic) { create(:work_item, :epic, namespace: group, title: 'Child epic') }
  let_it_be(:epic_without_parent) { create(:work_item, :epic, namespace: group, title: 'Epic without parent') }
  let_it_be(:parent_link_1) { create(:parent_link, work_item: child_epic, work_item_parent: parent_epic) }

  let(:issuable_container) { '[data-testid="issuable-container"]' }

  context 'for signed in user' do
    context 'when accessing work item from group epics list' do
      before do
        stub_licensed_features(epics: true)
        sign_in(user)
        visit group_epics_path(group)
      end

      it_behaves_like 'parent filter' do
        let(:parent_item) { parent_epic }
        let(:child_item) { child_epic }
        let(:work_item_2) { epic_without_parent }
        let(:expected_count) { 5 }
      end
    end

    context 'when accessing work item from group work items list' do
      before do
        stub_licensed_features(epics: true)
        sign_in(user)
        visit group_work_items_path(group)
      end

      it_behaves_like 'parent filter' do
        let(:parent_item) { parent_epic }
        let(:child_item) { child_epic }
        let(:work_item_2) { epic_without_parent }
        let(:expected_count) { 5 }
      end
    end
  end
end
