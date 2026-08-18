# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::UnblockPendingMergeRequestViolationsWorker, "#execute", feature_category: :security_policy_management do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be_with_reload(:merge_request) { create(:ee_merge_request, source_project: project) }
  let_it_be_with_reload(:pipeline) do
    create(:ci_empty_pipeline,
      status: :success,
      ref: merge_request.source_branch,
      head_pipeline_of: merge_request,
      project: project)
  end

  let(:feature_licensed) { true }

  let_it_be(:scan_result_policy_reads) { create_list(:scan_result_policy_read, 3, project: project) }
  let_it_be(:approval_project_scan_finding_rule) do
    create_project_rule(:scan_finding, scan_result_policy_reads.first)
  end

  let_it_be(:approval_project_license_scanning_rule) do
    create_project_rule(:license_scanning, scan_result_policy_reads.second)
  end

  let_it_be(:approval_project_any_merge_request_rule) do
    create_project_rule(:any_merge_request, scan_result_policy_reads.third)
  end

  let_it_be(:approval_policy_rule_scan_finding) { create(:approval_policy_rule, :scan_finding) }
  let_it_be(:approval_policy_rule_license_finding) { create(:approval_policy_rule, :license_finding) }
  let_it_be(:approval_policy_rule_any_merge_request) { create(:approval_policy_rule, :any_merge_request) }
  let(:approval_policy_rules) do
    [approval_policy_rule_scan_finding, approval_policy_rule_license_finding, approval_policy_rule_any_merge_request]
  end

  let!(:approval_merge_request_scan_finding_rule) do
    create_mr_rule(approval_project_scan_finding_rule, approval_policy_rule_scan_finding)
  end

  let!(:approval_merge_request_license_scanning_rule) do
    create_mr_rule(approval_project_license_scanning_rule, approval_policy_rule_license_finding)
  end

  let!(:approval_merge_request_any_merge_request_rule) do
    create_mr_rule(approval_project_any_merge_request_rule, approval_policy_rule_any_merge_request)
  end

  let!(:violations) do
    scan_result_policy_reads.zip(approval_policy_rules).each do |policy, approval_policy_rule|
      create(:scan_result_policy_violation, :running, project: project, merge_request: merge_request,
        scan_result_policy_read: policy, approval_policy_rule: approval_policy_rule)
    end
  end

  before do
    stub_licensed_features(security_orchestration_policies: feature_licensed)
  end

  subject(:perform) { described_class.new.perform(pipeline_id) }

  shared_examples_for 'does not update merge request violations' do
    it 'does not unblock scan_result_policy_violations' do
      expect { perform }.not_to change { merge_request.running_scan_result_policy_violations.count }

      expect(merge_request.scan_result_policy_violations.reload).to all(be_running)
    end
  end

  shared_examples_for 'does not update merge request report_approver approvals' do
    it 'does not update approvals' do
      perform

      expect(merge_request.approval_rules.report_approver.reload).to all(have_attributes(approvals_required: 0))
    end
  end

  context 'with pipeline found' do
    let(:pipeline_id) { pipeline.id }

    it 'unblocks running scan_result_policy_violations by marking them as skipped', :aggregate_failures do
      expect { perform }.to change { merge_request.running_scan_result_policy_violations.count }.from(3).to(0)

      expect(merge_request.scan_result_policy_violations).to all(be_skipped)
    end

    it 'updates approvals to be required' do
      perform

      expect(merge_request.approval_rules.report_approver).to all(have_attributes(approvals_required: 1))
    end

    it 'logs a message' do
      expect(Gitlab::AppJsonLogger).to receive(:info).with(
        hash_including(
          message: 'Policy evaluation timed out, skipping and requiring approvals',
          merge_request_id: merge_request.id))

      perform
    end

    context 'when there are completed violations' do
      let!(:violations) do
        create(:scan_result_policy_violation, :running, project: project, merge_request: merge_request,
          scan_result_policy_read: scan_result_policy_reads.first, approval_policy_rule: approval_policy_rules.first)
        create(:scan_result_policy_violation, :failed, project: project, merge_request: merge_request,
          scan_result_policy_read: scan_result_policy_reads.second, approval_policy_rule: approval_policy_rules.second)
        create(:scan_result_policy_violation, :warn, project: project, merge_request: merge_request,
          scan_result_policy_read: scan_result_policy_reads.third, approval_policy_rule: approval_policy_rules.third)
      end

      it 'only updates the running scan_result_policy_violations and not the completed ones', :aggregate_failures do
        perform

        violations_map = merge_request.scan_result_policy_violations.reload.index_by(&:scan_result_policy_read)
        expect(violations_map[scan_result_policy_reads.first]).to be_skipped
        expect(violations_map[scan_result_policy_reads.second]).to be_failed
        expect(violations_map[scan_result_policy_reads.third]).to be_warn
      end
    end

    context 'when there are other approval rules' do
      let(:other_approval_project_rule) do
        create(:approval_project_rule, name: 'Non-policy rule', project: project, approvals_required: 1)
      end

      let!(:other_approval_rule) do
        create(:approval_merge_request_rule, merge_request: merge_request, name: 'Non-policy-rule',
          approvals_required: 0, approval_project_rule: other_approval_project_rule)
      end

      it 'does not update approvals for the regular rule' do
        expect { perform }.not_to change { other_approval_rule.reload.approvals_required }
      end
    end

    context 'when feature is not licensed' do
      let(:feature_licensed) { false }

      it_behaves_like 'does not update merge request violations'
      it_behaves_like 'does not update merge request report_approver approvals'
    end

    context 'when there are no opened merge requests for the head pipeline' do
      before do
        merge_request.update!(state: 'closed')
      end

      it_behaves_like 'does not update merge request violations'
      it_behaves_like 'does not update merge request report_approver approvals'
    end

    context 'when there are no running violations' do
      before do
        merge_request.scan_result_policy_violations.update_all(status: :failed)
      end

      it 'does not change scan_result_policy_violations' do
        perform

        expect(merge_request.scan_result_policy_violations.reload).to all(be_failed)
      end

      it_behaves_like 'does not update merge request report_approver approvals'
    end

    context 'when there are no report_approver approval_rules' do
      let!(:approval_merge_request_scan_finding_rule) { nil }
      let!(:approval_merge_request_license_scanning_rule) { nil }
      let!(:approval_merge_request_any_merge_request_rule) { nil }

      it_behaves_like 'does not update merge request violations'
      it_behaves_like 'does not update merge request report_approver approvals'
    end
  end

  context 'without pipeline found' do
    let(:pipeline_id) { non_existing_record_id }

    it_behaves_like 'does not update merge request violations'
    it_behaves_like 'does not update merge request report_approver approvals'
  end

  private

  def create_project_rule(type, policy)
    create(:approval_project_rule, type, name: "#{type} policy rule", project: project,
      approvals_required: 1,
      scan_result_policy_read: policy)
  end

  def create_mr_rule(project_rule, policy_rule)
    create(:report_approver_rule, project_rule.report_type.to_sym, merge_request: merge_request,
      approval_project_rule: project_rule,
      approvals_required: 0,
      scan_result_policy_read: project_rule.scan_result_policy_read,
      approval_policy_rule: policy_rule)
  end
end
