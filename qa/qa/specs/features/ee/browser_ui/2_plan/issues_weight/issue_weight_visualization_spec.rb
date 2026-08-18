# frozen_string_literal: true

module QA
  RSpec.describe 'Plan', feature_category: :team_planning do
    describe 'Issues weight visualization' do
      before do
        Flow::Login.sign_in
      end

      let(:milestone) { create(:project_milestone) }
      let(:weight) { 1000 }
      let(:issue) { create(:issue, milestone: milestone, project: milestone.project, weight: weight) }

      it 'shows the set weight in the issue page, in the milestone page, and in the issues list page' do
        issue.visit!

        Page::Project::WorkItem::Show.perform do |show|
          show.close_dap_panel_if_exists
          expect(show.weight_label_value).to have_content(weight)

          show.click_milestone_link
        end

        Page::Milestone::Show.perform do |show|
          show.expand_sidebar_if_collapsed
          expect(show.total_issue_weight_value).to have_content(weight)
        end

        Page::Project::Menu.perform(&:go_to_work_items)

        Page::Project::WorkItem::Index.perform do |index|
          expect(index.issuable_weight).to have_content(weight)
        end
      end
    end
  end
end
