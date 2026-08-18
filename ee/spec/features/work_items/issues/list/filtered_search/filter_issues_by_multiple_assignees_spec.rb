# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Filter issues by multiple assignees', :js, feature_category: :planning_views do
  include FilteredSearchHelpers

  let_it_be_with_reload(:user) { create(:user) }
  let_it_be_with_reload(:user2) { create(:user) }
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be_with_reload(:issue1) { create(:issue, project: project, author: user, assignees: [user, user2]) }
  let_it_be(:issue2) { create(:issue, project: project, assignees: [user]) }

  before_all do
    project.add_maintainer(user)
    project.add_developer(user2)
  end

  before do
    sign_in(user)
    visit project_work_items_path(project)
  end

  describe 'with AND filtering' do
    it 'filters issues by multiple assignees' do
      select_tokens 'Assignee', '=', user.username, 'Assignee', '=', user2.username, submit: true

      expect_assignee_token(user.name)
      expect_assignee_token(user2.name)
      expect(page).to have_work_item_count(1)
      expect_empty_search_term
    end
  end

  describe 'with OR filtering' do
    it 'filters issues by multiple assignees' do
      select_tokens 'Assignee', '||', user.username, user2.username, submit: true

      expect_unioned_assignee_token("#{user.name}, #{user2.name}")
      expect(page).to have_work_item_count(2)
      expect_empty_search_term
    end
  end
end
