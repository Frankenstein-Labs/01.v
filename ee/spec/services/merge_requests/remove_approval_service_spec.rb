# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::RemoveApprovalService, feature_category: :code_review_workflow do
  describe '#execute' do
    let(:user) { create(:user) }
    let(:project) { create(:project, approvals_before_merge: 1) }
    let(:merge_request) { create(:merge_request, source_project: project) }

    subject(:service) { described_class.new(project: project, current_user: user) }

    def execute!
      service.execute(merge_request)
    end

    before do
      # Add the main user to the project with approval permissions
      project.add_developer(user)
    end

    context 'with a user who has approved' do
      let!(:approval) { create(:approval, merge_request: merge_request, user: user) }

      it 'removes the approval' do
        expect { execute! }.to change { merge_request.approvals.size }.from(1).to(0)
      end

      it 'creates an unapproval note' do
        expect(SystemNoteService).to receive(:unapprove_mr)

        execute!
      end

      it 'resets the cache for approvals' do
        expect(merge_request).to receive(:reset_approval_cache!)

        execute!
      end

      context 'when MR becomes unapproved after removal' do
        # Default case: Only 1 approval exists, removing it makes MR unapproved
        it 'changes approval state from approved to unapproved' do
          expect { execute! }.to change { merge_request.approved? }.from(true).to(false)
        end

        it 'fires an unapproved webhook' do
          expect(service).to receive(:execute_hooks).with(merge_request, 'unapproved')

          execute!
        end

        it 'does not fire an unapproval webhook' do
          expect(service).not_to receive(:execute_hooks).with(merge_request, 'unapproval')

          execute!
        end

        it 'sends unapproved notification' do
          notification_service = instance_double(NotificationService)
          async_service = instance_double(NotificationService)

          expect(service).to receive(:notification_service).and_return(notification_service)
          expect(notification_service).to receive(:async).and_return(async_service)
          expect(async_service).to receive(:unapprove_mr).with(merge_request, user)

          execute!
        end
      end

      context 'when MR remains approved after removal' do
        let!(:other_user) { create(:user) }
        let!(:third_user) { create(:user) }
        let!(:second_approval) { create(:approval, merge_request: merge_request, user: other_user) }
        let!(:third_approval) { create(:approval, merge_request: merge_request, user: third_user) }

        before do
          # Add all users to the project with approval permissions
          project.add_developer(other_user)
          project.add_developer(third_user)

          # Set approval requirement so MR stays approved after removing 1 of 3 approvals
          merge_request.update!(approvals_before_merge: 2)
        end

        it 'does not change approval state' do
          expect { execute! }.not_to change { merge_request.approved? }
        end

        it 'fires an unapproval webhook (not unapproved)' do
          expect(service).to receive(:execute_hooks).with(merge_request, 'unapproval')

          execute!
        end

        it 'does not fire an unapproved webhook' do
          expect(service).not_to receive(:execute_hooks).with(merge_request, 'unapproved')

          execute!
        end

        it 'sends unapproved notification' do
          notification_service = instance_double(NotificationService)
          async_service = instance_double(NotificationService)

          expect(service).to receive(:notification_service).and_return(notification_service)
          expect(notification_service).to receive(:async).and_return(async_service)
          expect(async_service).to receive(:unapprove_mr).with(merge_request, user)

          execute!
        end
      end

      context 'when MR was not approved before removal' do
        before do
          # Set high approval requirement so MR is not approved even with 1 approval
          merge_request.update!(approvals_before_merge: 5)
        end

        it 'does not change approval state (remains unapproved)' do
          expect { execute! }.not_to change { merge_request.approved? }
        end

        it 'fires an unapproval webhook' do
          expect(service).to receive(:execute_hooks).with(merge_request, 'unapproval')

          execute!
        end

        it 'does not fire an unapproved webhook' do
          expect(service).not_to receive(:execute_hooks).with(merge_request, 'unapproved')

          execute!
        end

        it 'does not send unapproved notification' do
          expect(service).not_to receive(:notification_service)

          execute!
        end
      end
    end
  end
end
