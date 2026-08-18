# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::ApprovalRulesSyncCoordinator, :clean_gitlab_redis_shared_state,
  feature_category: :code_review_workflow do
  let_it_be(:merge_request) { create(:merge_request) }
  let(:oldrev) { 'abc123' }
  let(:newrev) { 'def456' }
  let(:coordinator) { described_class.new(merge_request, oldrev: oldrev, newrev: newrev) }

  let(:reset_params) do
    {
      project_id: merge_request.project_id,
      user_id: create(:user).id,
      ref: 'refs/heads/feature',
      newrev: newrev,
      oldrev: oldrev
    }
  end

  describe '#sync_code_owners!' do
    it 'executes SyncCodeOwnerApprovalRules' do
      expect_next_instance_of(::MergeRequests::SyncCodeOwnerApprovalRules, merge_request) do |service|
        expect(service).to receive(:execute)
      end

      coordinator.sync_code_owners!
    end

    it 'marks the MR as temporarily unapproved during the sync' do
      allow_next_instance_of(::MergeRequests::SyncCodeOwnerApprovalRules) do |service|
        allow(service).to receive(:execute) do
          expect(merge_request.approval_state.temporarily_unapproved?).to be(true)
        end
      end

      coordinator.sync_code_owners!
    end

    it 'clears the sync key after the sync completes' do
      coordinator.sync_code_owners!

      expect(merge_request.approval_state.temporarily_unapproved?).to be(false)
    end

    it 'clears the sync key even when the sync raises' do
      allow_next_instance_of(::MergeRequests::SyncCodeOwnerApprovalRules) do |service|
        allow(service).to receive(:execute).and_raise(StandardError, 'boom')
      end

      expect { coordinator.sync_code_owners! }.to raise_error(StandardError, 'boom')
      expect(merge_request.approval_state.temporarily_unapproved?).to be(false)
    end

    it 'drains pending reset params when the sync completes' do
      # Simulate another push scheduling a reset while this sync is in progress:
      # manually mark a code owner sync as in-progress, then schedule -> params are queued.
      coordinator.start_approval_rules_sync!(:code_owner, 'other')
      coordinator.schedule_reset_approvals!(**reset_params)
      coordinator.finish_approval_rules_sync!(:code_owner, 'other')

      expect(MergeRequestResetApprovalsWorker).to receive(:perform_async).with(
        reset_params[:project_id],
        reset_params[:user_id],
        reset_params[:ref],
        reset_params[:newrev],
        reset_params[:oldrev]
      )

      coordinator.sync_code_owners!
    end
  end

  describe '#start_code_owner_sync!' do
    it 'marks the MR as temporarily unapproved' do
      coordinator.start_code_owner_sync!

      expect(merge_request.approval_state.temporarily_unapproved?).to be(true)
    end

    context 'when oldrev and newrev are not provided' do
      let(:coordinator) { described_class.new(merge_request) }

      it 'uses the create-flow sync key' do
        coordinator.start_code_owner_sync!

        expect(coordinator.any_approval_rules_syncing?(:code_owner)).to be(true)
      end
    end
  end

  describe '#start_reset_approvals!' do
    it 'marks the MR as temporarily unapproved' do
      coordinator.start_reset_approvals!

      expect(merge_request.approval_state.temporarily_unapproved?).to be(true)
    end

    context 'when oldrev and newrev are not provided' do
      let(:coordinator) { described_class.new(merge_request) }

      it 'raises ArgumentError' do
        expect { coordinator.start_reset_approvals! }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#finish_reset_approvals!' do
    it 'clears the reset tracking' do
      coordinator.start_reset_approvals!
      coordinator.finish_reset_approvals!

      expect(merge_request.approval_state.temporarily_unapproved?).to be(false)
    end

    it 'only clears the matching reset key' do
      coordinator.start_reset_approvals!
      described_class.new(merge_request, oldrev: 'other-old', newrev: 'other-new').start_reset_approvals!

      coordinator.finish_reset_approvals!

      expect(merge_request.approval_state.temporarily_unapproved?).to be(true)
    end
  end

  describe '#schedule_reset_approvals!' do
    context 'when no code owner sync is in progress' do
      it 'enqueues MergeRequestResetApprovalsWorker immediately' do
        expect(MergeRequestResetApprovalsWorker).to receive(:perform_async).with(
          reset_params[:project_id],
          reset_params[:user_id],
          reset_params[:ref],
          reset_params[:newrev],
          reset_params[:oldrev]
        )

        coordinator.schedule_reset_approvals!(**reset_params)
      end
    end

    context 'when a code owner sync is in progress' do
      before do
        coordinator.start_approval_rules_sync!(:code_owner, "#{oldrev}:#{newrev}")
      end

      it 'does not enqueue the reset worker' do
        expect(MergeRequestResetApprovalsWorker).not_to receive(:perform_async)

        coordinator.schedule_reset_approvals!(**reset_params)
      end

      it 'queues the params for later' do
        coordinator.schedule_reset_approvals!(**reset_params)

        # Completing the code owner sync (via a separate coordinator call) should drain the queue.
        expect(MergeRequestResetApprovalsWorker).to receive(:perform_async).with(
          reset_params[:project_id],
          reset_params[:user_id],
          reset_params[:ref],
          reset_params[:newrev],
          reset_params[:oldrev]
        )

        described_class.new(merge_request, oldrev: oldrev, newrev: newrev).sync_code_owners!
      end

      it 'enqueues the worker itself if the sync finishes between the check and the store' do
        # Simulate the race: the sync clears between code_owner_sync_in_progress? and the store.
        # The coordinator's post-store re-drain should catch the stranded params.
        allow(coordinator).to receive(:store_pending_reset_params!).and_wrap_original do |m, *args|
          m.call(*args)
          coordinator.finish_approval_rules_sync!(:code_owner, "#{oldrev}:#{newrev}")
        end

        expect(MergeRequestResetApprovalsWorker).to receive(:perform_async).with(
          reset_params[:project_id],
          reset_params[:user_id],
          reset_params[:ref],
          reset_params[:newrev],
          reset_params[:oldrev]
        )

        coordinator.schedule_reset_approvals!(**reset_params)
      end
    end

    it 'drains multiple queued reset params when the sync completes' do
      coordinator.start_approval_rules_sync!(:code_owner, 'other')

      coordinator.schedule_reset_approvals!(**reset_params)
      coordinator.schedule_reset_approvals!(**reset_params.merge(newrev: 'second-newrev'))

      coordinator.finish_approval_rules_sync!(:code_owner, 'other')

      expect(MergeRequestResetApprovalsWorker).to receive(:perform_async).twice

      coordinator.sync_code_owners!
    end
  end

  describe '#any_sync_in_progress?' do
    it 'returns false when no syncs are tracked' do
      expect(coordinator.any_sync_in_progress?).to be(false)
    end

    it 'returns true when a code_owner sync is in progress' do
      coordinator.start_code_owner_sync!

      expect(coordinator.any_sync_in_progress?).to be(true)
    end

    it 'returns true when a reset_approvals sync is in progress' do
      coordinator.start_reset_approvals!

      expect(coordinator.any_sync_in_progress?).to be(true)
    end

    it 'returns false after all syncs finish' do
      coordinator.start_code_owner_sync!
      coordinator.start_reset_approvals!

      coordinator.finish_approval_rules_sync!(:code_owner, "#{oldrev}:#{newrev}")
      coordinator.finish_reset_approvals!

      expect(coordinator.any_sync_in_progress?).to be(false)
    end
  end

  describe '#clear_sync_state!' do
    it 'removes in-progress entries for every sync type' do
      coordinator.start_code_owner_sync!
      coordinator.start_reset_approvals!

      coordinator.clear_sync_state!

      expect(coordinator.any_sync_in_progress?).to be(false)
    end

    it 'is safe to call when nothing is tracked' do
      expect { coordinator.clear_sync_state! }.not_to raise_error
    end
  end

  describe '#start_approval_rules_sync!' do
    it 'marks the given sync type as in progress' do
      coordinator.start_approval_rules_sync!(:code_owner, 'abc123')

      expect(coordinator.any_approval_rules_syncing?(:code_owner)).to be(true)
    end

    it 'tracks multiple sync types independently' do
      coordinator.start_approval_rules_sync!(:code_owner, 'abc123')
      coordinator.start_approval_rules_sync!(:reset_approvals, 'abc123')

      coordinator.finish_approval_rules_sync!(:code_owner, 'abc123')

      expect(coordinator.any_approval_rules_syncing?(:code_owner)).to be(false)
      expect(coordinator.any_approval_rules_syncing?(:reset_approvals)).to be(true)
    end

    it 'sets a TTL on the syncing key' do
      coordinator.start_approval_rules_sync!(:code_owner, 'abc123')

      ttl = Gitlab::Redis::SharedState.with do |redis|
        redis.ttl("mr_#{merge_request.id}_syncing_code_owner")
      end

      expect(ttl).to be > 0
      expect(ttl).to be <= described_class::SYNC_TTL
    end

    it 'raises when given an unknown sync type' do
      expect { coordinator.start_approval_rules_sync!(:unknown, 'abc123') }.to raise_error(ArgumentError)
    end
  end

  describe '#finish_approval_rules_sync!' do
    it 'removes the matching sync entry' do
      coordinator.start_approval_rules_sync!(:code_owner, 'abc123')

      coordinator.finish_approval_rules_sync!(:code_owner, 'abc123')

      expect(coordinator.any_approval_rules_syncing?(:code_owner)).to be(false)
    end

    it 'tracks concurrent entries for the same sync type independently' do
      coordinator.start_approval_rules_sync!(:reset_approvals, 'abc123')
      coordinator.start_approval_rules_sync!(:reset_approvals, 'def456')

      coordinator.finish_approval_rules_sync!(:reset_approvals, 'abc123')

      expect(coordinator.any_approval_rules_syncing?(:reset_approvals)).to be(true)

      coordinator.finish_approval_rules_sync!(:reset_approvals, 'def456')

      expect(coordinator.any_approval_rules_syncing?(:reset_approvals)).to be(false)
    end

    it 'is safe to call when no syncs are in progress' do
      expect { coordinator.finish_approval_rules_sync!(:code_owner, 'abc123') }.not_to raise_error
    end
  end

  describe '#any_approval_rules_syncing?' do
    it 'returns true when a sync of the given type is in progress' do
      coordinator.start_approval_rules_sync!(:code_owner, 'abc123')

      expect(coordinator.any_approval_rules_syncing?(:code_owner)).to be(true)
    end

    it 'returns false when no syncs of the given type exist' do
      coordinator.start_approval_rules_sync!(:reset_approvals, 'abc123')

      expect(coordinator.any_approval_rules_syncing?(:code_owner)).to be(false)
    end

    it 'raises when given an unknown sync type' do
      expect { coordinator.any_approval_rules_syncing?(:unknown) }.to raise_error(ArgumentError)
    end
  end
end
