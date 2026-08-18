# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Burndown charts', :js, feature_category: :team_planning do
  let(:current_user) { create(:user) }

  before do
    sign_in(current_user)
  end

  describe 'for project milestones' do
    let(:project) { create(:project) }
    let(:milestone_1) { create(:milestone, start_date: Date.current, due_date: Date.tomorrow, project: project) }
    let(:milestone_empty) { create(:milestone, start_date: nil, due_date: nil, project: project) }

    before do
      project.add_maintainer(current_user)
      create(:issue, project: project, milestone: milestone_1)
    end

    it 'presents no issues alert' do
      visit project_milestone_path(milestone_empty.project, milestone_empty)
      expect(page).to have_content('Assign some issues to this milestone.')
    end

    it 'presents no dates alert' do
      visit project_milestone_path(milestone_empty.project, milestone_empty)
      expect(page).to have_content('Add a start date and due date')
    end

    it 'presents burndown charts when available' do
      stub_licensed_features(milestone_charts: true)
      visit project_milestone_path(milestone_1.project, milestone_1)

      expect(page).to have_css('.burndown-chart')
      expect(page).to have_content('Burndown chart')
    end
  end

  describe 'for group milestones' do
    let(:group) { create(:group) }
    let(:project) { create(:project, group: group) }
    let(:milestone_1) { create(:milestone, start_date: Date.current, due_date: Date.tomorrow, group: group) }
    let(:milestone_empty) { create(:milestone, start_date: nil, due_date: nil, group: group) }

    before do
      group.add_maintainer(current_user)
      create(:issue, milestone: milestone_1, project: project)
    end

    it 'presents no dates alert' do
      visit group_milestone_path(milestone_empty.group, milestone_empty)
      expect(page).to have_content('Add a start date and due date')
    end

    it 'presents burndown charts when available' do
      stub_licensed_features(milestone_charts: true)

      visit group_milestone_path(milestone_1.group, milestone_1)

      expect(page).to have_css('div.burndown-chart')
      expect(page).to have_content('Burndown chart')
    end
  end
end
