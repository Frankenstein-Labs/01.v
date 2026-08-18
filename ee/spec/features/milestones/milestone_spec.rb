# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "User views milestone detail", feature_category: :team_planning do
  let_it_be(:group) { create(:group, :public) }
  let_it_be_with_reload(:project) { create(:project, :repository, group: group) }
  let_it_be_with_reload(:no_access_project) { create(:project, :repository, group: group) }
  let_it_be(:milestone) { create(:milestone, group: group) }
  let_it_be(:user) { create(:project_member, :developer, user: create(:user), project: project).user }

  def toggle_sidebar
    click_button 'Toggle sidebar'
  end

  def sidebar_release_block
    find_by_testid('milestone-sidebar-releases')
  end

  def sidebar_release_block_collapsed_icon
    find_by_testid('milestone-sidebar-releases-collapsed-icon')
  end

  before do
    stub_licensed_features(group_milestone_project_releases: true)
    sign_in(user)
  end

  context 'when the milestone is not associated with a release' do
    before do
      visit group_milestone_path(group, milestone)
    end

    it 'shows "None" in the "Releases" section' do
      expect(sidebar_release_block).to have_content 'Releases None'
    end

    describe 'when the sidebar is collapsed' do
      before do
        toggle_sidebar
      end

      it 'shows "0" in the "Releases" section' do
        expect(sidebar_release_block).to have_content '0'
      end

      it 'has a tooltip that reads "Releases"' do
        expect(sidebar_release_block_collapsed_icon['title']).to eq 'Releases'
      end
    end
  end

  context 'when the milestone is associated with one release' do
    before do
      create(:release, project: project, name: 'Version 5', milestones: [milestone])

      visit group_milestone_path(group, milestone)
    end

    it 'shows "Version 5" in the "Release" section' do
      expect(sidebar_release_block).to have_content 'Release Version 5'
    end

    describe 'when the sidebar is collapsed' do
      before do
        toggle_sidebar
      end

      it 'shows "1" in the "Releases" section' do
        expect(sidebar_release_block).to have_content '1'
      end

      it 'has a tooltip that reads "1 release"' do
        expect(sidebar_release_block_collapsed_icon['title']).to eq '1 release'
      end
    end
  end

  context 'when the milestone is associated with multiple releases' do
    before do
      (5..10).each do |num|
        released_at = Time.zone.parse('2019-10-04') + num.months
        create(:release, project: project, name: "Version #{num}", milestones: [milestone], released_at: released_at)
      end

      visit group_milestone_path(group, milestone)
    end

    it 'shows a shortened list of releases in the "Releases" section' do
      expect(sidebar_release_block).to have_content 'Releases Version 10 • Version 9 • Version 8 • 3 more releases'
    end

    describe 'when the sidebar is collapsed' do
      before do
        toggle_sidebar
      end

      it 'shows "6" in the "Releases" section' do
        expect(sidebar_release_block).to have_content '6'
      end

      it 'has a tooltip that reads "6 releases"' do
        expect(sidebar_release_block_collapsed_icon['title']).to eq '6 releases'
      end
    end
  end

  context 'when the milestone is associated with unavailable releases' do
    it 'only shows releases that user has access to' do
      create(:release, name: 'PUBLIC RELEASE', project: project, milestones: [milestone])
      create(:release, name: 'PRIVATE RELEASE', project: no_access_project, milestones: [milestone])

      visit group_milestone_path(group, milestone)

      expect(sidebar_release_block).to have_content 'PUBLIC RELEASE'
      expect(sidebar_release_block).not_to have_content 'PRIVATE RELEASE'
      expect(sidebar_release_block).to have_content '1 more release'
    end
  end
end
