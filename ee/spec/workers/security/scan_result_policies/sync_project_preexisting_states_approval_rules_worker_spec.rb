# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::SyncProjectPreexistingStatesApprovalRulesWorker, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let(:per_mr_worker) { Security::ScanResultPolicies::SyncPreexistingStatesApprovalRulesWorker }
  let_it_be(:open_mr_with_rule) do
    create(:merge_request, source_project: project, source_branch: 'feature-a', target_branch: 'master')
  end

  let_it_be(:open_mr_without_rule) do
    create(:merge_request, source_project: project, source_branch: 'feature-b', target_branch: 'master')
  end

  let_it_be(:closed_mr_with_rule) do
    create(:merge_request, :closed, source_project: project, source_branch: 'feature-c', target_branch: 'master')
  end

  let_it_be(:other_project_mr_with_rule) { create(:merge_request) }

  before_all do
    create(:security_policy_project_link, project: project)
    create(:report_approver_rule, :scan_finding, merge_request: open_mr_with_rule)
    create(:report_approver_rule, :scan_finding, merge_request: closed_mr_with_rule)
    create(:report_approver_rule, :scan_finding, merge_request: other_project_mr_with_rule)
  end

  describe '#perform' do
    subject(:run_worker) { described_class.new.perform(project_id) }

    let(:project_id) { project.id }

    it 'enqueues the per-merge-request worker for open MRs in the project with scan_finding rules' do
      expect(per_mr_worker).to receive(:perform_async).with(open_mr_with_rule.id).once

      run_worker
    end

    it 'does not enqueue for MRs without applicable rules, closed MRs, or MRs in other projects' do
      allow(per_mr_worker).to receive(:perform_async)

      run_worker

      expect(per_mr_worker).not_to have_received(:perform_async).with(open_mr_without_rule.id)
      expect(per_mr_worker).not_to have_received(:perform_async).with(closed_mr_with_rule.id)
      expect(per_mr_worker).not_to have_received(:perform_async).with(other_project_mr_with_rule.id)
    end

    context 'when the project does not exist' do
      let(:project_id) { non_existing_record_id }

      it 'does nothing' do
        expect(per_mr_worker).not_to receive(:perform_async)

        run_worker
      end
    end

    context 'when the project has no approval policy' do
      let_it_be(:project_without_policy) { create(:project) }
      let_it_be(:mr_with_rule) do
        create(:merge_request, source_project: project_without_policy, source_branch: 'x', target_branch: 'master')
      end

      let(:project_id) { project_without_policy.id }

      before_all do
        create(:report_approver_rule, :scan_finding, merge_request: mr_with_rule)
      end

      it 'returns early without enqueueing per-merge-request workers' do
        expect(per_mr_worker).not_to receive(:perform_async)

        run_worker
      end
    end

    it_behaves_like 'an idempotent worker' do
      let(:job_args) { [project.id] }
    end
  end
end
