# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Iterations::RollOverIssuesService, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:closed_iteration1) { create(:closed_iteration, group: group) }
  let_it_be(:closed_iteration2) { create(:closed_iteration, group: group) }
  let_it_be(:current_iteration) { create(:current_iteration, group: group) }
  let_it_be(:open_issues) { [create(:issue, :opened, iteration: closed_iteration1)] }
  let_it_be(:closed_issues) { [create(:issue, :closed, iteration: closed_iteration1)] }

  let(:from_iteration) { closed_iteration1 }
  let(:to_iteration) { current_iteration }

  subject { execute_service }

  context 'when from iteration or null iteration or both are nil' do
    context 'when to iteration is nil' do
      let(:to_iteration) { nil }

      it { is_expected.to be_error }
    end

    context 'when from iteration is nil' do
      let(:from_iteration) { nil }

      it { is_expected.to be_error }
    end

    context 'when both from_iteration and to_iteration are nil' do
      let(:from_iteration) { nil }
      let(:to_iteration) { nil }

      it { is_expected.to be_error }
    end
  end

  context 'when iterations are present' do
    context 'when issues are rolled-over to a closed iteration' do
      let(:to_iteration) { closed_iteration2 }

      it { is_expected.to be_error }
    end

    context 'when user does not have permission to roll-over issues' do
      context 'when user is not a team member' do
        it { is_expected.to be_error }
      end

      context 'when user is a bot other than automation bot' do
        let(:user) { Users::Internal.in_organization(group.organization).security_bot }

        it { is_expected.to be_error }
      end

      context 'when user is a Guest' do
        before_all do
          group.add_guest(user)
        end

        it { is_expected.to be_error }

        it 'does not triggers note created subscription' do
          expect(GraphqlTriggers).not_to receive(:work_item_note_created)

          subject
        end
      end
    end

    context 'when user has permissions to roll-over issues' do
      context 'when user is a Reporter' do
        before_all do
          group.add_reporter(user)
        end

        it { is_expected.not_to be_error }
      end

      context 'when user is the automation bot' do
        let(:user) { Users::Internal.in_organization(group.organization_id).automation_bot }

        it { is_expected.not_to be_error }

        it 'rolls-over issues to next iteration' do
          expect(current_iteration.issues).to be_empty
          expect(closed_iteration1.issues).to match_array(open_issues + closed_issues)

          expect do
            execute_service(from: closed_iteration1, to: current_iteration)
          end.to change { ResourceIterationEvent.count }.by(2)

          created_iteration_events = ResourceIterationEvent.last(2)
          open_issue = open_issues.first

          expect(current_iteration.reload.issues).to match_array(open_issues)
          expect(closed_iteration1.reload.issues).to match_array(closed_issues)
          expect(created_iteration_events.pluck(:iteration_id, :issue_id, :namespace_id)).to contain_exactly(
            [current_iteration.id, open_issue.id, group.id],
            [closed_iteration1.id, open_issue.id, group.id]
          )
        end

        it 'does not produce N+1 queries' do
          execute_service(from: closed_iteration1, to: current_iteration) # warm-up

          new_iteration1 = create(:current_iteration, group: group)
          control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
            execute_service(to: new_iteration1, from: current_iteration)
          end

          create(:issue, :opened, iteration: new_iteration1)
          new_iteration2 = create(:current_iteration, group: group)

          expect { execute_service(to: new_iteration2, from: new_iteration1) }.to issue_same_number_of_queries_as(
            control
          )
        end

        it 'triggers note created subscription' do
          # since we have one open issue it gets 2 events:
          # 1. for the removed closed iteration
          # 2. for the new current iteration
          expect(GraphqlTriggers).to receive(:work_item_note_created).twice

          subject
        end
      end
    end
  end

  def execute_service(from: from_iteration, to: to_iteration)
    described_class.new(user, from, to).execute
  end
end
