# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::UpdateLicenseApprovalsService, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project, :public, :repository) }
  let_it_be_with_refind(:merge_request) do
    create(:merge_request, source_project: project)
  end

  let_it_be_with_reload(:pipeline) do
    create(
      :ee_ci_pipeline,
      :success,
      :with_cyclonedx_report,
      project: project,
      merge_requests_as_head_pipeline: [merge_request],
      ref: merge_request.source_branch,
      sha: merge_request.diff_head_sha)
  end

  let_it_be_with_reload(:target_pipeline) do
    create(
      :ee_ci_pipeline,
      :success,
      :with_cyclonedx_report,
      project: project,
      ref: merge_request.target_branch,
      sha: merge_request.diff_base_sha)
  end

  let_it_be(:preexisting_states) { false }

  let(:license_states) { ['newly_detected'] }
  let(:scan_result_policy_read) do
    srp = create(:scan_result_policy_read, project: project, license_states: license_states)
    security_policy = create(:security_policy,
      security_orchestration_policy_configuration: srp.security_orchestration_policy_configuration,
      policy_index: srp.orchestration_policy_idx)
    apr = create(:approval_policy_rule, :license_finding,
      content: {
        type: 'license_finding', branches: [],
        match_on_inclusion_license: true, license_types: %w[BSD MIT],
        license_states: license_states
      },
      security_policy: security_policy)
    srp.update!(approval_policy_rule: apr)
    srp
  end

  let!(:license_finding_rule) do
    create(:report_approver_rule, :license_scanning,
      merge_request: merge_request,
      scan_result_policy_read: scan_result_policy_read,
      approval_policy_rule: scan_result_policy_read.approval_policy_rule,
      approvals_required: 1
    )
  end

  let(:service) { described_class.new(merge_request, pipeline, preexisting_states) }

  subject(:execute) { service.execute }

  shared_examples 'does not require approvals' do
    it 'resets approvals_required in approval rules' do
      expect { execute }.to change { license_finding_rule.reload.approvals_required }.from(1).to(0)
    end
  end

  shared_examples 'requires approval' do
    it 'does not update approval rules' do
      expect { execute }.not_to change { license_finding_rule.reload.approvals_required }
    end
  end

  shared_examples 'persists a violation as warning' do
    it 'persists a violation as warning' do
      execute

      expect(merge_request.scan_result_policy_violations.last).to be_warn
    end
  end

  shared_examples 'saves a trimmed list of violated dependencies' do
    it 'saves a trimmed list of violated dependencies' do
      execute

      expect(merge_request.scan_result_policy_violations.last.violation_data).to eq({
        'context' => {
          'pipeline_ids' => [pipeline.id],
          'target_pipeline_ids' => [target_pipeline.id]
        },
        'violations' => {
          'license_scanning' => {
            'GNU' => dependencies.first(Security::ScanResultPolicyViolation::MAX_VIOLATIONS + 1)
          }
        }
      })
    end
  end

  shared_examples 'saves violation without pipeline id' do
    it 'saves violation without pipeline id' do
      execute

      expect(merge_request.scan_result_policy_violations.last.violation_data).to eq({
        'context' => {
          'pipeline_ids' => [],
          'target_pipeline_ids' => [target_pipeline.id]
        },
        'violations' => {
          'license_scanning' => {
            'GNU' => ['A']
          }
        }
      })
    end
  end

  context 'when merge request is merged' do
    before do
      merge_request.update!(state: 'merged')
    end

    it_behaves_like 'requires approval'
    it_behaves_like 'does not trigger policy bot comment'
  end

  context 'when there are no license scanning rules' do
    before do
      license_finding_rule.delete
    end

    it_behaves_like 'does not trigger policy bot comment'

    it 'does not call logger' do
      expect(Gitlab::AppJsonLogger).not_to receive(:info)

      execute
    end
  end

  describe 'violation data' do
    let(:dependencies) { ('A'..'Z').to_a }

    before do
      allow_next_instance_of(Security::ScanResultPolicies::LicenseViolationChecker) do |checker|
        allow(checker).to receive(:execute).and_return({ 'GNU' => dependencies })
      end
    end

    it_behaves_like 'saves a trimmed list of violated dependencies'

    context 'when the licenses field is present' do
      let(:licenses) { { denied: [{ name: 'MIT License' }] } }
      let(:scan_result_policy_read) do
        create(:scan_result_policy_read, project: project, license_states: license_states, licenses: licenses)
      end

      before do
        allow_next_instance_of(Security::MergeRequestApprovalPolicies::LicenseExpressionChecker) do |checker|
          allow(checker).to receive(:denied_licenses_with_dependencies).and_return({ 'GNU' => dependencies })
        end
      end

      it_behaves_like 'saves a trimmed list of violated dependencies'

      context 'when the license_expression_checker flag is disabled' do
        before do
          stub_feature_flags(license_expression_checker: false)

          allow_next_instance_of(Security::MergeRequestApprovalPolicies::DeniedLicensesChecker) do |checker|
            allow(checker).to receive(:denied_licenses_with_dependencies).and_return({ 'GNU' => dependencies })
          end
        end

        it_behaves_like 'saves a trimmed list of violated dependencies'
      end
    end
  end

  context 'for preexisting states' do
    let_it_be(:preexisting_states) { true }
    let_it_be(:pipeline) { nil }
    let(:license_states) { ['detected'] }

    before do
      allow_next_instance_of(Security::ScanResultPolicies::LicenseViolationChecker) do |checker|
        allow(checker).to receive(:execute).and_return({ 'GNU' => ['A'] })
      end
    end

    it_behaves_like 'requires approval'
    it_behaves_like 'triggers policy bot comment', true

    it 'logs the violated rules' do
      expect(Gitlab::AppJsonLogger).to receive(:info).with(hash_including(
        message: 'Evaluating license_scanning rules from approval policies'))
      expect(Gitlab::AppJsonLogger).to receive(:info).with(hash_including(message: 'Updating MR approval rule'))

      execute
    end

    it_behaves_like 'saves violation without pipeline id'

    context 'when the licenses field is present' do
      let(:licenses) { { denied: [{ name: 'MIT License' }] } }

      context 'when the scan_result_policy_read has the license information' do
        let(:scan_result_policy_read) do
          create(:scan_result_policy_read, project: project, license_states: license_states, licenses: licenses)
        end

        before do
          allow_next_instance_of(Security::MergeRequestApprovalPolicies::LicenseExpressionChecker,
            project, anything, anything, an_instance_of(Security::ApprovalPolicySource)) do |checker|
            allow(checker).to receive(:denied_licenses_with_dependencies).and_return({ 'GNU' => ['A'] })
          end
        end

        it_behaves_like 'saves violation without pipeline id'

        context 'when the license_expression_checker flag is disabled' do
          before do
            stub_feature_flags(license_expression_checker: false)

            allow_next_instance_of(Security::MergeRequestApprovalPolicies::DeniedLicensesChecker,
              project, anything, anything, an_instance_of(Security::ApprovalPolicySource)) do |checker|
              allow(checker).to receive(:denied_licenses_with_dependencies).and_return({ 'GNU' => ['A'] })
            end
          end

          it_behaves_like 'saves violation without pipeline id'
        end
      end

      context 'when the approval_policy_rule has the license information' do
        let(:approval_policy_rule_content) do
          {
            type: 'license_finding',
            branches: [],
            license_states: license_states,
            licenses: licenses
          }
        end

        let(:approval_policy_rule) do
          create(:approval_policy_rule, :license_finding_with_allowed_licenses,
            content: approval_policy_rule_content)
        end

        before do
          allow_next_instance_of(Security::MergeRequestApprovalPolicies::LicenseExpressionChecker,
            project, anything, anything, an_instance_of(Security::ApprovalPolicySource)) do |checker|
            allow(checker).to receive(:denied_licenses_with_dependencies).and_return({ 'GNU' => ['A'] })
          end
        end

        it_behaves_like 'saves violation without pipeline id'

        context 'when the license_expression_checker flag is disabled' do
          before do
            stub_feature_flags(license_expression_checker: false)

            allow_next_instance_of(Security::MergeRequestApprovalPolicies::DeniedLicensesChecker,
              project, anything, anything, an_instance_of(Security::ApprovalPolicySource)) do |checker|
              allow(checker).to receive(:denied_licenses_with_dependencies).and_return({ 'GNU' => ['A'] })
            end
          end

          it_behaves_like 'saves violation without pipeline id'
        end
      end
    end

    context 'when there are no violations' do
      before do
        allow_next_instance_of(Security::ScanResultPolicies::LicenseViolationChecker) do |checker|
          allow(checker).to receive(:execute).and_return(nil)
        end
      end

      it_behaves_like 'does not require approvals'
      it_behaves_like 'triggers policy bot comment', false
      it_behaves_like 'merge request without scan result violations'

      it 'only logs evaluation' do
        expect(Gitlab::AppJsonLogger).to receive(:info).with(hash_including(
          message: 'Evaluating license_scanning rules from approval policies'))

        execute
      end
    end

    context 'when target branch pipeline is nil' do
      before do
        allow(service).to receive(:target_branch_pipeline).and_return(nil)
      end

      context 'when fail_open is true' do
        before do
          license_finding_rule.scan_result_policy_read.update!(fallback_behavior: { fail: 'open' })
          license_finding_rule.approval_policy_rule&.security_policy
            &.update!(content: { fallback_behavior: { fail: 'open' } })
        end

        it_behaves_like 'does not require approvals'
        it_behaves_like 'triggers policy bot comment', true
        it_behaves_like 'persists a violation as warning'
      end

      context 'when fail_open is false' do
        before do
          license_finding_rule.scan_result_policy_read.update!(fallback_behavior: { fail: 'closed' })
          license_finding_rule.approval_policy_rule&.security_policy
            &.update!(content: { fallback_behavior: { fail: 'closed' } })
        end

        it 'continues evaluation and logs rule violation' do
          expect(Gitlab::AppJsonLogger).to receive(:info).with(hash_including(
            message: 'Evaluating license_scanning rules from approval policies'))
          expect(Gitlab::AppJsonLogger).to receive(:info).with(hash_including(
            message: 'Updating MR approval rule', reason: 'license_finding rule violated'))

          execute
        end

        it 'requires approval due to fail closed behavior' do
          expect { execute }.not_to change { license_finding_rule.reload.approvals_required }
        end
      end

      context 'with fallback_behavior divergent between approval_policy_rule and scan_result_policy_read' do
        include_context 'with divergent fallback_behavior using existing approval_policy_rule'

        let(:approval_policy_source_read) { scan_result_policy_read }

        it_behaves_like 'does not require approvals'
        it_behaves_like 'triggers policy bot comment', true

        context 'when the deprecate_scan_result_policies flag is disabled' do
          include_context 'with deprecate_scan_result_policies flag disabled'

          it 'continues evaluation and logs rule violation' do
            expect(Gitlab::AppJsonLogger).to receive(:info).with(hash_including(
              message: 'Evaluating license_scanning rules from approval policies'))
            expect(Gitlab::AppJsonLogger).to receive(:info).with(hash_including(
              message: 'Updating MR approval rule', reason: 'license_finding rule violated'))

            execute
          end

          it 'requires approval due to fail closed behavior' do
            expect { execute }.not_to change { license_finding_rule.reload.approvals_required }
          end
        end
      end

      context 'when approval rule has no approval_policy_source' do
        before do
          license_finding_rule.update_columns(scan_result_policy_id: nil, approval_policy_rule_id: nil)
          license_finding_rule.reload
        end

        it 'evaluates the rule without error' do
          expect { execute }.not_to raise_error
        end
      end
    end
  end

  context 'for newly_detected states' do
    before do
      allow_next_instance_of(Security::ScanResultPolicies::LicenseViolationChecker) do |checker|
        allow(checker).to receive(:execute).and_return({ 'GNU' => ['A'] })
      end
    end

    context 'when the pipeline has no license report' do
      let_it_be_with_reload(:pipeline) do
        create(
          :ee_ci_pipeline,
          :success,
          project: project,
          merge_requests_as_head_pipeline: [merge_request],
          ref: merge_request.source_branch,
          sha: merge_request.diff_head_sha)
      end

      it_behaves_like 'requires approval'
      it_behaves_like 'does not trigger policy bot comment'

      it 'logs a message' do
        expect(Gitlab::AppJsonLogger).to receive(:info).with(hash_including(
          message: 'No SBOM reports found for the pipeline'))

        execute
      end

      context 'when a related source pipeline has a license report' do
        let_it_be(:related_source_pipeline) do
          create(
            :ee_ci_pipeline,
            :success,
            :with_dependency_scanning_feature_branch,
            :with_cyclonedx_report,
            source: :merge_request_event,
            project: project,
            ref: merge_request.source_branch,
            sha: merge_request.diff_head_sha)
        end

        it_behaves_like 'requires approval'
        it_behaves_like 'triggers policy bot comment', true

        context 'when there are no violations' do
          before do
            allow_next_instance_of(Security::ScanResultPolicies::LicenseViolationChecker) do |checker|
              allow(checker).to receive(:execute).and_return(nil)
            end
          end

          it_behaves_like 'does not require approvals'
          it_behaves_like 'triggers policy bot comment', false
        end
      end
    end

    context 'when there are no violations' do
      before do
        allow_next_instance_of(Security::ScanResultPolicies::LicenseViolationChecker) do |checker|
          allow(checker).to receive(:execute).and_return(nil)
        end
      end

      it_behaves_like 'does not require approvals'
      it_behaves_like 'triggers policy bot comment', false
    end

    context 'when target branch pipeline is nil' do
      before do
        allow(service).to receive(:target_branch_pipeline).and_return(nil)
      end

      context 'when fail_open is true' do
        before do
          license_finding_rule.scan_result_policy_read.update!(fallback_behavior: { fail: 'open' })
          license_finding_rule.approval_policy_rule&.security_policy
            &.update!(content: { fallback_behavior: { fail: 'open' } })
        end

        it_behaves_like 'does not require approvals'
        it_behaves_like 'triggers policy bot comment', true
        it_behaves_like 'persists a violation as warning'
      end

      context 'when fail_open is false' do
        before do
          license_finding_rule.scan_result_policy_read.update!(fallback_behavior: { fail: 'closed' })
          license_finding_rule.approval_policy_rule&.security_policy
            &.update!(content: { fallback_behavior: { fail: 'closed' } })
        end

        it 'continues evaluation and logs rule violation' do
          expect(Gitlab::AppJsonLogger).to receive(:info).with(hash_including(
            message: 'Evaluating license_scanning rules from approval policies'))
          expect(Gitlab::AppJsonLogger).to receive(:info).with(hash_including(
            message: 'Updating MR approval rule', reason: 'license_finding rule violated'))

          execute
        end

        it 'requires approval due to fail closed behavior' do
          expect { execute }.not_to change { license_finding_rule.reload.approvals_required }
        end
      end
    end

    context 'when there are multiple pipelines without reports and one related pipeline' do
      before do
        create_list(:ee_ci_pipeline, 3, :success, project: project, ref: merge_request.target_branch,
          sha: merge_request.diff_base_sha, source: :schedule)
      end

      let_it_be(:related_target_pipeline) do
        create(
          :ee_ci_pipeline,
          :success,
          :with_dependency_scanning_feature_branch,
          project: project,
          ref: merge_request.target_branch,
          sha: merge_request.diff_base_sha)
      end

      it_behaves_like 'requires approval'
    end
  end

  context 'when approval rule has no approval_policy_source' do
    before do
      license_finding_rule.update_columns(scan_result_policy_id: nil, approval_policy_rule_id: nil)
      license_finding_rule.reload
    end

    it 'skips evaluation and leaves approvals_required unchanged' do
      expect(Gitlab::AppJsonLogger).not_to receive(:info).with(hash_including(
        message: 'Evaluating license_scanning rules from approval policies'))

      expect { execute }.not_to change { license_finding_rule.reload.approvals_required }
    end
  end

  describe 'target branch report memoization' do
    it 'fetches the target branch report only once for rules sharing the same target pipeline' do
      allow(service).to receive(:target_branch_pipeline).and_return(target_pipeline)

      expect(Gitlab::LicenseScanning).to receive(:scanner_for_pipeline)
        .with(project, target_pipeline).once.and_call_original

      2.times { service.send(:target_branch_report, instance_double(ApprovalMergeRequestRule)) }
    end
  end

  describe 'violation detail data' do
    let(:max_array_limit) { 2 }
    let(:full_deps) { Array.new(max_array_limit + 3) { |i| "dep#{i}" } }
    let(:denied_licenses) { { 'MIT License' => full_deps } }

    before do
      stub_const('Security::ScanResultPolicyViolationDetail::MAX_ARRAY_LIMIT', max_array_limit)

      allow_next_instance_of(Security::ScanResultPolicies::LicenseViolationChecker) do |checker|
        allow(checker).to receive(:execute).and_return(denied_licenses)
      end
    end

    it 'stores trimmed dependencies in the violation detail row' do
      execute

      detail = Security::ScanResultPolicyViolationDetail.order(:id).last
      expect(detail.dependencies).to eq(full_deps.first(max_array_limit))
    end

    it 'stores total dependency count in violation detail metadata' do
      execute

      detail = Security::ScanResultPolicyViolationDetail.order(:id).last
      expect(detail.metadata).to include('total_dependencies_count' => full_deps.size)
    end

    context 'when rule is not violated' do
      let(:denied_licenses) { {} }

      it 'does not create violation detail rows' do
        expect { execute }.not_to change { Security::ScanResultPolicyViolationDetail.count }
      end
    end

    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(dual_write_scan_result_policy_violation_details: false)
      end

      it 'does not create violation detail rows' do
        expect { execute }.not_to change { Security::ScanResultPolicyViolationDetail.count }
      end
    end
  end
end
