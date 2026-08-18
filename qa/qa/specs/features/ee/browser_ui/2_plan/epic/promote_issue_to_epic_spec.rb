# frozen_string_literal: true

module QA
  RSpec.describe 'Plan', feature_category: :portfolio_management do
    describe 'promote issue to epic' do
      let(:project) do
        create(:project, name: 'promote-issue-to-epic', description: 'Project to promote issue to epic')
      end

      let(:issue) { create(:issue, project: project) }

      before do
        Flow::Login.sign_in
      end

      it 'promotes issue to epic' do
        issue.visit!

        Page::Project::WorkItem::Show.perform do |show|
          # Due to the randomness of tests execution, sometimes a previous test
          # may have changed the filter, which makes the below action needed.
          # TODO: Make this test completely independent, not requiring the below step.
          show.select_all_activities_filter
          # We add a space together with the '/promote' string to avoid test flakiness
          # due to the tooltip '/promote Promote issue to an epic (may expose
          # confidential information)' from being shown, which may cause the click not
          # to work properly.
          show.comment('/promote_to epic')
        end

        project.group.visit!

        Page::Group::Menu.perform(&:go_to_epics)

        QA::EE::Page::Group::WorkItem::Epic::Index.perform do |index|
          expect(index).to have_epic_title(issue.title)
        end
      end
    end
  end
end
