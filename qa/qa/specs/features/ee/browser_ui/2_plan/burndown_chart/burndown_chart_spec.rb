# frozen_string_literal: true

module QA
  RSpec.describe 'Plan', feature_category: :team_planning do
    describe 'Burndown chart' do
      include ::QA::Support::Dates

      let(:milestone) do
        create(:project_milestone, start_date: current_date_yyyy_mm_dd, due_date: next_month_yyyy_mm_dd)
      end

      before do
        Flow::Login.sign_in

        create_list(:issue, 2, project: milestone.project, milestone: milestone, weight: 2)
      end

      it 'shows burndown chart on milestone page' do
        milestone.visit!

        Page::Milestone::Show.perform do |show|
          expect(show.burndown_chart).to be_visible
          expect(show.burndown_chart).to have_content("Remaining")

          show.click_weight_button

          expect(show.burndown_chart).to have_content('Remaining')
        end
      end
    end
  end
end
