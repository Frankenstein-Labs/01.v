# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Projects::Panel, feature_category: :navigation do
  let_it_be_with_reload(:project) { create(:project) }

  let(:context) { Sidebars::Projects::Context.new(current_user: nil, container: project, show_get_started_menu: false) }

  subject(:panel) { described_class.new(context) }

  describe 'ExternalIssueTrackerMenu' do
    before do
      allow_next_instance_of(Sidebars::Projects::Menus::IssuesMenu) do |issues_menu|
        allow(issues_menu).to receive(:show_jira_menu_items?).and_return(show_jira_menu_items)
      end
    end

    context 'when show_jira_menu_items? is false' do
      let(:show_jira_menu_items) { false }

      it 'contains ExternalIssueTracker menu' do
        expect(panel).to include_menu(Sidebars::Projects::Menus::ExternalIssueTrackerMenu)
      end
    end

    context 'when show_jira_menu_items? is true' do
      let(:show_jira_menu_items) { true }

      it 'does not contain ExternalIssueTracker menu' do
        expect(panel).not_to include_menu(Sidebars::Projects::Menus::ExternalIssueTrackerMenu)
      end
    end
  end

  context 'with learn gitlab menu' do
    it 'contains the menu' do
      expect(panel).to include_menu(Sidebars::Projects::Menus::LearnGitlabMenu)
    end

    context 'when the project namespace is on a trial', :saas do
      before_all do
        group = create(
          :group_with_plan,
          plan: :ultimate_trial_plan,
          trial_starts_on: Date.current,
          trial_ends_on: Date.current.advance(days: 60),
          trial: true
        )
        project.update!(namespace: group)
      end

      it 'contains the GetStarted menu' do
        expect(panel).to include_menu(Sidebars::Projects::Menus::GetStartedMenu)
      end

      it 'does not contain the LearnGitlab menu' do
        expect(panel).not_to include_menu(Sidebars::Projects::Menus::LearnGitlabMenu)
      end
    end

    context 'when the project namespace is not on a trial' do
      context 'when show_get_started_menu is false' do
        it 'contains the LearnGitlab menu' do
          expect(panel).to include_menu(Sidebars::Projects::Menus::LearnGitlabMenu)
        end
      end

      context 'when show_get_started_menu is true' do
        before do
          allow(context).to receive(:show_get_started_menu).and_return(true)
        end

        it 'contains the GetStarted menu' do
          expect(panel).to include_menu(Sidebars::Projects::Menus::GetStartedMenu)
        end
      end
    end
  end
end
