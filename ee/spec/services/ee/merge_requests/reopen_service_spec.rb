# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::ReopenService, feature_category: :code_review_workflow do
  describe '#execute' do
    # `freeze: false` is required in this spec: one or more `let_it_be` subjects
    # cannot be frozen by default (deep_freeze traversal failure, a non-AR
    # subject, or an in-memory mutation that survives reload/refind). Do not
    # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
    # (see gitlab-org/gitlab#602925).
    let_it_be(:merge_request, freeze: false) { create(:merge_request) }
    let_it_be(:project, freeze: false) { merge_request.target_project }

    let(:service_object) { described_class.new(project: project, current_user: merge_request.author) }

    subject(:merge_request_reopen_service) { service_object.execute(merge_request) }

    context 'for audit events' do
      let_it_be(:project_bot) { create(:user, :project_bot, email: "bot@example.com") }
      let_it_be(:merge_request, freeze: false) { create(:merge_request, author: project_bot) }

      include_examples 'audit event logging' do
        let(:operation) { merge_request_reopen_service }
        let(:event_type) { 'merge_request_reopened_by_project_bot' }
        let(:fail_condition!) { expect(project_bot).to receive(:project_bot?).and_return(false) }
        let(:attributes) do
          {
            author_id: project_bot.id,
            entity_id: merge_request.target_project.id,
            entity_type: 'Project',
            details: {
              author_name: project_bot.name,
              event_name: 'merge_request_reopened_by_project_bot',
              target_id: merge_request.id,
              target_type: 'MergeRequest',
              target_details: {
                iid: merge_request.iid,
                id: merge_request.id,
                source_branch: merge_request.source_branch,
                target_branch: merge_request.target_branch
              }.to_s,
              author_class: project_bot.class.name,
              custom_message: "Reopened merge request #{merge_request.title}"
            }
          }
        end
      end
    end

    it 'publishes reopened event' do
      expect { merge_request_reopen_service }
        .to publish_event(::MergeRequests::ReopenedEvent).with(
          merge_request_id: merge_request.id
        )
    end

    context 'when the merge request cannot be reopened because a branch no longer exists' do
      let(:merge_request) do
        create(:merge_request, :closed, source_project: project, target_project: project)
      end

      before do
        allow(merge_request).to receive(:source_branch_exists?).and_return(false)
      end

      it 'does not reopen the merge request and skips the side effects', :aggregate_failures do
        expect(service_object).not_to receive(:delete_approvals)
        expect { merge_request_reopen_service }.not_to publish_event(::MergeRequests::ReopenedEvent)

        expect(merge_request).to be_closed
      end

      context 'when the prevent_reopen_merge_request_without_branch feature flag is disabled' do
        before do
          stub_feature_flags(prevent_reopen_merge_request_without_branch: false)
        end

        it 'still runs the side effects (behaviour unchanged when the flag is off)' do
          # Simulate the reopen not taking effect; with the flag off the guard must not
          # skip the side effects (preserving the pre-flag behaviour).
          allow(merge_request).to receive(:reopen).and_return(false)

          expect { merge_request_reopen_service }.to publish_event(::MergeRequests::ReopenedEvent)
        end
      end
    end

    context 'when the MR contains approvals' do
      let(:user) { create(:user) }
      let(:user2) { create(:user) }

      before do
        create(:approval, merge_request: merge_request, user: user)
        create(:approval, merge_request: merge_request, user: user2)
      end

      it 'deletes all the approvals' do
        expect { merge_request_reopen_service }.to change { merge_request.reload.approvals.size }
          .from(2).to(0)
      end
    end

    it_behaves_like 'audits security policy branch bypass' do
      let(:execute) { merge_request_reopen_service }
    end

    describe '#resync_policies' do
      let(:feature_licensed) { true }
      # `freeze: false` is required in this spec: one or more `let_it_be` subjects
      # cannot be frozen by default (deep_freeze traversal failure, a non-AR
      # subject, or an in-memory mutation that survives reload/refind). Do not
      # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
      # (see gitlab-org/gitlab#602925).
      let_it_be(:protected_branch, freeze: false) do
        create(:protected_branch, project: project, name: merge_request.target_branch)
      end

      let_it_be(:scan_result_policy_read) do
        create(:scan_result_policy_read, :with_approval_policy_rule, project: project)
      end

      let_it_be(:approval_policy_rule_project_link) do
        create(:approval_policy_rule_project_link, project: project,
          approval_policy_rule: scan_result_policy_read.approval_policy_rule)
      end

      let_it_be(:project_approval_rule) do
        create(:approval_project_rule, :scan_finding, project: project, approvals_required: 1,
          scan_result_policy_read: scan_result_policy_read,
          approval_policy_rule: scan_result_policy_read.approval_policy_rule)
      end

      before do
        stub_licensed_features(security_orchestration_policies: feature_licensed)
      end

      it 'recreates policies violations based on approval rules' do
        expect { merge_request_reopen_service }
          .to change { merge_request.running_scan_result_policy_violations.count }.from(0).to(1)

        expect(merge_request.scan_result_policy_violations.first)
          .to have_attributes(
            project: project, merge_request: merge_request, scan_result_policy_read: scan_result_policy_read
          )
      end

      it 'triggers the policy synchronization' do
        expect(merge_request).to receive(:schedule_policy_synchronization)

        merge_request_reopen_service
      end

      it_behaves_like 'synchronizes policies for a merge request' do
        subject(:execute) { merge_request_reopen_service }
      end

      context 'when feature is not licensed' do
        let(:feature_licensed) { false }

        it 'does not trigger the synchronization' do
          expect(merge_request).not_to receive(:schedule_policy_synchronization)

          merge_request_reopen_service
        end

        it 'does not update the violations' do
          expect { merge_request_reopen_service }.not_to change { merge_request.scan_result_policy_violations.count }
        end
      end
    end
  end
end
