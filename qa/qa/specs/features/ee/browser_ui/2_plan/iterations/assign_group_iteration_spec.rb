# frozen_string_literal: true

module QA
  RSpec.describe 'Plan', feature_category: :team_planning do
    describe 'Assign Iterations' do
      include QA::Support::Dates

      let!(:start_date) { current_date_yyyy_mm_dd }
      let!(:due_date) { thirteen_days_from_now_yyyy_mm_dd }

      let(:iteration_group) { create(:group, path: "group-to-test-assigning-iterations-#{SecureRandom.hex(8)}") }
      let(:period) { iteration_period(start_date, due_date) }
      let(:period_display) { iteration_period(start_date, due_date, use_thin_space: false) }

      let(:project) do
        create(:project, name: "project-to-test-iterations-#{SecureRandom.hex(8)}", group: iteration_group)
      end

      let(:issue) { create(:issue, project: project, title: "issue-to-test-iterations-#{SecureRandom.hex(8)}") }

      let(:group_iteration) do
        create(:group_iteration, group: iteration_group, start_date: start_date, due_date: due_date)
      end

      before do
        Flow::Login.sign_in
      end

      it(
        'assigns a group iteration to an existing issue',
        except: { subdomain: 'pre' }
      ) do
        issue.visit!

        Page::Project::WorkItem::Show.perform do |issue|
          issue.assign_iteration(period, period_display, group_iteration)

          expect(issue).to have_iteration(period_display)

          issue.click_iteration(period_display)
        end

        EE::Page::Group::Iteration::Show.perform do |iteration|
          aggregate_failures "iteration created successfully" do
            expect(iteration).to have_content(period_display)
            expect(iteration).to have_issue(issue)
          end
        end
      end
    end
  end
end
