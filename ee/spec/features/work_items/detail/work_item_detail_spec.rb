# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Work item detail', :js, feature_category: :team_planning do
  include ListboxHelpers

  let_it_be_with_refind(:user) { create(:user) }

  let_it_be(:group) { create(:group, :nested) }
  let_it_be(:root_group) { group.root_ancestor }
  let_it_be(:project) { create(:project, :public, namespace: group, developers: user) }
  let_it_be(:work_item) { create(:work_item, project: project) }
  let(:work_items_path) { project_work_item_path(project, work_item.iid) }

  context 'for signed in user' do
    before do
      stub_licensed_features(work_item_status: true)
      sign_in(user)
      visit work_items_path
    end

    it_behaves_like 'work items weight'
    it_behaves_like 'work items iteration'
    it_behaves_like 'work items status'
  end

  context 'for user not signed in' do
    before do
      stub_licensed_features(work_item_status: true)
      visit work_items_path
    end

    it 'does to show edit status button' do
      within_testid 'work-item-status' do
        expect(page).not_to have_button 'Edit'
        expect(page).to have_text 'To do'
      end
    end
  end
end
