# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::ReviewerAssignment::AssignService, feature_category: :code_review_workflow do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be_with_reload(:author) { create(:user) }
  let_it_be_with_reload(:reviewer1) { create(:user) }
  let_it_be_with_reload(:reviewer2) { create(:user) }

  let(:merge_request) { create(:merge_request, source_project: project, author: author) }
  let(:strategy) { instance_double(MergeRequests::ReviewerAssignment::CodeOwnersStrategy) }
  let(:reviewers) { [reviewer1, reviewer2] }

  subject(:service) { described_class.new(merge_request: merge_request, current_user: author) }

  before_all do
    project.add_developer(author)
    project.add_developer(reviewer1)
    project.add_developer(reviewer2)
  end

  before do
    stub_licensed_features(merge_request_approvers: true, multiple_merge_request_reviewers: true)
    project.project_setting.update!(reviewer_assignment_strategy: 'code_owners')

    allow(MergeRequests::ReviewerAssignment::StrategyFactory).to receive(:build).and_return(strategy)
    allow(strategy).to receive_messages(
      select_reviewers: reviewers,
      strategy_name: 'code_owners'
    )
  end

  describe '#execute' do
    context 'when license is not available' do
      before do
        stub_licensed_features(merge_request_approvers: false)
      end

      it 'returns skipped response' do
        result = service.execute

        expect(result).to be_success
        expect(result.message).to eq('Feature not available')
        expect(result.payload[:skipped]).to be true
      end
    end

    context 'when project setting is disabled' do
      before do
        project.project_setting.update!(reviewer_assignment_strategy: 'disabled')
      end

      it 'returns skipped response' do
        result = service.execute

        expect(result).to be_success
        expect(result.message).to eq('Feature disabled')
        expect(result.payload[:skipped]).to be true
      end
    end

    context 'when current_user lacks permission to assign reviewers' do
      let(:non_member) { create(:user) }

      subject(:service) { described_class.new(merge_request: merge_request, current_user: non_member) }

      it 'returns skipped response' do
        result = service.execute

        expect(result).to be_success
        expect(result.message).to eq('Insufficient permissions')
        expect(result.payload[:skipped]).to be true
      end
    end

    context 'when the only reviewer is the Duo code review bot' do
      let(:duo_bot) { create(:user, :duo_code_review_bot) }

      before do
        merge_request.reviewers = [duo_bot]
      end

      it 'proceeds with assignment alongside the bot' do
        result = service.execute

        expect(result).to be_success
        expect(merge_request.reload.reviewer_ids).to include(reviewer1.id, reviewer2.id, duo_bot.id)
      end
    end

    context 'when no strategy is available' do
      before do
        allow(MergeRequests::ReviewerAssignment::StrategyFactory).to receive(:build).and_return(nil)
      end

      it 'returns skipped response' do
        result = service.execute

        expect(result).to be_success
        expect(result.message).to eq('No strategy available')
        expect(result.payload[:skipped]).to be true
      end
    end

    context 'when strategy returns reviewers' do
      it 'assigns reviewers from strategy' do
        service.execute

        expect(merge_request.reload.reviewer_ids).to match_array([reviewer1.id, reviewer2.id])
      end

      it 'tracks the assignment event' do
        expect { service.execute }.to trigger_internal_events('auto_assign_reviewers').with(
          category: 'MergeRequests::ReviewerAssignment::AssignService',
          user: author,
          project: project,
          namespace: project.namespace,
          additional_properties: { label: 'code_owners', value: 2 }
        )
      end

      it 'returns success' do
        result = service.execute

        expect(result).to be_success
      end
    end

    context 'when strategy returns no eligible reviewers' do
      before do
        allow(strategy).to receive(:select_reviewers).and_return([])
      end

      it 'returns skipped response' do
        result = service.execute

        expect(result).to be_success
        expect(result.message).to eq('No eligible reviewers')
        expect(result.payload[:skipped]).to be true
      end
    end

    context 'when UpdateReviewersService fails to assign reviewers' do
      before do
        allow_next_instance_of(MergeRequests::UpdateReviewersService) do |svc|
          allow(svc).to receive(:execute).and_return(merge_request)
        end
      end

      it 'returns error response' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('Failed to assign reviewers')
        expect(merge_request.reset.reviewers).to be_empty
      end

      it 'does not track the assignment event' do
        expect { service.execute }.not_to trigger_internal_events('auto_assign_reviewers')
      end

      it 'logs the failure' do
        expect(Gitlab::AppLogger).to receive(:warn).with(
          message: 'Failed to assign reviewers',
          merge_request_id: merge_request.id,
          project_id: project.id
        )

        service.execute
      end
    end

    context 'when UpdateReviewersService raises ActiveRecord::RecordInvalid' do
      before do
        allow_next_instance_of(MergeRequests::UpdateReviewersService) do |svc|
          allow(svc).to receive(:execute).and_raise(ActiveRecord::RecordInvalid)
        end
      end

      it 'tracks the exception' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception)
          .with(instance_of(ActiveRecord::RecordInvalid), merge_request_id: merge_request.id)

        service.execute
      end

      it 'returns an error response' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to match(/Failed to assign reviewers/)
      end

      it 'does not track the assignment event' do
        expect { service.execute }.not_to trigger_internal_events('auto_assign_reviewers')
      end

      it 'logs the failure' do
        expect(Gitlab::AppLogger).to receive(:warn).with(
          hash_including(
            message: match(/Failed to assign reviewers/),
            merge_request_id: merge_request.id,
            project_id: project.id
          )
        )

        service.execute
      end
    end

    context 'when reviewer count equals the limit' do
      before do
        stub_const("Issuable::MAX_NUMBER_OF_ASSIGNEES_OR_REVIEWERS", 2)
      end

      it 'returns success without limit reached' do
        result = service.execute

        expect(result).to be_success
        expect(result.payload).not_to include(limit_reached: true)
      end
    end

    context 'when reviewer limit would be exceeded' do
      before do
        stub_const("Issuable::MAX_NUMBER_OF_ASSIGNEES_OR_REVIEWERS", 1)
      end

      it 'returns success with limit reached message' do
        result = service.execute

        expect(result).to be_success
        expect(result.message).to eq('Assigned reviewers limit reached')
        expect(result.payload[:limit_reached]).to be true
      end

      it 'assigns up to the limit' do
        service.execute

        expect(merge_request.reload.reviewers.count).to eq(1)
      end
    end

    context 'with real strategy integration' do
      let!(:approval_rule) do
        create(:code_owner_rule, merge_request: merge_request, users: [reviewer1, reviewer2], approvals_required: 1)
      end

      before do
        allow(MergeRequests::ReviewerAssignment::StrategyFactory).to receive(:build).and_call_original
      end

      it 'assigns reviewers end-to-end using the real strategy' do
        result = service.execute

        expect(result).to be_success
        expect(merge_request.reload.reviewer_ids).to match_array([reviewer1.id, reviewer2.id])
      end

      it 'excludes the MR author from assignment' do
        approval_rule.update!(users: [author, reviewer1])

        result = service.execute

        expect(result).to be_success
        expect(merge_request.reload.reviewer_ids).to contain_exactly(reviewer1.id)
      end
    end
  end
end
