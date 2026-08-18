# frozen_string_literal: true

module QA
  RSpec.describe 'Plan', feature_category: :team_planning do
    describe 'Group Iterations' do
      include QA::Support::Dates
      include ActiveSupport::Testing::TimeHelpers

      future_year = Time.now.year + 1

      before do
        Flow::Login.sign_in
      end

      context 'with automatic scheduling' do
        let(:title) { "Automatic group iteration cadence created via GUI #{SecureRandom.hex(8)}" }
        let(:start_date) { current_date_yyyy_mm_dd }
        let(:due_date) { thirteen_days_from_now_yyyy_mm_dd }
        let(:description) { "This is a group to test automatic iterations." }
        let(:iteration_period) { "Feb 1 – 14, #{future_year}" }
        let!(:iteration_group) do
          create(:group, path: "group-to-test-creating-automatic-iterations-#{SecureRandom.hex(8)}")
        end

        it 'creates a group iteration automatically through an iteration cadence' do
          # use an arbitrary fixed current date to make sure the iteration period formatting is always correct
          travel_to Time.utc(Time.now.year + 1, 2, 1) do
            EE::Resource::GroupCadence.fabricate_via_browser_ui! do |cadence|
              cadence.group = iteration_group
              cadence.title = title
              cadence.description = description
              cadence.start_date = start_date
              cadence.duration = 2
              cadence.upcoming_iterations = 2
            end

            EE::Page::Group::Iteration::Cadence::Index.perform do |cadence|
              cadence.retry_on_exception(reload: cadence) do
                cadence.open_iteration(title, iteration_period)
              end
            end

            EE::Page::Group::Iteration::Show.perform do |iteration|
              aggregate_failures "automatic iteration created successfully" do
                expect(iteration).to have_content("Feb 1 – 14, #{future_year}")
                expect(iteration).to have_burndown_chart
                expect(iteration).to have_burnup_chart
              end
            end
          end
        end
      end

      context 'with manual scheduling' do
        let(:title) { "Manual group iteration created via GUI #{SecureRandom.hex(8)}" }
        let(:start_date) { current_date_yyyy_mm_dd }
        let(:due_date) { next_month_yyyy_mm_dd }
        let(:description) { "This is a group to test manual iterations." }
        let(:iteration_period) { "Feb 1 – Mar 1, #{future_year}" }

        let!(:iteration_group) do
          create(:group, path: "group-to-test-creating-manual-iterations-#{SecureRandom.hex(8)}")
        end

        it 'creates a group iteration manually through an iteration cadence' do
          travel_to Time.utc(Time.now.year + 1, 2, 1) do
            EE::Resource::GroupIteration.fabricate_via_browser_ui! do |iteration|
              iteration.group = iteration_group
              iteration.title = title
              iteration.description = description
              iteration.start_date = start_date
              iteration.due_date = due_date
            end

            EE::Page::Group::Iteration::Show.perform do |iteration|
              aggregate_failures "manual iteration created successfully" do
                expect(iteration).to have_content("Feb 1 – Mar 1, #{future_year}")
                expect(iteration).to have_burndown_chart
                expect(iteration).to have_burnup_chart
              end
            end
          end
        end
      end
    end
  end
end
