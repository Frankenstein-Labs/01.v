# frozen_string_literal: true

require 'spec_helper'

# Regression test for https://gitlab.com/gitlab-org/gitlab/merge_requests/22461
RSpec.describe 'Resource weight events', :js, feature_category: :team_planning do
  include Features::NotesHelpers

  describe 'move issue by quick action' do
    let(:user) { create(:user) }
    let(:project) { create(:project, :public, :repository) }
    let(:issue) { create(:issue, project: project, weight: nil, due_date: Date.new(2016, 8, 28)) }

    before do
      allow(Gitlab::QueryLimiting::Transaction).to receive(:threshold).and_return(200)
      project.add_maintainer(user)
      sign_in(user)
      visit project_issue_path(project, issue)
    end

    context 'when original issue has weight events' do
      let(:target_project) { create(:project, :public) }

      before do
        target_project.add_maintainer(user)
      end

      it "creates expected weight events on the moved issue" do
        fill_in('Add a reply', with: '/weight 2')
        click_button 'Comment'
        expect(page).to have_field('Add a reply', with: '')

        fill_in('Add a reply', with: "/weight 3\n/move #{target_project.full_path}")
        click_button 'Comment'
        expect(page).to have_content "Moved this item to #{target_project.full_path}."
        expect(issue.reload).to be_closed

        visit project_issue_path(target_project, issue)

        expect(page).to have_content('set weight to 2', count: 1)
        expect(page).to have_content('changed weight to 3 from 2', count: 1)

        visit project_issue_path(project, issue)

        expect(page).to have_content('set weight to 2', count: 1)
        expect(page).to have_content('changed weight to 3 from 2', count: 1)
        expect(page).to have_content 'Closed'
      end
    end
  end
end
