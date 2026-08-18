# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User manage saved views list', :js, feature_category: :planning_views do
  include FilteredSearchHelpers
  include WorkItemsHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :public) }
  let_it_be(:project) { create(:project, :public, group: group) }
  let_it_be(:label) { create(:group_label, title: 'bug', group: group) }
  let_it_be(:issue) do
    create(:work_item, :issue, project: project, title: 'Test issue', labels: [label])
  end

  before_all do
    group.add_planner(user)
  end

  context 'when user has planner role' do
    before do
      stub_licensed_features(epics: true)
      sign_in(user)
    end

    context 'when creating a view from the add view dropdown' do
      before do
        visit group_work_items_path(group)
        wait_for_all_requests
      end

      include_examples 'saved view creation from add view dropdown'
    end

    context 'when creating a view via the save view button with filters applied' do
      before do
        visit group_work_items_path(group)
        wait_for_all_requests
      end

      include_examples 'saved view creation via save view button with filters'
    end
  end

  context 'when user has guest role' do
    before_all do
      group.add_guest(user)
    end

    before do
      stub_licensed_features(epics: true)
      sign_in(user)
      visit group_work_items_path(group)
      wait_for_all_requests
    end

    include_examples 'guest user saved view restrictions'
  end
end
