# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User views the merge trains page', :js, feature_category: :merge_trains do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { project.owner }

  before do
    stub_licensed_features(merge_pipelines: true, merge_trains: true)
    sign_in(user)
  end

  context 'when the train is empty' do
    before do
      visit project_merge_trains_path(project)
    end

    it 'renders the page with its filter and tabs' do
      expect(page).to have_content('Merge trains')
      expect(page).to have_content('Filter by target branch')

      expect(page).to have_selector('[role="tab"]', text: 'Active')
      expect(page).to have_selector('[role="tab"]', text: 'Merged')
    end

    it 'renders the empty state' do
      expect(page).to have_content('No merge trains')
    end
  end

  context 'when a merge request is on the train' do
    let_it_be(:merge_request) do
      create(:merge_request, source_project: project, source_branch: 'feature',
        target_project: project, target_branch: project.default_branch, title: 'Mock Merge Request')
    end

    let_it_be(:car) do
      create(:merge_train_car, :idle,
        target_project: project,
        target_branch: project.default_branch,
        merge_request: merge_request,
        user: user)
    end

    before do
      visit project_merge_trains_path(project)
    end

    it 'lists the merge request in the train' do
      expect(page).to have_link('Mock Merge Request', href: project_merge_request_path(project, merge_request))
      expect(page).not_to have_content('No merge trains')
    end
  end
end
