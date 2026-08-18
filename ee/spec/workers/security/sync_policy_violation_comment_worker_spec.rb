# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SyncPolicyViolationCommentWorker, feature_category: :security_policy_management do
  describe '#perform' do
    let_it_be_with_reload(:project) { create(:project) }
    let_it_be(:merge_request) { create(:merge_request, source_project: project) }
    let(:merge_request_id) { merge_request.id }
    let(:licensed_feature) { true }
    let_it_be(:protected_branch) { create(:protected_branch, project: project, name: merge_request.target_branch) }
    let_it_be(:scan_result_policy_read) { create(:scan_result_policy_read, project: project) }
    let_it_be(:scan_finding_project_rule) do
      create(:approval_project_rule, :scan_finding, project: project, protected_branches: [protected_branch],
        scan_result_policy_read: scan_result_policy_read)
    end

    let!(:scan_finding_rule) do
      create(:report_approver_rule, :scan_finding, merge_request: merge_request,
        approval_project_rule: scan_finding_project_rule, scan_result_policy_read: scan_result_policy_read)
    end

    let_it_be(:license_scanning_project_rule) do
      create(:approval_project_rule, :license_scanning, project: project, protected_branches: [protected_branch],
        scan_result_policy_read: scan_result_policy_read)
    end

    let!(:license_scanning_rule) do
      create(:report_approver_rule, :license_scanning, merge_request: merge_request,
        approval_project_rule: scan_finding_project_rule, scan_result_policy_read: scan_result_policy_read)
    end

    before do
      stub_licensed_features(security_orchestration_policies: licensed_feature)
    end

    subject(:perform) { described_class.new.perform(merge_request_id) }

    it_behaves_like 'an idempotent worker' do
      let(:job_args) { [merge_request_id] }
    end

    shared_examples_for 'does not enqueue the policy bot comment worker' do
      it 'does not enqueue the worker' do
        expect(Security::GeneratePolicyViolationCommentWorker).not_to receive(:perform_async)

        perform
      end
    end

    it 'enqueues Security::GeneratePolicyViolationCommentWorker' do
      expect(Security::GeneratePolicyViolationCommentWorker).to receive(:perform_async).with(merge_request.id)

      perform
    end

    it_behaves_like 'does not trigger policy bot comment for archived project' do
      subject(:execute) { perform }

      let(:archived_project) { project }
    end

    context 'when there are violations' do
      before do
        create(:scan_result_policy_violation, scan_result_policy_read: scan_result_policy_read,
          merge_request: merge_request, project: project)
      end

      it 'enqueues Security::GeneratePolicyViolationCommentWorker' do
        expect(Security::GeneratePolicyViolationCommentWorker).to receive(:perform_async).with(merge_request.id)

        perform
      end

      context 'when some violations are still running' do
        let_it_be(:other_scan_result_policy_read) { create(:scan_result_policy_read, project: project) }

        before do
          create(:scan_result_policy_violation, scan_result_policy_read: other_scan_result_policy_read,
            merge_request: merge_request, project: project, status: :running)
        end

        it_behaves_like 'does not enqueue the policy bot comment worker'
      end
    end

    context 'when there are no report_approver rules' do
      let!(:license_scanning_rule) { nil }
      let!(:scan_finding_rule) { nil }

      it_behaves_like 'does not enqueue the policy bot comment worker'
    end

    context 'with a non-existing merge request' do
      let(:merge_request_id) { non_existing_record_id }

      it_behaves_like 'does not enqueue the policy bot comment worker'
    end

    context 'when feature is not licensed' do
      let(:licensed_feature) { false }

      it_behaves_like 'does not enqueue the policy bot comment worker'
    end
  end
end
