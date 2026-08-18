# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::UpdateViolationsService, feature_category: :security_policy_management do
  let(:service) { described_class.new(merge_request) }
  let_it_be(:project) { create(:project) }
  let_it_be_with_reload(:merge_request) do
    create(:merge_request, source_project: project, target_project: project)
  end

  let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }

  let_it_be(:security_policy_a, reload: true) do
    create(:security_policy, security_orchestration_policy_configuration: policy_configuration, policy_index: 0)
  end

  let_it_be(:security_policy_b) do
    create(:security_policy, security_orchestration_policy_configuration: policy_configuration, policy_index: 1)
  end

  let_it_be_with_reload(:approval_policy_rule_a) do
    create(:approval_policy_rule, security_policy: security_policy_a, rule_index: 0)
  end

  let_it_be(:approval_policy_rule_b) do
    create(:approval_policy_rule, security_policy: security_policy_b, rule_index: 0)
  end

  let_it_be(:scan_result_policy_read_a, reload: true) do
    create(:scan_result_policy_read, project: project,
      security_orchestration_policy_configuration: policy_configuration,
      orchestration_policy_idx: 0, rule_idx: 0, approval_policy_rule: approval_policy_rule_a)
  end

  let_it_be(:scan_result_policy_read_b) do
    create(:scan_result_policy_read, project: project,
      security_orchestration_policy_configuration: policy_configuration,
      orchestration_policy_idx: 1, rule_idx: 0, approval_policy_rule: approval_policy_rule_b)
  end

  let(:policy_a) do
    Security::ApprovalPolicySource.new(project: project,
      action_idx: 0,
      scan_result_policy_read: scan_result_policy_read_a, approval_policy_rule: approval_policy_rule_a)
  end

  let(:policy_b) do
    Security::ApprovalPolicySource.new(project: project,
      action_idx: 0,
      scan_result_policy_read: scan_result_policy_read_b, approval_policy_rule: approval_policy_rule_b)
  end

  let(:violated_scan_result_policy_reads) { violations.map(&:scan_result_policy_read) }

  subject(:violations) { merge_request.scan_result_policy_violations }

  def last_violation
    violations.last.reload
  end

  describe '#execute' do
    describe 'attributes' do
      subject(:attrs) { project.scan_result_policy_violations.last.attributes }

      before do
        service.add([policy_a], [])
        service.execute
      end

      specify do
        is_expected.to include(
          "scan_result_policy_id" => scan_result_policy_read_a.id,
          "merge_request_id" => merge_request.id,
          "project_id" => project.id,
          "approval_policy_rule_id" => approval_policy_rule_a.id
        )
      end
    end

    shared_examples_for 'when violation data is invalid' do
      let(:expected_policy_id) { policy.id }

      context 'when violation data is invalid' do
        before do
          service.add_violation(policy, :any_merge_request, { commits: "invalid_value" })
        end

        it 'does not persist invalid violation data' do
          expect { service.execute }.not_to change { violations.count }
        end

        it 'logs invalid violation data' do
          expect(::Gitlab::AppLogger).to receive(:warn).with(
            message: 'Skipping invalid ScanResultPolicyViolation: ["Violation data must be a valid json schema"]',
            policy_id: expected_policy_id,
            merge_request_id: merge_request.id
          )

          service.execute
        end
      end
    end

    context 'without pre-existing violations' do
      before do
        service.add([policy_b], [])
      end

      it 'creates violations' do
        service.execute

        expect(violated_scan_result_policy_reads).to contain_exactly(scan_result_policy_read_b)
        expect(last_violation.approval_policy_rule).to eq(approval_policy_rule_b)
      end

      it 'stores the correct status' do
        service.add_violation(policy_b, :scan_finding, { uuids: { newly_detected: ['123'] } })
        service.execute

        expect(last_violation.status).to eq('failed')
        expect(last_violation).to be_valid
      end

      it 'can persist violation data' do
        service.add_violation(policy_b, :scan_finding, { uuids: { newly_detected: ['123'] } })
        service.execute

        expect(last_violation.violation_data)
          .to eq({ "violations" => { "scan_finding" => { "uuids" => { "newly_detected" => ['123'] } } } })
        expect(last_violation).to be_valid
      end

      it_behaves_like 'when violation data is invalid' do
        let(:policy) { policy_b }
      end

      context 'when policy approval_policy_rule_id is nil' do
        before do
          allow(policy_b).to receive(:approval_policy_rule_id).and_return(nil)
        end

        it_behaves_like 'when violation data is invalid' do
          let(:policy) { policy_b }
        end
      end

      it 'publishes MergeRequests::ViolationsUpdatedEvent' do
        expect { service.execute }
          .to publish_event(::MergeRequests::ViolationsUpdatedEvent)
          .with(merge_request_id: merge_request.id)
      end
    end

    context 'with pre-existing violations' do
      before do
        service.add_violation(policy_a, :scan_finding, { uuids: { newly_detected: ['123'] } })
        service.execute
      end

      it 'clears existing violations' do
        service.add([policy_b], [policy_a])
        service.execute

        expect(violated_scan_result_policy_reads).to contain_exactly(scan_result_policy_read_b)
        expect(last_violation.approval_policy_rule).to eq(approval_policy_rule_b)
      end

      it 'can add error to existing violation data' do
        service.add_error(policy_a, :scan_removed, missing_scans: ['sast'])

        expect { service.execute }
          .to change { last_violation.violation_data }.to match(
            { 'violations' => { 'scan_finding' => { 'uuids' => { 'newly_detected' => ['123'] } } },
              'errors' => [{ 'error' => 'SCAN_REMOVED', 'missing_scans' => ['sast'] }] }
          )
        expect(last_violation).to be_valid
      end

      it_behaves_like 'when violation data is invalid' do
        let(:policy) { policy_a }
      end

      it 'stores the correct status' do
        service.add_error(policy_a, :scan_removed, missing_scans: ['sast'])
        service.execute

        expect(last_violation.status).to eq('failed')
        expect(last_violation).to be_valid
      end

      context 'with identical state' do
        it 'does not clear violations' do
          service.add([policy_a], [])

          expect { service.execute }.not_to change { last_violation.violation_data }
          expect(violated_scan_result_policy_reads).to contain_exactly(scan_result_policy_read_a)
          expect(last_violation).to be_valid
        end
      end
    end

    context 'with unrelated existing violation' do
      let_it_be(:unrelated_violation) do
        create(:scan_result_policy_violation, scan_result_policy_read: scan_result_policy_read_a,
          merge_request: merge_request)
      end

      before do
        service.add([], [policy_b])
      end

      it 'removes only violations provided in unviolated ids' do
        service.execute

        expect(violations).to contain_exactly(unrelated_violation)
      end

      it 'publishes MergeRequests::ViolationsUpdatedEvent' do
        expect { service.execute }
          .to publish_event(::MergeRequests::ViolationsUpdatedEvent)
          .with(merge_request_id: merge_request.id)
      end
    end

    context 'when deprecate_scan_result_policies is disabled' do
      let_it_be(:legacy_violation) do
        create(:scan_result_policy_violation, merge_request: merge_request,
          scan_result_policy_read: scan_result_policy_read_a)
      end

      before do
        stub_feature_flags(deprecate_scan_result_policies: false)
        service.add([], [policy_a])
      end

      it 'deletes unviolated violations matched by scan_result_policy_id' do
        service.execute

        expect(violations).to be_empty
      end
    end

    context 'without violations' do
      it 'clears all violations' do
        service.execute

        expect(violations).to be_empty
      end

      it 'does not publish MergeRequests::ViolationsUpdatedEvent' do
        expect { service.execute }.not_to publish_event(MergeRequests::ViolationsUpdatedEvent)
      end
    end

    context 'with multiple Security::ScanResultPolicyRead rows sharing an approval_policy_rule' do
      let_it_be(:scan_result_policy_read_lower) do
        create(:scan_result_policy_read, project: project,
          security_orchestration_policy_configuration: policy_configuration,
          orchestration_policy_idx: 0,
          approval_policy_rule: approval_policy_rule_a)
      end

      let_it_be(:scan_result_policy_read_higher) do
        create(:scan_result_policy_read, project: project,
          security_orchestration_policy_configuration: policy_configuration,
          orchestration_policy_idx: 0,
          approval_policy_rule: approval_policy_rule_a)
      end

      let(:policy_a_action_lower) do
        Security::ApprovalPolicySource.new(project: project, action_idx: 0,
          scan_result_policy_read: scan_result_policy_read_lower, approval_policy_rule: approval_policy_rule_a)
      end

      let(:policy_a_action_higher) do
        Security::ApprovalPolicySource.new(project: project, action_idx: 0,
          scan_result_policy_read: scan_result_policy_read_higher, approval_policy_rule: approval_policy_rule_a)
      end

      let(:violation_for_apr_a) do
        violations.find_by(approval_policy_rule_id: approval_policy_rule_a.id)
      end

      it 'inserts only the lower row per approval_policy_rule_id', :aggregate_failures do
        service.add([policy_a_action_lower, policy_a_action_higher], [])
        service.execute

        expect(violations.where(approval_policy_rule_id: approval_policy_rule_a.id).count).to eq(1)
        expect(violation_for_apr_a).to be_present
        expect(violation_for_apr_a.scan_result_policy_id).to eq(scan_result_policy_read_lower.id)
      end
    end

    context 'with legacy rows that have no approval_policy_rule_id' do
      before do
        allow(policy_a).to receive(:approval_policy_rule).and_return(nil)
        allow(policy_b).to receive(:approval_policy_rule).and_return(nil)
      end

      it 'inserts each row independently and does not collapse nil-APR rows together', :aggregate_failures do
        service.add([policy_a, policy_b], [])

        expect { service.execute }.to change { violations.count }.by(2)
        expect(violations.pluck(:scan_result_policy_id))
          .to contain_exactly(policy_a.id, policy_b.id)
      end
    end

    describe 'security_policy_violations_detected audit event' do
      shared_examples 'not enqueuing the PolicyViolationsDetectedAuditEventWorker' do
        it 'does not enqueue MergeRequests::PolicyViolationsDetectedAuditEventWorker' do
          expect(::MergeRequests::PolicyViolationsDetectedAuditEventWorker).not_to receive(:perform_async)

          service.execute
        end
      end

      shared_examples 'not enqueuing the AuditWarnModeMergeRequestApprovalSettingsWorker' do
        it 'does not enqueue Security::ScanResultPolicies::AuditWarnModeMergeRequestApprovalSettingsWorker' do
          expect(::Security::ScanResultPolicies::AuditWarnModeMergeRequestApprovalSettingsWorker)
            .not_to receive(:perform_async)

          service.execute
        end
      end

      context 'when there are policy violations' do
        before do
          service.add([policy_a], [])
          service.execute
        end

        it 'enqueues MergeRequests::PolicyViolationsDetectedAuditEventWorker' do
          expect(::MergeRequests::PolicyViolationsDetectedAuditEventWorker).to receive(:perform_async).with(
            merge_request.id
          )

          service.execute
        end

        it 'enqueues Security::ScanResultPolicies::AuditWarnModeMergeRequestApprovalSettingsWorker' do
          expect(::Security::ScanResultPolicies::AuditWarnModeMergeRequestApprovalSettingsWorker)
            .to receive(:perform_async).with(merge_request.id)

          service.execute
        end
      end

      context "when there are running violations" do
        let_it_be(:running_violation) do
          create(:scan_result_policy_violation, :running, scan_result_policy_read: scan_result_policy_read_a,
            merge_request: merge_request)
        end

        let_it_be(:failed_violation) do
          create(:scan_result_policy_violation, :failed, scan_result_policy_read: scan_result_policy_read_b,
            merge_request: merge_request)
        end

        it_behaves_like 'not enqueuing the PolicyViolationsDetectedAuditEventWorker'
        it_behaves_like 'not enqueuing the AuditWarnModeMergeRequestApprovalSettingsWorker'
      end

      context "when there are no violations" do
        it_behaves_like 'not enqueuing the PolicyViolationsDetectedAuditEventWorker'
        it_behaves_like 'not enqueuing the AuditWarnModeMergeRequestApprovalSettingsWorker'
      end
    end

    describe 'security_policy_violations_resolved audit event' do
      shared_examples 'not enqueuing the PolicyViolationsResolvedAuditEventWorker' do
        it 'does not enqueue MergeRequests::PolicyViolationsResolvedAuditEventWorker' do
          expect(::MergeRequests::PolicyViolationsResolvedAuditEventWorker).not_to receive(:perform_async)

          service.execute
        end
      end

      context 'when violations with data are removed' do
        let_it_be(:existing_violation) do
          create(:scan_result_policy_violation, :failed, merge_request: merge_request, project: project,
            scan_result_policy_read: scan_result_policy_read_a, approval_policy_rule: approval_policy_rule_a,
            violation_data: { any_merge_request: { commits: true } })
        end

        before do
          service.remove_violation(policy_a)
        end

        context 'when there are no other existing violations' do
          it 'enqueues MergeRequests::PolicyViolationsResolvedAuditEventWorker' do
            expect(::MergeRequests::PolicyViolationsResolvedAuditEventWorker).to receive(:perform_async).with(
              merge_request.id
            )

            service.execute
          end
        end

        context 'when there are other existing violations' do
          before do
            service.add([policy_b], [])
          end

          it_behaves_like 'not enqueuing the PolicyViolationsResolvedAuditEventWorker'
        end
      end

      context 'when violations without data are removed' do
        before do
          create(:scan_result_policy_violation, :running, merge_request: merge_request, project: project,
            scan_result_policy_read: scan_result_policy_read_a, approval_policy_rule: approval_policy_rule_a,
            violation_data: nil)

          service.remove_violation(policy_a)
        end

        it_behaves_like 'not enqueuing the PolicyViolationsResolvedAuditEventWorker'
      end
    end
  end

  describe '#add_violation' do
    subject(:violation_data) do
      service.add_violation(policy_a, :scan_finding, data, context: context)
      service.violation_data[policy_a.id]
    end

    let(:context) { nil }
    let(:data) { { uuids: { newly_detected: ['123'] } } }

    it 'adds violation data into the correct structure' do
      expect(violation_data)
        .to eq({ violations: { scan_finding: { uuids: { newly_detected: ['123'] } } } })
    end

    it 'stores the correct status' do
      service.add_violation(policy_a, :scan_finding, data, context: context)
      service.execute

      expect(last_violation.status).to eq('failed')
      expect(last_violation).to be_valid
    end

    context 'when policy is fail-open' do
      before do
        scan_result_policy_read_a.update!(fallback_behavior: { fail: 'open' })
        security_policy_a.update_column(:content,
          security_policy_a.content.deep_stringify_keys.merge('fallback_behavior' => { 'fail' => 'open' }))
      end

      it 'persists the violation as failed', :aggregate_failures do
        service.add_violation(policy_a, :scan_finding, data, context: context)
        service.execute

        expect(last_violation.status).to eq('failed')
      end
    end

    context 'when other data is present' do
      before do
        service.add_violation(policy_a, :scan_finding, { uuids: { previously_existing: ['456'] } })
      end

      it 'merges the data for report_type' do
        expect(violation_data)
          .to eq({ violations: { scan_finding: { uuids: { previously_existing: ['456'], newly_detected: ['123'] } } } })
      end
    end

    context 'with additional context' do
      let(:context) { { pipeline_ids: [1] } }

      it 'saves context information' do
        expect(violation_data)
          .to match({
            context: { pipeline_ids: [1] },
            violations: { scan_finding: { uuids: { newly_detected: ['123'] } } }
          })
      end
    end
  end

  describe '#remove_violation' do
    subject(:remove_violation) do
      service.remove_violation(policy_a)
      service.execute
    end

    let!(:existing_violation) do
      create(:scan_result_policy_violation, merge_request: merge_request, project: project,
        scan_result_policy_read: scan_result_policy_read_a, approval_policy_rule: approval_policy_rule_a)
    end

    it 'removes violation for the policy' do
      expect { remove_violation }.to change { merge_request.scan_result_policy_violations.count }.from(1).to(0)
    end
  end

  describe '#add_error' do
    subject(:violation_data) do
      service.add_error(policy_a, error, context: context, **extra_data)
      service.violation_data[policy_a.id]
    end

    let(:error) { :scan_removed }
    let(:extra_data) { {} }
    let(:context) { nil }

    it 'adds error into violation data and persists the violation as failed', :aggregate_failures do
      expect(violation_data)
        .to eq({ errors: [{ error: 'SCAN_REMOVED' }] })
      service.execute
      expect(last_violation.status).to eq('failed')
    end

    context 'when policy is fail-open' do
      before do
        scan_result_policy_read_a.update!(fallback_behavior: { fail: 'open' })
        security_policy_a.update_column(:content,
          security_policy_a.content.deep_stringify_keys.merge('fallback_behavior' => { 'fail' => 'open' }))
      end

      it 'persists the violation as warning', :aggregate_failures do
        expect(violation_data)
          .to eq({ errors: [{ error: 'SCAN_REMOVED' }] })
        service.execute
        expect(last_violation.status).to eq('warn')
      end
    end

    context 'when other error is present' do
      before do
        service.add_error(policy_a, :artifacts_missing)
      end

      it 'merges the errors' do
        expect(violation_data)
          .to match({ errors: array_including({ error: 'SCAN_REMOVED' }, { error: 'ARTIFACTS_MISSING' }) })
      end
    end

    context 'with extra data' do
      let(:extra_data) { { missing_scans: ['sast'] } }

      it 'saves extra data' do
        expect(violation_data)
          .to eq({ errors: [{ error: 'SCAN_REMOVED', missing_scans: ['sast'] }] })
      end
    end

    context 'with context' do
      let(:context) { { pipeline_ids: [1999], target_pipeline_ids: [2000] } }

      it 'adds context into violation data' do
        expect(violation_data)
          .to eq({ errors: [{ error: 'SCAN_REMOVED' }],
                   context: { pipeline_ids: [1999], target_pipeline_ids: [2000] } })
      end
    end
  end

  describe '#skip' do
    it 'adds a specific error into violation data and persists the violation as skipped', :aggregate_failures do
      service.skip(policy_a)
      service.execute

      expect(violated_scan_result_policy_reads).to contain_exactly(scan_result_policy_read_a)
      expect(last_violation).to be_skipped
      expect(last_violation.violation_data).to match(
        { 'errors' => [{ 'error' => 'EVALUATION_SKIPPED' }] }
      )
    end

    context 'when policy is fail-open' do
      before do
        scan_result_policy_read_a.update!(fallback_behavior: { fail: 'open' })
        security_policy_a.update_column(:content,
          security_policy_a.content.deep_stringify_keys.merge('fallback_behavior' => { 'fail' => 'open' }))
      end

      it 'persists the violation as warning', :aggregate_failures do
        service.skip(policy_a)
        service.execute

        expect(violated_scan_result_policy_reads).to contain_exactly(scan_result_policy_read_a)
        expect(last_violation).to be_warn
        expect(last_violation.violation_data).to match(
          { 'errors' => [{ 'error' => 'EVALUATION_SKIPPED' }] }
        )
      end
    end

    context 'when other error is present for a skipped policy' do
      it 'merges the errors and persists it as failed', :aggregate_failures do
        service.skip(policy_a)
        service.add_error(policy_a, :artifacts_missing)
        service.execute

        expect(violated_scan_result_policy_reads).to contain_exactly(scan_result_policy_read_a)
        expect(last_violation).to be_failed
        expect(last_violation.violation_data).to match(
          { 'errors' => array_including({ 'error' => 'ARTIFACTS_MISSING' }, { 'error' => 'EVALUATION_SKIPPED' }) }
        )
      end
    end
  end

  describe '#add_violation_detail_data' do
    it 'stores metadata keyed by policy source id' do
      service.add_violation_detail_data(policy_a, total_commit_shas_count: 42)

      expect(service.violation_detail_data).to eq(
        policy_a.id => { total_commit_shas_count: 42 }
      )
    end

    it 'merges metadata for the same policy source' do
      service.add_violation_detail_data(policy_a, total_commit_shas_count: 5)
      service.add_violation_detail_data(policy_a, total_dependencies_by_license: { 'MIT' => 3 })

      expect(service.violation_detail_data[policy_a.id]).to eq(
        total_commit_shas_count: 5,
        total_dependencies_by_license: { 'MIT' => 3 }
      )
    end

    it 'stores metadata for multiple policy sources independently' do
      service.add_violation_detail_data(policy_a, total_commit_shas_count: 10)
      service.add_violation_detail_data(policy_b, total_commit_shas_count: 20)

      expect(service.violation_detail_data[policy_a.id]).to eq(total_commit_shas_count: 10)
      expect(service.violation_detail_data[policy_b.id]).to eq(total_commit_shas_count: 20)
    end
  end

  describe 'when writing scan result policy violation_details' do
    let(:finding_uuid) { SecureRandom.uuid }

    before do
      service.add_violation(policy_a, :scan_finding, { uuids: { newly_detected: [finding_uuid] } })
      service.add_violation_detail_data(policy_a, full_newly_detected_uuids: [finding_uuid])
    end

    it 'calls CreateViolationDetailsService and create violation detail' do
      expect_next_instance_of(
        Security::SecurityOrchestrationPolicies::CreateViolationDetailsService
      ) do |create_service|
        expect(create_service).to receive(:execute).and_call_original
      end

      expect { service.execute }.to change { Security::ScanResultPolicyViolationDetail.count }.by(1)
    end

    it 'passes violation_detail_data to CreateViolationDetailsService' do
      service.add_violation_detail_data(policy_a, total_commit_shas_count: 99)

      expect(Security::SecurityOrchestrationPolicies::CreateViolationDetailsService).to receive(:new).with(
        merge_request: merge_request,
        violation_detail_data: service.violation_detail_data
      ).and_call_original

      expect { service.execute }.to change { Security::ScanResultPolicyViolationDetail.count }.by(1)
    end

    context 'when dual_write_scan_result_policy_violation_details is disabled' do
      before do
        stub_feature_flags(dual_write_scan_result_policy_violation_details: false)
      end

      it 'does not call CreateViolationDetailsService' do
        expect(Security::SecurityOrchestrationPolicies::CreateViolationDetailsService).not_to receive(:new)

        service.execute
      end

      it 'creates no violation detail rows' do
        expect { service.execute }.not_to change { Security::ScanResultPolicyViolationDetail.count }
      end
    end
  end
end
