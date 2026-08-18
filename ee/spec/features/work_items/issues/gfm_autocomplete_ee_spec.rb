# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'GFM autocomplete EE', :js, feature_category: :team_planning do
  include Features::AutocompleteHelpers

  let_it_be_with_reload(:user) { create(:user, name: '💃speciąl someone💃', username: 'someone.special') }
  let_it_be(:another_user) { create(:user, name: 'another user', username: 'another.user') }
  let_it_be_with_reload(:project) { create(:project, :in_group) }
  let_it_be(:cadence) { create(:iterations_cadence, group: project.group) }
  let_it_be(:iteration) { create(:iteration, :with_due_date, iterations_cadence: cadence, start_date: 2.days.ago) }
  let_it_be_with_reload(:issue) { create(:issue, project: project, assignees: [user]) }

  before do
    project.add_maintainer(user)

    sign_in(user)

    visit project_issue_path(project, issue)
  end

  context 'assignees' do
    it 'only lists users who are currently assigned to the issue when using /unassign' do
      fill_in 'Add a reply', with: '/una'
      find_highlighted_autocomplete_item.click

      expect(find_autocomplete_menu).to have_text(user.username)
      expect(find_autocomplete_menu).not_to have_text(another_user.username)
    end
  end

  context 'iterations' do
    before do
      stub_licensed_features(iterations: true)
    end

    it 'correctly autocompletes iteration reference prefix' do
      fill_in 'Add a reply', with: '/ite'

      expect(find_autocomplete_menu).to have_text('/iteration *iteration:')
    end
  end
end
