# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::ReloadMergeHeadDiffService, feature_category: :code_review_workflow do
  let(:merge_request) { create(:merge_request) }
  let(:pending) { ::MergeRequests::ReviewerAssignment::PendingInitialAssignment }

  subject { described_class.new(merge_request).execute }

  describe '#execute' do
    before do
      MergeRequests::MergeToRefService
        .new(project: merge_request.project, current_user: merge_request.author)
        .execute(merge_request)
    end

    context 'code_owners feature is available' do
      before do
        stub_licensed_features(code_owners: true)
      end

      context 'when reloading was successful' do
        context 'when merge request is not on a merge train' do
          it 'syncs code owner approval rules' do
            sync_service = instance_double(MergeRequests::SyncCodeOwnerApprovalRules)
            expect(sync_service).to receive(:execute)
            expect(MergeRequests::SyncCodeOwnerApprovalRules).to receive(:new)
              .with(merge_request)
              .and_return(sync_service)
            expect(subject[:status]).to eq(:success)
          end
        end

        context 'when merge request is on a merge train' do
          let(:merge_request) { create(:merge_request, :on_train) }

          it 'does not sync code owner approval rules' do
            expect(MergeRequests::SyncCodeOwnerApprovalRules).not_to receive(:new)
            expect(subject[:status]).to eq(:success)
          end
        end
      end

      context 'when reloading failed' do
        before do
          allow(merge_request).to receive(:build_merge_head_diff).and_raise('fail')
        end

        it 'does not sync code owner approval rules' do
          expect(MergeRequests::SyncCodeOwnerApprovalRules).not_to receive(:new)
          expect(subject[:status]).to eq(:error)
        end
      end
    end

    context 'code_owners feature is not available' do
      before do
        stub_licensed_features(code_owners: false)
      end

      context 'when reloading was successful' do
        it 'does not sync code owner approval rules' do
          expect(MergeRequests::SyncCodeOwnerApprovalRules).not_to receive(:new)
          expect(subject[:status]).to eq(:success)
        end
      end
    end

    describe 'auto reviewer assignment' do
      before do
        stub_licensed_features(code_owners: true)
        allow(MergeRequests::SyncCodeOwnerApprovalRules).to receive(:new).and_return(
          instance_double(MergeRequests::SyncCodeOwnerApprovalRules, execute: nil)
        )
      end

      context 'when the pending initial-assignment flag is set' do
        before do
          allow(pending).to receive(:consume).with(merge_request).and_return(true)
        end

        it 'enqueues the auto assign reviewers worker' do
          expect(::MergeRequests::AutoAssignReviewersWorker).to receive(:perform_async).with(merge_request.id)

          subject
        end

        context 'without the code_owners licensed feature' do
          before do
            stub_licensed_features(code_owners: false)
          end

          it 'does not enqueue the auto assign reviewers worker' do
            expect(pending).not_to receive(:consume)
            expect(::MergeRequests::AutoAssignReviewersWorker).not_to receive(:perform_async)

            subject
          end
        end

        context 'when the merge request is on a merge train' do
          let(:merge_request) { create(:merge_request, :on_train) }

          it 'does not enqueue the auto assign reviewers worker' do
            expect(pending).not_to receive(:consume)
            expect(::MergeRequests::AutoAssignReviewersWorker).not_to receive(:perform_async)

            subject
          end
        end

        context 'when reloading the merge head diff fails' do
          before do
            allow(merge_request).to receive(:build_merge_head_diff).and_raise('fail')
          end

          it 'does not enqueue the auto assign reviewers worker' do
            expect(pending).not_to receive(:consume)
            expect(::MergeRequests::AutoAssignReviewersWorker).not_to receive(:perform_async)

            subject
          end
        end
      end

      context 'when the pending initial-assignment flag is not set' do
        before do
          allow(pending).to receive(:consume).with(merge_request).and_return(false)
        end

        it 'does not enqueue the auto assign reviewers worker' do
          expect(::MergeRequests::AutoAssignReviewersWorker).not_to receive(:perform_async)

          subject
        end
      end
    end
  end
end
