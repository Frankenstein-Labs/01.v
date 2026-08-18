# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Boards::Issues::ListService, :services, feature_category: :planning_views do
  describe '#execute' do
    let_it_be(:user)    { create(:user) }
    let_it_be(:group) { create(:group, developers: user) }
    let_it_be(:project) { create(:project, :empty_repo, namespace: group) }
    let_it_be(:project1) { create(:project, :empty_repo, namespace: group) }
    let_it_be_with_reload(:board) { create(:board, group: group) }

    let_it_be(:m1) { create(:milestone, group: group) }
    let_it_be(:m2) { create(:milestone, group: group) }

    let_it_be(:bug) { create(:group_label, group: group, name: 'Bug') }
    let_it_be(:development) { create(:group_label, group: group, name: 'Development') }
    let_it_be(:testing) { create(:group_label, group: group, name: 'Testing') }

    let_it_be(:p1) { create(:group_label, title: 'P1', group: group) }
    let_it_be(:p2) { create(:group_label, title: 'P2', group: group) }
    let_it_be(:p3) { create(:group_label, title: 'P3', group: group) }

    let_it_be(:milestone) { create(:milestone, group: group) }
    let_it_be(:iteration) { create(:iteration, iterations_cadence: create(:iterations_cadence, group: group)) }
    let_it_be(:system_defined_status) { build(:work_item_system_defined_status, namespace: group) }
    let_it_be(:custom_status) { create(:work_item_custom_status, namespace: group) }

    let_it_be(:opened_issue1) { create(:labeled_issue, project: project, milestone: m1, weight: 9, title: 'Issue 1', labels: [bug]) }
    let_it_be(:opened_issue2) { create(:labeled_issue, project: project, milestone: m2, weight: 1, title: 'Issue 2', labels: [p2]) }
    let_it_be_with_reload(:opened_issue3) { create(:labeled_issue, project: project, milestone: m2, title: 'Assigned Issue', labels: [p3]) }
    let_it_be(:reopened_issue1) { create(:issue, state: 'opened', project: project, title: 'Issue 3', closed_at: Time.current) }

    let_it_be(:list1_issue1) { create(:labeled_issue, project: project, milestone: m1, labels: [p2, development]) }
    let_it_be(:list1_issue2) { create(:labeled_issue, project: project, milestone: m2, labels: [development]) }
    let_it_be(:list1_issue3) { create(:labeled_issue, project: project1, milestone: m1, labels: [development, p1]) }
    let_it_be(:list2_issue1) { create(:labeled_issue, project: project1, milestone: m1, labels: [testing]) }

    let_it_be(:closed_issue1) { create(:labeled_issue, :closed, project: project, labels: [bug]) }
    let_it_be(:closed_issue2) { create(:labeled_issue, :closed, project: project, labels: [p3]) }
    let_it_be(:closed_issue3) { create(:issue, :closed, project: project1, milestone: m1) }
    let_it_be(:closed_issue4) { create(:labeled_issue, :closed, project: project1, labels: [p1]) }
    let_it_be(:closed_issue5) { create(:labeled_issue, :closed, project: project1, labels: [development]) }

    let(:parent) { group }

    before do
      stub_licensed_features(
        board_assignee_lists: true,
        board_milestone_lists: true,
        board_iteration_lists: true,
        board_status_lists: true,
        work_item_status: true
      )

      opened_issue3.assignees.push(user_list.user)
    end

    context 'with assignee, milestone, iteration, label and status lists present' do
      let!(:user_list) { create(:user_list, board: board, position: 2) }
      let!(:milestone_list) { create(:milestone_list, board: board, position: 3, milestone: milestone) }
      let!(:iteration_list) { create(:iteration_list, board: board, position: 4, iteration: iteration) }
      let(:system_defined_status_list) { create(:status_list, :with_system_defined_status, board: board, position: 5, system_defined_status: system_defined_status) }
      let(:custom_status_list) { create(:status_list, :with_custom_status, board: board, position: 5, custom_status: custom_status) }

      let!(:backlog)   { board.lists.backlog.first }
      let!(:list1)     { create(:list, board: board, label: development, position: 0) }
      let!(:list2)     { create(:list, board: board, label: testing, position: 1) }
      let!(:closed)    { board.lists.closed.first }

      context 'milestone lists' do
        let!(:milestone_issue) { create(:labeled_issue, project: project, milestone: milestone_list.milestone, labels: [p3]) }

        it 'returns issues from milestone persisted in the list' do
          params = { board_id: board.id, id: milestone_list.id }

          issues = described_class.new(parent, user, params).execute

          expect(issues).to contain_exactly(milestone_issue)
        end

        context 'backlog list context' do
          it 'returns issues without milestones and without milestones from other lists' do
            params = { board_id: board.id, id: backlog.id }

            issues = described_class.new(parent, user, params).execute

            expect(issues).to contain_exactly(
              opened_issue1, # milestone from this issue is not in a list
              opened_issue2, # milestone from this issue is not in a list
              reopened_issue1 # has no milestone
            )
          end
        end
      end

      context 'iteration lists' do
        let!(:iteration_issue) { create(:labeled_issue, project: project, iteration: iteration, labels: [p3]) }

        let(:params) { { board_id: board.id, id: iteration_list.id } }

        subject(:issues) { described_class.new(parent.class.find(parent.id), user, params).execute }

        it 'returns issues from iteration persisted in the list' do
          expect(issues).to contain_exactly(iteration_issue)
        end

        context 'backlog list' do
          let(:params) { { board_id: board.id, id: backlog.id } }

          it 'excludes issues in the iteration list' do
            expect(issues).not_to include(iteration_issue)
          end

          context 'when feature is disabled' do
            before do
              stub_licensed_features(board_iteration_lists: false)
            end

            it 'includes issues in the iteration list' do
              expect(issues).to include(iteration_issue)
            end
          end
        end
      end

      context 'status lists' do
        shared_examples_for 'includes status issue' do
          it 'includes issues from the status list' do
            expect(issues).to include(status_issue)
          end
        end

        shared_examples_for 'excludes status issue' do
          it 'does not include issues from the status list' do
            expect(issues).not_to include(status_issue)
          end
        end

        shared_examples_for 'status list' do |status_type|
          context 'with only status mapping' do
            it_behaves_like 'includes status issue'
          end

          context 'with statuses set explicitly' do
            let!(:current_status) do
              create(:work_item_current_status, status_type => send(status_type), work_item_id: status_issue.id)
            end

            it_behaves_like 'includes status issue'
          end

          context 'with open/backlog list' do
            let(:params) { { board_id: board.id, id: backlog.id } }

            it_behaves_like 'excludes status issue'

            context 'when board_status_lists feature is not available' do
              before do
                stub_licensed_features(board_status_lists: false, work_item_status: true)
              end

              it_behaves_like 'includes status issue'
            end

            context 'when work_item_status feature is not available' do
              before do
                stub_licensed_features(board_status_lists: true, work_item_status: false)
              end

              it_behaves_like 'includes status issue'
            end
          end

          context 'with closed list' do
            let(:status_issue) { create(:issue, :closed, project: project) }
            let(:params) { { board_id: board.id, id: closed.id } }

            it_behaves_like 'includes status issue'

            context 'when board_status_lists feature is not available' do
              before do
                stub_licensed_features(board_status_lists: false, work_item_status: true)
              end

              it_behaves_like 'includes status issue'
            end

            context 'when work_item_status feature is not available' do
              before do
                stub_licensed_features(board_status_lists: true, work_item_status: false)
              end

              it_behaves_like 'includes status issue'
            end
          end
        end

        let(:status_issue) { create(:issue, project: project) }

        subject(:issues) { described_class.new(parent.class.find(parent.id), user, params).execute }

        context 'with a system-defined status list' do
          let(:params) { { board_id: board.id, id: system_defined_status_list.id } }

          before do
            system_defined_status_list
          end

          it_behaves_like 'status list', :system_defined_status
        end

        context 'with a custom status list' do
          let(:params) { { board_id: board.id, id: custom_status_list.id } }

          before do
            custom_status_list
          end

          it_behaves_like 'status list', :custom_status
        end
      end

      describe '#metadata' do
        it 'returns issues count and weight for list' do
          params = { board_id: board.id, id: backlog.id }

          metadata = described_class.new(parent, user, params).metadata

          expect(metadata[:size]).to eq(3)
          expect(metadata[:total_weight]).to eq(10)
        end

        # When collection is filtered by labels the ActiveRecord::Relation returns '{}' on #count or #sum
        # if no issues are found
        it 'returns 0 when filtering by labels and issues are not present' do
          params = { board_id: board.id, id: list1.id, label_name: [bug.title, p2.title] }

          metadata = described_class.new(parent, user, params).metadata

          expect(metadata[:size]).to eq(0)
          expect(metadata[:total_weight]).to eq(0)
        end

        context 'when total_issue_weight is not included in the required_fields' do
          it 'returns only issue count' do
            params = { board_id: board.id, id: backlog.id }

            metadata = described_class.new(parent, user, params).metadata([:issue_count])

            expect(metadata).to eq(size: 3)
          end
        end

        context 'when required_fields array is empty' do
          it 'returns empty hash' do
            params = { board_id: board.id, id: backlog.id }

            metadata = described_class.new(parent, user, params).metadata([])

            expect(metadata).to eq({})
          end
        end
      end

      context 'when list_id is missing' do
        context 'when board is not scoped by milestone' do
          it 'returns opened issues without board labels and assignees applied' do
            params = { board_id: board.id }

            issues = described_class.new(parent, user, params).execute

            expect(issues).to match_array([opened_issue2, reopened_issue1, opened_issue1])
          end
        end

        context 'when board is scoped by milestone' do
          it 'returns opened issues without board labels, assignees, or milestone applied' do
            params = { board_id: board.id }
            board.update_attribute(:milestone, m1)

            issues = described_class.new(parent, user, params).execute

            expect(issues)
              .to match_array([opened_issue2, list1_issue2, reopened_issue1, opened_issue1])
          end

          context 'when milestone is predefined' do
            let(:params) { { board_id: board.id, id: backlog.id } }

            context 'as upcoming' do
              before do
                board.update!(milestone_id: Milestone::Upcoming.id)
              end

              it 'returns open issue for backlog without board label or assignees' do
                issues = described_class.new(parent, user, params).execute

                expect(issues).to match_array([opened_issue2, reopened_issue1, opened_issue1])
              end
            end

            context 'as started' do
              before do
                board.update!(milestone_id: Milestone::Started.id)
              end

              it 'returns open issue for backlog without board label or assignees' do
                issues = described_class.new(parent, user, params).execute

                expect(issues).to match_array([opened_issue2, reopened_issue1, opened_issue1])
              end
            end
          end

          context 'when :all_lists param is set' do
            let(:params) { { board_id: board.id, all_lists: true, milestone_title: m1.title } }

            it 'returns matching issues in all board lists' do
              issues = described_class.new(parent, user, params).execute

              expect(issues).to match_array([opened_issue1, list1_issue1,
                list1_issue3, list2_issue1, closed_issue3])
            end
          end
        end
      end

      context 'when search param is present' do
        it 'returns correct issues' do
          params = { board_id: board.id, search: 'Issue' }

          issues = described_class.new(parent, user, params).execute
          expect(issues).to contain_exactly(opened_issue1, opened_issue2, reopened_issue1)
        end
      end

      context 'when test cases are present' do
        it 'filters out test cases' do
          create(:quality_test_case, project: project, milestone: m1, title: 'Test Case 1', labels: [development])
          incident = create(:incident, project: project, milestone: m1, title: 'Incident 1', labels: [development])
          params = { board_id: board.id, id: list1.id }

          issues = described_class.new(parent, user, params).execute

          expect(issues).to match_array([list1_issue1, list1_issue2, list1_issue3, incident])
        end
      end

      context 'when filtering by custom work item type' do
        let_it_be(:converted_custom_type) do
          create(:work_item_custom_type, :converted_from_issue, :with_organization, organization: group.organization)
        end

        let_it_be(:non_converted_custom_type) do
          create(:work_item_custom_type, :with_organization, organization: group.organization, name: 'Feature')
        end

        let_it_be(:issue_with_converted_type) do
          create(:labeled_issue, project: project, labels: [development], work_item_type: converted_custom_type)
        end

        let_it_be(:issue_with_non_converted_type) do
          create(:labeled_issue, project: project, labels: [development], work_item_type: non_converted_custom_type)
        end

        before do
          stub_licensed_features(configurable_work_item_types: true)
        end

        it 'filters by non-converted custom work item type id' do
          params = { board_id: board.id, id: list1.id, work_item_type_ids: [non_converted_custom_type.id] }

          expect(described_class.new(parent, user, params).execute).to contain_exactly(issue_with_non_converted_type)
        end

        it 'filters by converted_from_system_defined_type_identifier' do
          params = {
            board_id: board.id,
            id: list1.id,
            work_item_type_ids: [converted_custom_type.converted_from_system_defined_type_identifier]
          }

          expect(described_class.new(parent, user, params).execute)
            .to contain_exactly(list1_issue1, list1_issue2, list1_issue3, issue_with_converted_type)
        end

        it 'filters by converted_from_system_defined_type_identifier combined with custom type id' do
          params = {
            board_id: board.id,
            id: list1.id,
            work_item_type_ids: [
              converted_custom_type.converted_from_system_defined_type_identifier,
              non_converted_custom_type.id
            ]
          }

          expect(described_class.new(parent, user, params).execute)
            .to contain_exactly(list1_issue1, list1_issue2, list1_issue3, issue_with_converted_type, issue_with_non_converted_type)
        end

        it 'excludes non-converted custom work item type with negated filter' do
          params = { board_id: board.id, id: list1.id, not: { work_item_type_ids: [non_converted_custom_type.id] } }

          expect(described_class.new(parent, user, params).execute)
            .to contain_exactly(list1_issue1, list1_issue2, list1_issue3, issue_with_converted_type)
        end

        it 'excludes issues matching converted_from_system_defined_type_identifier with negated filter' do
          params = {
            board_id: board.id,
            id: list1.id,
            not: { work_item_type_ids: [converted_custom_type.converted_from_system_defined_type_identifier] }
          }

          expect(described_class.new(parent, user, params).execute)
            .to contain_exactly(issue_with_non_converted_type)
        end

        it 'excludes issues with negated filter combining converted identifier and custom type id' do
          params = {
            board_id: board.id,
            id: list1.id,
            not: {
              work_item_type_ids: [
                converted_custom_type.converted_from_system_defined_type_identifier,
                non_converted_custom_type.id
              ]
            }
          }

          expect(described_class.new(parent, user, params).execute).to be_empty
        end
      end
    end
  end
end
