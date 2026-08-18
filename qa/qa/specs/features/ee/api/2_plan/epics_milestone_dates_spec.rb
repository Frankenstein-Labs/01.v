# frozen_string_literal: true

# rubocop:disable Rails/Date -- e2e specs do not set the timezone
module QA
  RSpec.describe 'Plan', feature_category: :portfolio_management do
    include Support::API

    describe 'Epics milestone dates API' do
      let(:milestone_start_date) { (Date.today + 100).iso8601 }
      let(:milestone_due_date) { (Date.today + 120).iso8601 }
      let(:fixed_start_date) { Date.today.iso8601 }
      let(:fixed_due_date) { (Date.today + 90).iso8601 }
      let(:api_client) { Runtime::User::Store.test_user.api_client }
      let(:group) { create(:group, path: "epic-milestone-group-#{SecureRandom.hex(8)}") }
      let(:project) { create(:project, name: "epic-milestone-project-#{SecureRandom.hex(8)}", group: group) }
      let(:wait_args) { { max_duration: 120, sleep_interval: 1 } }

      it 'updates epic dates when updating milestones' do
        epic, milestone = create_epic_issue_milestone
        new_milestone_start_date = (Date.today + 20).iso8601
        new_milestone_due_date = (Date.today + 30).iso8601

        # Update Milestone to different dates and see it reflecting in the epics
        request = create_request("/projects/#{project.id}/milestones/#{milestone.id}")
        response = Support::API.put(request.url, start_date: new_milestone_start_date, due_date: new_milestone_due_date)
        expect(response.code).to eq(Support::API::HTTP_STATUS_OK)

        epic.reload!

        expect_epic_to_have_updated_dates(epic, new_milestone_start_date, new_milestone_due_date)
      end

      it 'updates epic dates when adding another issue', :smoke do
        epic = create_epic_issue_milestone[0]
        new_milestone_start_date = Date.today.iso8601
        new_milestone_due_date = (Date.today + 150).iso8601

        # Add another Issue and milestone
        second_milestone = create_milestone(new_milestone_start_date, new_milestone_due_date)
        second_issue = create_issue(second_milestone)
        add_issue_to_epic(epic, second_issue)

        epic.reload!

        aggregate_failures do
          expect_epic_to_have_updated_dates(epic, new_milestone_start_date, new_milestone_due_date)

          if epic.instance_of?(QA::EE::Resource::WorkItemEpic)
            expect_epic_to_have_updated_milestone(epic, second_milestone)
          end
        end
      end

      it 'updates epic dates when removing issue', :smoke do
        epic = create_epic_issue_milestone[0]
        issue_id = epic.child_items[0][:id]

        epic.remove_child_items(issue_id)
        epic.reload!

        expect_epic_to_have_updated_dates(epic, nil, nil)
      end

      it 'updates epic dates when deleting milestones' do
        epic, milestone = create_epic_issue_milestone

        milestone.remove_via_api!
        epic.reload!

        aggregate_failures do
          expect_epic_to_have_updated_dates(epic, nil, nil)

          if epic.instance_of?(QA::EE::Resource::WorkItemEpic)
            expect { epic.reload!.start_date_sourcing_milestone }
              .to eventually_eq(nil).within(wait_args)
            expect { epic.reload!.due_date_sourcing_milestone }
              .to eventually_eq(nil).within(wait_args)
          end
        end
      end

      private

      def create_epic_issue_milestone
        epic = create_epic
        milestone = create_milestone(milestone_start_date, milestone_due_date)
        issue = create_issue(milestone)
        add_issue_to_epic(epic, issue)
        use_epics_milestone_dates(epic, milestone)
        [epic, milestone]
      end

      def create_request(api_endpoint)
        Runtime::API::Request.new(api_client, api_endpoint)
      end

      def create_issue(milestone)
        create(:issue, title: 'My Test Issue', project: project, milestone: milestone)
      end

      def create_milestone(start_date, due_date)
        create(:project_milestone, project: project, start_date: start_date, due_date: due_date)
      end

      def create_epic
        create(:work_item_epic,
          group: group,
          title: 'My New Epic',
          is_fixed: true,
          start_date: fixed_start_date,
          due_date: fixed_due_date)
      end

      def add_issue_to_epic(epic, issue)
        # Add Issue with milestone to an epic
        epic.add_child_item(issue.id)
        epic.reload!

        expect(epic.title).to eq('My New Epic')
        expect(epic.child_items[0][:name]).to eq('My Test Issue')
      end

      def use_epics_milestone_dates(epic, milestone)
        # Update Epic to use Milestone Dates
        epic.set_is_fixed(fixed: false)
        epic.reload!

        aggregate_failures do
          expect_epic_to_have_updated_dates(epic, milestone_start_date, milestone_due_date)
          expect_epic_to_have_updated_milestone(epic, milestone)
          expect(epic.fixed?).to be(false)
        end
      end

      def expect_epic_to_have_updated_dates(epic, new_milestone_start_date, new_milestone_due_date)
        aggregate_failures do
          expect { epic.reload!.start_date }
            .to eventually_eq(new_milestone_start_date).within(wait_args)
          expect { epic.reload!.due_date }
            .to eventually_eq(new_milestone_due_date).within(wait_args)
        end
      end

      def expect_epic_to_have_updated_milestone(epic, milestone)
        expected_id = "gid://gitlab/Milestone/#{milestone.id}"

        aggregate_failures do
          expect { epic.reload!.start_date_sourcing_milestone&.dig(:id) }
            .to eventually_eq(expected_id).within(wait_args)
          expect { epic.reload!.due_date_sourcing_milestone&.dig(:id) }
            .to eventually_eq(expected_id).within(wait_args)
        end
      end
    end
  end
end
# rubocop:enable Rails/Date
