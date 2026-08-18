# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'New/edit issue', :js, feature_category: :team_planning do
  include GitlabRoutingHelper
  include ActionView::Helpers::JavaScriptHelper
  include FormHelper
  include ListboxHelpers

  let!(:project)   { create(:project) }
  let!(:user)      { create(:user) }
  let!(:user2)     { create(:user) }
  let!(:milestone) { create(:milestone, project: project) }
  let!(:label)     { create(:label, project: project) }
  let!(:label2)    { create(:label, project: project) }
  let!(:issue)     { create(:issue, project: project, assignees: [user], milestone: milestone) }

  before do
    project.add_maintainer(user)
    project.add_maintainer(user2)

    stub_licensed_features(multiple_issue_assignees: true)
    sign_in(user)
  end

  context 'new issue' do
    before do
      visit new_project_issue_path(project)
    end

    describe 'multiple assignees' do
      it 'unselects other assignees when unassigned is selected' do
        within_testid('work-item-assignees') do
          expect(page).to have_button 'assign yourself'

          click_button 'Edit'
          select_listbox_item(user.name)
          select_listbox_item(user2.name)
          click_button 'Apply'

          expect(page).to have_link user.name
          expect(page).to have_link user2.name
          expect(page).not_to have_button 'assign yourself'

          click_button 'Edit'
          click_button 'Clear'

          expect(page).to have_text 'None'
          expect(page).to have_button 'assign yourself'
        end
      end
    end
  end
end
