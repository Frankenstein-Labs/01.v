# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::PolicyViolationDetails, feature_category: :security_policy_management do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:project) { create(:project, :small_repo) }
  let_it_be_with_reload(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:security_orchestration_policy_configuration) do
    create(:security_orchestration_policy_configuration, project: project)
  end

  let_it_be(:policy1) do
    create(:scan_result_policy_read, project: project,
      security_orchestration_policy_configuration: security_orchestration_policy_configuration)
  end

  let_it_be(:policy2) do
    create(:scan_result_policy_read, project: project,
      security_orchestration_policy_configuration: security_orchestration_policy_configuration)
  end

  let_it_be(:policy3) do
    create(:scan_result_policy_read, project: project,
      security_orchestration_policy_configuration: security_orchestration_policy_configuration)
  end

  let_it_be(:policy_warn_mode) do
    create(:scan_result_policy_read, project: project,
      security_orchestration_policy_configuration: security_orchestration_policy_configuration)
  end

  let_it_be(:warn_mode_db_policy) do
    create(:security_policy, :enforcement_type_warn, policy_index: 3, name: 'Warn mode',
      security_orchestration_policy_configuration: security_orchestration_policy_configuration)
  end

  let(:warn_mode_policy_rule) { create(:approval_policy_rule, security_policy: warn_mode_db_policy) }

  let_it_be(:approver_rule_policy1) do
    create(:report_approver_rule, :scan_finding, merge_request: merge_request,
      scan_result_policy_read: policy1, name: 'Policy 1')
  end

  let_it_be(:approver_rule_policy2) do
    create(:report_approver_rule, :license_scanning, merge_request: merge_request,
      scan_result_policy_read: policy2, name: 'Policy 2')
  end

  let_it_be_with_reload(:approver_rule_policy3) do
    create(:report_approver_rule, :any_merge_request, merge_request: merge_request,
      scan_result_policy_read: policy3, name: 'Policy 3')
  end

  let_it_be_with_reload(:approver_rule_policy_warn_mode) do
    create(:report_approver_rule, :any_merge_request, merge_request: merge_request,
      scan_result_policy_read: policy_warn_mode, name: 'Warn mode')
  end

  let_it_be(:uuid) { SecureRandom.uuid }
  let_it_be(:uuid_previous) { SecureRandom.uuid }
  let_it_be(:scanner) { create(:vulnerabilities_scanner, project: project) }
  let_it_be(:pipeline) do
    create(:ee_ci_pipeline, :success, :with_dependency_scanning_report, project: project,
      ref: merge_request.source_branch, sha: merge_request.diff_head_sha,
      merge_requests_as_head_pipeline: [merge_request])
  end

  let_it_be(:ci_build) { pipeline.builds.first }

  let(:details) { described_class.new(merge_request) }

  def build_violation_details(policy, data, status = :failed, report_type = :scan_finding)
    create_violation_with_rule(status, policy: policy, report_type: report_type, violation_data: data)
  end

  def create_violation_with_rule(
    *traits, policy:, approval_policy_rule: nil, report_type: :scan_finding,
    policy_name: nil, warn_mode: false, **attrs)
    approval_policy_rule ||= create(:approval_policy_rule,
      security_policy: create(:security_policy, *(warn_mode ? [:enforcement_type_warn] : []),
        **{ name: policy_name }.compact))
    ensure_approval_rule(approval_policy_rule, report_type: report_type, policy: policy)

    create(:scan_result_policy_violation, *traits, project: project, merge_request: merge_request,
      scan_result_policy_read: policy, approval_policy_rule: approval_policy_rule, **attrs)
  end

  def ensure_approval_rule(approval_policy_rule, report_type: :scan_finding, policy: nil)
    return if merge_request.approval_rules.exists?(approval_policy_rule_id: approval_policy_rule.id)

    create(:report_approver_rule, report_type, merge_request: merge_request,
      scan_result_policy_read: policy, approval_policy_rule: approval_policy_rule,
      name: "Approver rule #{approval_policy_rule.id}")
  end

  # rubocop:disable RSpec/MultipleMemoizedHelpers -- the total number increased because of the inherited memoized helpers which are required for the tests
  describe '#violations' do
    subject(:violations) { details.violations }

    let(:scan_finding_violation_data) do
      { 'violations' => { 'scan_finding' => { 'uuids' => { 'newly_detected' => ['uuid'] } } } }
    end

    let(:license_scanning_violation_data) do
      { 'violations' => { 'license_scanning' => { 'MIT' => ['A'] } } }
    end

    let(:any_merge_request_violation_data) do
      { 'violations' => { 'any_merge_request' => { 'commits' => true } } }
    end

    let(:normal_db_policy) do
      create(:security_policy, policy_index: 1,
        security_orchestration_policy_configuration: security_orchestration_policy_configuration)
    end

    let_it_be(:enforcement_type_warn_db_policy) do
      create(:security_policy, :enforcement_type_warn, policy_index: 2, name: 'Warn DB Policy',
        security_orchestration_policy_configuration: security_orchestration_policy_configuration)
    end

    let(:warn_mode_policy_rule) { create(:approval_policy_rule, security_policy: warn_mode_db_policy) }
    let(:normal_policy_rule) { create(:approval_policy_rule, security_policy: normal_db_policy) }
    let(:enforcement_type_warn_policy_rule) do
      create(:approval_policy_rule, security_policy: enforcement_type_warn_db_policy)
    end

    let_it_be(:policy_dismissal) do
      create(:policy_dismissal, merge_request: merge_request, security_policy: enforcement_type_warn_db_policy,
        security_findings_uuids: ['uuid'])
    end

    where(:policy, :name, :report_type, :data, :status, :is_warning, :policy_rule, :is_warn_mode, :security_policy,
      :enforcement_type, :dismissed) do
      [
        [
          ref(:policy1),
          'Policy 1',
          'scan_finding',
          ref(:scan_finding_violation_data),
          :failed,
          false,
          ref(:normal_policy_rule),
          false,
          ref(:normal_db_policy),
          :enforce,
          false
        ],
        [
          ref(:policy2),
          'Policy 2',
          'license_scanning',
          ref(:license_scanning_violation_data),
          :failed,
          false,
          ref(:normal_policy_rule),
          false,
          ref(:normal_db_policy),
          :enforce,
          false
        ],
        [
          ref(:policy3),
          'Policy 3',
          'any_merge_request',
          ref(:any_merge_request_violation_data),
          :failed,
          false,
          ref(:normal_policy_rule),
          false,
          ref(:normal_db_policy),
          :enforce,
          false
        ],
        [
          ref(:policy1),
          'Policy 1',
          'scan_finding',
          ref(:scan_finding_violation_data),
          :warn,
          true,
          ref(:enforcement_type_warn_policy_rule),
          true,
          ref(:enforcement_type_warn_db_policy),
          :warn,
          true
        ]
      ]
    end

    with_them do
      before do
        create_violation_with_rule(status, policy: policy, approval_policy_rule: policy_rule,
          report_type: report_type.to_sym, violation_data: data)
      end

      it 'has correct attributes', :aggregate_failures do
        expect(violations.size).to eq 1

        violation = violations.first
        expect(violation.name).to eq security_policy.name
        expect(violation.report_type).to eq report_type
        expect(violation.data).to eq data
        expect(violation.scan_result_policy_id).to eq policy.id
        expect(violation.approval_policy_rule_id).to eq policy_rule.id
        expect(violation.warning).to eq is_warning
        expect(violation.status).to eq status.to_s
        expect(violation.warn_mode).to eq is_warn_mode
        expect(violation.security_policy_id).to eq security_policy.id
        expect(violation.enforcement_type).to eq enforcement_type.to_s
        expect(violation.dismissed).to eq dismissed
      end
    end

    context 'when there is a violation that has no approval rules associated with it' do
      let_it_be(:policy_without_rules) do
        create(:scan_result_policy_read, project: project,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration)
      end

      before do
        create(:scan_result_policy_violation, project: project, merge_request: merge_request,
          scan_result_policy_read: policy_without_rules, violation_data: any_merge_request_violation_data)
      end

      it 'is ignored' do
        expect(violations).to be_empty
      end
    end

    describe 'filtering violation by branch rule' do
      let_it_be(:policy) do
        create(:scan_result_policy_read, project: project,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration)
      end

      let_it_be(:approval_policy_rule, freeze: false) do
        create(:approval_policy_rule,
          security_policy: create(:security_policy, name: 'Test Policy',
            security_orchestration_policy_configuration: security_orchestration_policy_configuration))
      end

      let_it_be(:approver_rule_policy) do
        create(:report_approver_rule, :scan_finding, merge_request: merge_request,
          scan_result_policy_read: policy, approval_policy_rule: approval_policy_rule, name: 'Test Policy')
      end

      before do
        create(:scan_result_policy_violation, project: project, merge_request: merge_request,
          scan_result_policy_read: policy, violation_data: scan_finding_violation_data,
          approval_policy_rule: approval_policy_rule
        )
      end

      context 'when the associated approval rule is not applicable to target branch' do
        before do
          approval_policy_rule.update!(
            content: approval_policy_rule.content.merge("branches" => ['random'])
          )
        end

        it 'ignores the violation' do
          expect(violations).to be_empty
        end
      end

      context 'when the associated approval rule is applicable to target branch' do
        before do
          approval_policy_rule.update!(
            content: approval_policy_rule.content.merge("branches" => [merge_request.target_branch])
          )
        end

        it 'includes the violation' do
          expect(violations.size).to eq 1

          violation = violations.first
          expect(violation.name).to eq approval_policy_rule.security_policy.name
          expect(violation.scan_result_policy_id).to eq policy.id
          expect(violation.approval_policy_rule_id).to eq approval_policy_rule.id
        end
      end
    end

    context 'when deprecate_scan_result_policies is disabled' do
      before do
        stub_feature_flags(deprecate_scan_result_policies: false)

        create(:scan_result_policy_violation, :failed, project: project, merge_request: merge_request,
          scan_result_policy_read: policy1, violation_data: scan_finding_violation_data)
      end

      it 'resolves the violation rule via scan_result_policy_id', :aggregate_failures do
        expect(violations.size).to eq 1

        violation = violations.first
        expect(violation.scan_result_policy_id).to eq policy1.id
        expect(violation.approval_policy_rule_id).to be_nil
      end
    end

    context 'when enabled_violated_policy_ids are provided' do
      let_it_be(:policy1_rule) { create(:approval_policy_rule) }
      let_it_be(:policy2_rule) { create(:approval_policy_rule) }

      before do
        create_violation_with_rule(:failed, policy: policy1, approval_policy_rule: policy1_rule,
          report_type: :scan_finding, violation_data: scan_finding_violation_data)
        create_violation_with_rule(:failed, policy: policy2, approval_policy_rule: policy2_rule,
          report_type: :license_scanning, violation_data: license_scanning_violation_data)
      end

      context 'when filtering to a subset of policies' do
        let(:details) { described_class.new(merge_request, enabled_violated_policy_ids: [policy1_rule.id]) }

        it 'only includes violations for the given enabled_violated_policy_ids' do
          expect(violations.map(&:approval_policy_rule_id)).to contain_exactly(policy1_rule.id)
        end
      end

      context 'when the provided ids do not match any violation' do
        let(:details) { described_class.new(merge_request, enabled_violated_policy_ids: [non_existing_record_id]) }

        it 'returns no violations' do
          expect(violations).to be_empty
        end
      end

      context 'when enabled_violated_policy_ids is nil' do
        let(:details) { described_class.new(merge_request, enabled_violated_policy_ids: nil) }

        it 'includes all violations' do
          expect(violations.map(&:approval_policy_rule_id)).to contain_exactly(policy1_rule.id, policy2_rule.id)
        end
      end

      context 'when deprecate_scan_result_policies is disabled' do
        before do
          stub_feature_flags(deprecate_scan_result_policies: false)
        end

        context 'when filtering to a subset of policies' do
          let(:details) { described_class.new(merge_request, enabled_violated_policy_ids: [policy1.id]) }

          it 'only includes violations for the given enabled_violated_policy_ids' do
            expect(violations.map(&:scan_result_policy_id)).to contain_exactly(policy1.id)
          end
        end

        context 'when the provided ids do not match any violation' do
          let(:details) do
            described_class.new(merge_request, enabled_violated_policy_ids: [non_existing_record_id])
          end

          it 'returns no violations' do
            expect(violations).to be_empty
          end
        end

        context 'when enabled_violated_policy_ids is nil' do
          let(:details) { described_class.new(merge_request, enabled_violated_policy_ids: nil) }

          it 'includes all violations' do
            expect(violations.map(&:scan_result_policy_id)).to contain_exactly(policy1.id, policy2.id)
          end
        end
      end
    end
  end
  # rubocop:enable RSpec/MultipleMemoizedHelpers

  describe '#fail_closed_policies' do
    subject(:fail_closed_policies) { details.fail_closed_policies }

    let!(:policy1_violation) do
      create_violation_with_rule(policy: policy1, policy_name: 'Policy', report_type: :scan_finding)
    end

    let!(:policy2_violation) do
      create_violation_with_rule(policy: policy2, policy_name: 'Policy', report_type: :license_scanning)
    end

    let(:warn_mode_policy_rule) { create(:approval_policy_rule, security_policy: warn_mode_db_policy) }

    before do
      create_violation_with_rule(policy: policy3, policy_name: 'Other', report_type: :scan_finding)
      create_violation_with_rule(policy: policy_warn_mode, approval_policy_rule: warn_mode_policy_rule,
        report_type: :any_merge_request)
    end

    it { is_expected.to contain_exactly 'Policy', 'Other', 'Warn mode' }

    context 'when filtered by report_type' do
      subject(:fail_closed_policies) { details.fail_closed_policies(:license_scanning) }

      it { is_expected.to contain_exactly 'Policy' }
    end

    context 'when violation has status warn' do
      let!(:policy1_violation) do
        create_violation_with_rule(:warn, policy: policy1, policy_name: 'Policy', report_type: :scan_finding)
      end

      let!(:policy2_violation) do
        create_violation_with_rule(:warn, policy: policy2, policy_name: 'Policy', report_type: :license_scanning)
      end

      it('is excluded') { is_expected.to contain_exactly 'Other', 'Warn mode' }
    end
  end

  describe '#fail_open_policies' do
    subject(:fail_open_policies) { details.fail_open_policies }

    before do
      create_violation_with_rule(:failed, policy: policy1, policy_name: 'Policy', report_type: :scan_finding)
      create_violation_with_rule(:failed, policy: policy2, policy_name: 'Policy', report_type: :license_scanning)
      create_violation_with_rule(:warn, policy: policy3, policy_name: 'Other', report_type: :scan_finding)
      create_violation_with_rule(:warn, policy: policy_warn_mode, approval_policy_rule: warn_mode_policy_rule,
        report_type: :any_merge_request)
    end

    it { is_expected.to contain_exactly 'Other', 'Warn mode' }
  end

  describe '#warn_mode_policies' do
    subject(:warn_mode_policies) { details.warn_mode_policies }

    let(:normal_db_policy) do
      create(:security_policy, policy_index: 1,
        security_orchestration_policy_configuration: security_orchestration_policy_configuration)
    end

    let(:normal_policy_rule) { create(:approval_policy_rule, security_policy: normal_db_policy) }

    context 'when there are a mix of policy types' do
      before do
        create_violation_with_rule(policy: policy1, approval_policy_rule: warn_mode_policy_rule)
        create_violation_with_rule(policy: policy2, approval_policy_rule: normal_policy_rule)
      end

      it 'returns only warn mode policies' do
        expect(warn_mode_policies).to contain_exactly(warn_mode_db_policy)
      end
    end

    describe '#warn_mode_violations' do
      subject(:warn_mode_violations) { details.warn_mode_violations }

      let(:normal_db_policy) do
        create(:security_policy, policy_index: 1,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration)
      end

      let(:normal_policy_rule) { create(:approval_policy_rule, security_policy: normal_db_policy) }

      let!(:warn_mode_violation) do
        create_violation_with_rule(policy: policy1, approval_policy_rule: warn_mode_policy_rule)
      end

      let!(:normal_violation) do
        create_violation_with_rule(policy: policy2, approval_policy_rule: normal_policy_rule)
      end

      it 'returns only warn mode violations' do
        expect(warn_mode_violations.pluck(:security_policy)).to contain_exactly(warn_mode_db_policy)
      end
    end

    describe '#enforced_violations' do
      subject(:enforced_violations) { details.enforced_violations }

      let(:normal_db_policy) do
        create(:security_policy, policy_index: 1,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration)
      end

      let(:normal_policy_rule) { create(:approval_policy_rule, security_policy: normal_db_policy) }

      let!(:warn_mode_violation) do
        create_violation_with_rule(policy: policy1, approval_policy_rule: warn_mode_policy_rule)
      end

      let!(:normal_violation) do
        create_violation_with_rule(policy: policy2, approval_policy_rule: normal_policy_rule)
      end

      it 'returns only non-warn mode violations' do
        expect(enforced_violations.pluck(:security_policy)).to contain_exactly(normal_db_policy)
      end
    end

    context 'when there are multiple warn mode policies' do
      let(:another_warn_mode_db_policy) do
        create(:security_policy, :enforcement_type_warn, policy_index: 2,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration)
      end

      let(:another_warn_policy_rule) { create(:approval_policy_rule, security_policy: another_warn_mode_db_policy) }

      before do
        create_violation_with_rule(policy: policy1, approval_policy_rule: warn_mode_policy_rule)
        create_violation_with_rule(policy: policy3, approval_policy_rule: another_warn_policy_rule)
      end

      it 'returns all warn mode policies' do
        expect(warn_mode_policies).to contain_exactly(warn_mode_db_policy, another_warn_mode_db_policy)
      end
    end
  end

  describe 'scan finding violations' do
    let_it_be_with_reload(:policy1_violation) do
      build_violation_details(policy1,
        context: { pipeline_ids: [pipeline.id] },
        violations: { scan_finding: { uuids: { newly_detected: [uuid], previously_existing: [uuid_previous] } } }
      )
    end

    let_it_be_with_reload(:policy1_security_finding) do
      pipeline_scan = create(:security_scan, :succeeded, build: ci_build, scan_type: 'dependency_scanning')
      create(:security_finding, :with_finding_data, scan: pipeline_scan, scanner: scanner, severity: 'high',
        uuid: uuid, location: { start_line: 3, file: '.env' })
    end

    let_it_be_with_reload(:policy1_vulnerability_finding) do
      create(:vulnerabilities_finding, :with_secret_detection, project: project, scanner: scanner,
        uuid: uuid_previous, name: 'AWS API key')
    end

    before_all do
      # Unrelated violation that is expected to be filtered out
      build_violation_details(policy3, violations: { any_merge_request: { commits: true } })
    end

    shared_examples 'with CVE enrichment data' do
      before do
        create(:security_finding_enrichment, finding_uuid: finding_uuid)
      end

      it 'includes CVE enrichments in the violation' do
        expect(violation.cve_enrichments).not_to be_empty
        expect(violation.cve_enrichments.first.finding_uuid).to eq(finding_uuid)
      end
    end

    describe '#new_scan_finding_violations' do
      let(:violation) { new_scan_finding_violations.first }

      subject(:new_scan_finding_violations) { details.new_scan_finding_violations }

      context 'with CVE enrichment data' do
        let(:finding_uuid) { uuid }

        before do
          create(:security_finding_enrichment, finding_uuid: uuid)
        end

        it_behaves_like 'with CVE enrichment data'
      end

      context 'with additional unrelated violation' do
        before do
          build_violation_details(policy2,
            violations: { scan_finding: { uuids: { previously_existing: [uuid_previous] } } }
          )
        end

        it 'returns only related new scan finding violations', :aggregate_failures do
          expect(new_scan_finding_violations.size).to eq 1

          expect(violation.report_type).to eq 'dependency_scanning'
          expect(violation.name).to eq 'Test finding'
          expect(violation.severity).to eq 'high'
          expect(violation.path).to match(/^http.+\.env#L3$/)
          expect(violation.location).to match(file: '.env', start_line: 3)
        end
      end

      context 'with multiple pipelines detecting the same uuid' do
        let_it_be(:other_pipeline) do
          create(:ee_ci_pipeline, :success, :with_dependency_scanning_report, project: project,
            ref: merge_request.source_branch, sha: merge_request.diff_head_sha)
        end

        before_all do
          pipeline_scan = create(:security_scan, :succeeded, build: other_pipeline.builds.first,
            scan_type: 'dependency_scanning')
          create(:security_finding, scan: pipeline_scan, scanner: scanner, severity: 'high',
            uuid: uuid, location: { start_line: 3, file: '.env' })
          policy1_violation.update!(violation_data: policy1_violation.violation_data.merge(
            context: { pipeline_ids: [pipeline.id, other_pipeline.id] }
          ))
        end

        it 'returns only one violation', :aggregate_failures do
          expect(new_scan_finding_violations.size).to eq 1

          expect(violation.report_type).to eq 'dependency_scanning'
          expect(violation.name).to eq 'Test finding'
          expect(violation.severity).to eq 'high'
          expect(violation.path).to match(/^http.+\.env#L3$/)
          expect(violation.location).to match(file: '.env', start_line: 3)
        end
      end

      context 'when multiple policies containing the same uuid' do
        before do
          build_violation_details(policy2,
            context: { pipeline_ids: [pipeline.id] },
            violations: {
              scan_finding: { uuids: { newly_detected: [uuid] } }
            }
          )
        end

        it 'returns de-duplicated violations', :aggregate_failures do
          expect(new_scan_finding_violations.size).to eq 1

          expect(violation.report_type).to eq 'dependency_scanning'
          expect(violation.name).to eq 'Test finding'
          expect(violation.severity).to eq 'high'
          expect(violation.path).to match(/^http.+\.env#L3$/)
          expect(violation.location).to match(file: '.env', start_line: 3)
        end
      end

      context 'when the referenced finding does not contain any finding_data' do
        before do
          policy1_security_finding.update!(finding_data: {})
        end

        it 'returns violations without location, path and name', :aggregate_failures do
          expect(new_scan_finding_violations.size).to eq 1

          expect(violation.report_type).to eq 'dependency_scanning'
          expect(violation.severity).to eq 'high'
          expect(violation.name).to be_nil
          expect(violation.path).to be_nil
          expect(violation.location).to be_nil
        end
      end
    end

    describe '#previous_warn_mode_scan_finding_violations' do
      subject(:previous_warn_mode_scan_finding_violations) { details.previous_warn_mode_scan_finding_violations }

      let(:normal_db_policy) do
        create(:security_policy, policy_index: 1,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration)
      end

      let(:normal_policy_rule) { create(:approval_policy_rule, security_policy: normal_db_policy) }

      before do
        policy1_violation.update!(approval_policy_rule: warn_mode_policy_rule)
        ensure_approval_rule(warn_mode_policy_rule)

        create_violation_with_rule(policy: policy2, approval_policy_rule: normal_policy_rule,
          violation_data: {
            'context' => { 'pipeline_ids' => [pipeline.id] },
            'violations' => { 'scan_finding' => { 'uuids' => { 'previously_existing' => [uuid] } } }
          })
      end

      it 'returns only previously existing violations from warn mode policies' do
        expect(previous_warn_mode_scan_finding_violations).to contain_exactly(
          have_attributes(name: policy1_vulnerability_finding.name,
            report_type: policy1_vulnerability_finding.report_type,
            severity: policy1_vulnerability_finding.severity))
      end
    end

    describe '#previous_enforced_scan_finding_violations' do
      subject(:previous_enforced_scan_finding_violations) { details.previous_enforced_scan_finding_violations }

      let(:normal_db_policy) do
        create(:security_policy, policy_index: 1,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration)
      end

      let(:normal_policy_rule) { create(:approval_policy_rule, security_policy: normal_db_policy) }

      before do
        policy1_violation.update!(approval_policy_rule: warn_mode_policy_rule)
        ensure_approval_rule(warn_mode_policy_rule)

        create_violation_with_rule(policy: policy2, approval_policy_rule: normal_policy_rule,
          violation_data: {
            'context' => { 'pipeline_ids' => [pipeline.id] },
            'violations' => { 'scan_finding' => { 'uuids' => { 'previously_existing' => [uuid_previous] } } }
          })
      end

      it 'returns only previously existing violations from enforced (non-warn mode) policies' do
        expect(previous_enforced_scan_finding_violations).to contain_exactly(
          have_attributes(name: policy1_vulnerability_finding.name,
            report_type: policy1_vulnerability_finding.report_type,
            severity: policy1_vulnerability_finding.severity))
      end
    end

    describe '#previous_scan_finding_violations' do
      let(:violation) { previous_scan_finding_violations.first }

      subject(:previous_scan_finding_violations) { details.previous_scan_finding_violations }

      context 'with CVE enrichment data' do
        let(:finding_uuid) { uuid_previous }

        before do
          create(:security_finding, uuid: uuid_previous)
        end

        it_behaves_like 'with CVE enrichment data'
      end

      context 'with additional unrelated violation' do
        before do
          build_violation_details(policy2,
            context: { pipeline_ids: [pipeline.id] },
            violations: { scan_finding: { uuids: { newly_detected: [uuid] } } }
          )
        end

        it 'returns only related previous scan finding violations', :aggregate_failures do
          expect(previous_scan_finding_violations.size).to eq 1

          expect(violation.report_type).to eq 'secret_detection'
          expect(violation.name).to eq 'AWS API key'
          expect(violation.severity).to eq 'critical'
          expect(violation.path).to match(/^http.+aws-key\.py#L5$/)
          expect(violation.location).to match(hash_including(file: 'aws-key.py', start_line: 5))
        end
      end

      context 'when multiple policies containing the same uuid' do
        before do
          build_violation_details(policy2,
            violations: {
              scan_finding: { uuids: { previously_existing: [uuid_previous] } }
            }
          )
        end

        it 'returns de-duplicated violations', :aggregate_failures do
          expect(previous_scan_finding_violations.size).to eq 1

          expect(violation.report_type).to eq 'secret_detection'
          expect(violation.name).to eq 'AWS API key'
          expect(violation.severity).to eq 'critical'
          expect(violation.path).to match(/^http.+aws-key\.py#L5$/)
          expect(violation.location).to match(hash_including(file: 'aws-key.py', start_line: 5))
        end
      end

      context 'when the referenced finding does not contain any raw_metadata' do
        before do
          policy1_vulnerability_finding.update! raw_metadata: {}
        end

        it 'returns violations without location and path', :aggregate_failures do
          expect(previous_scan_finding_violations.size).to eq 1

          expect(violation.report_type).to eq 'secret_detection'
          expect(violation.severity).to eq 'critical'
          expect(violation.name).to eq 'AWS API key'
          expect(violation.path).to be_nil
          expect(violation.location).to eq({})
        end
      end
    end
  end

  describe '#any_merge_request_violations' do
    subject(:violations) { details.any_merge_request_violations }

    before do
      create_violation_with_rule(policy: policy3, report_type: :any_merge_request, policy_name: 'Policy',
        violation_data: { violations: { any_merge_request: { commits: commits } } })
      # Unrelated violation that is expected to be filtered out
      build_violation_details(policy1,
        context: { pipeline_ids: [pipeline.id] },
        violations: { scan_finding: { uuids: { newly_detected: [uuid], previously_existing: [uuid_previous] } } }
      )
    end

    context 'when commits is boolean' do
      let(:commits) { true }

      it 'returns only any_merge_request violations', :aggregate_failures do
        expect(violations.size).to eq 1

        violation = violations.first
        expect(violation.name).to eq 'Policy'
        expect(violation.commits).to be true
      end
    end

    context 'when commits is array' do
      let(:commits) { ['abcd1234'] }

      it 'returns only any_merge_request violations', :aggregate_failures do
        expect(violations.size).to eq 1

        violation = violations.first
        expect(violation.name).to eq 'Policy'
        expect(violation.commits).to match_array(['abcd1234'])
      end
    end
  end

  describe '#enforced_any_merge_request_violations' do
    subject(:violations_enforced) { details.enforced_any_merge_request_violations }

    context 'when there are both enforced and warn mode violations' do
      before do
        create_violation_with_rule(policy: policy3, report_type: :any_merge_request, policy_name: 'Policy',
          violation_data: { 'violations' => { 'any_merge_request' => { 'commits' => true } } })
        create_violation_with_rule(policy: policy_warn_mode, report_type: :any_merge_request, warn_mode: true,
          violation_data: { 'violations' => { 'any_merge_request' => { 'commits' => ['sha123'] } } })
      end

      it { is_expected.to contain_exactly(have_attributes(name: 'Policy', warn_mode: false, commits: true)) }
    end

    context 'when there are only warn mode violations' do
      before do
        create_violation_with_rule(policy: policy_warn_mode, report_type: :any_merge_request, warn_mode: true,
          violation_data: { 'violations' => { 'any_merge_request' => { 'commits' => true } } })
      end

      it { is_expected.to be_empty }
    end

    context 'when there are multiple enforced violations' do
      let_it_be(:another_policy) do
        create(:scan_result_policy_read, project: project,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration)
      end

      before do
        create_violation_with_rule(policy: policy3, report_type: :any_merge_request, policy_name: 'Policy',
          violation_data: { 'violations' => { 'any_merge_request' => { 'commits' => ['sha1'] } } })
        create_violation_with_rule(policy: another_policy, report_type: :any_merge_request,
          policy_name: 'Another Policy',
          violation_data: { 'violations' => { 'any_merge_request' => { 'commits' => ['sha2'] } } })
      end

      specify do
        expect(violations_enforced).to contain_exactly(
          have_attributes(name: 'Policy', warn_mode: false, commits: %w[sha1]),
          have_attributes(name: 'Another Policy', warn_mode: false, commits: %w[sha2])
        )
      end
    end

    context 'when violations have commits as array' do
      before do
        create_violation_with_rule(policy: policy3, report_type: :any_merge_request, policy_name: 'Policy',
          violation_data: { 'violations' => { 'any_merge_request' => { 'commits' => %w[sha1 sha2] } } })
      end

      it { is_expected.to contain_exactly(have_attributes(name: 'Policy', warn_mode: false, commits: %w[sha1 sha2])) }
    end
  end

  describe '#warn_mode_any_merge_request_violations' do
    subject(:violations_bypassable) { details.warn_mode_any_merge_request_violations }

    context 'when there are both enforced and warn mode violations' do
      before do
        create_violation_with_rule(policy: policy3, report_type: :any_merge_request, policy_name: 'Policy',
          violation_data: { 'violations' => { 'any_merge_request' => { 'commits' => true } } })
        create_violation_with_rule(policy: policy_warn_mode, report_type: :any_merge_request, warn_mode: true,
          policy_name: 'Warn mode',
          violation_data: { 'violations' => { 'any_merge_request' => { 'commits' => ['sha123'] } } })
      end

      it { is_expected.to contain_exactly(have_attributes(name: 'Warn mode', warn_mode: true, commits: %w[sha123])) }
    end

    context 'when there are only enforced violations' do
      before do
        create_violation_with_rule(policy: policy3, report_type: :any_merge_request, policy_name: 'Policy',
          violation_data: { 'violations' => { 'any_merge_request' => { 'commits' => true } } })
      end

      it { is_expected.to be_empty }
    end

    context 'when there are multiple warn mode violations' do
      let_it_be(:another_policy_warn) do
        create(:scan_result_policy_read, project: project,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration)
      end

      before do
        create_violation_with_rule(policy: policy_warn_mode, report_type: :any_merge_request, warn_mode: true,
          policy_name: 'Warn mode',
          violation_data: { 'violations' => { 'any_merge_request' => { 'commits' => ['sha1'] } } })
        create_violation_with_rule(policy: another_policy_warn, report_type: :any_merge_request, warn_mode: true,
          policy_name: 'Another Warn Policy',
          violation_data: { 'violations' => { 'any_merge_request' => { 'commits' => ['sha2'] } } })
      end

      specify do
        expect(violations_bypassable).to contain_exactly(
          have_attributes(name: 'Warn mode', warn_mode: true, commits: %w[sha1]),
          have_attributes(name: 'Another Warn Policy', warn_mode: true, commits: %w[sha2])
        )
      end
    end

    context 'when violations have commits as boolean' do
      before do
        create_violation_with_rule(policy: policy_warn_mode, report_type: :any_merge_request, warn_mode: true,
          policy_name: 'Warn mode',
          violation_data: { 'violations' => { 'any_merge_request' => { 'commits' => false } } })
      end

      it { is_expected.to contain_exactly(have_attributes(name: 'Warn mode', warn_mode: true, commits: false)) }
    end
  end

  describe '#license_scanning_violations' do
    subject(:violations) { details.license_scanning_violations }

    context 'with violation without data' do
      before do
        build_violation_details(policy1, nil)
      end

      it 'returns empty list' do
        expect(violations).to be_empty
      end
    end

    context 'when a violation exists' do
      context 'when software license matching the name does not exists' do
        before do
          build_violation_details(policy1, violations: { license_scanning: { 'License' => %w[B C D] } })
        end

        it 'returns list of licenses with dependencies' do
          expect(violations.size).to eq 1
          violation = violations.first
          expect(violation.license).to eq 'License'
          expect(violation.dependencies).to contain_exactly('B', 'C', 'D')
          expect(violation.url).to be_nil
        end
      end

      context 'when software license matching the name exists' do
        before do
          build_violation_details(policy1, violations: { license_scanning: { 'MIT License' => %w[B C D] } })
        end

        it 'includes license URL' do
          violation = violations.first
          expect(violation.url).to eq 'https://spdx.org/licenses/MIT.html'
        end

        context 'when multiple violations exist' do
          before do
            build_violation_details(policy2,
              violations: { license_scanning: { 'MIT License' => %w[A B], 'w3m License' => %w[A] } }
            )
          end

          it 'merges the licenses and dependencies' do
            expect(violations.size).to eq 2
            expect(violations).to contain_exactly(
              Security::ScanResultPolicies::PolicyViolationDetails::LicenseScanningViolation.new(license: 'w3m License',
                dependencies: %w[A], url: 'https://spdx.org/licenses/w3m.html'),
              Security::ScanResultPolicies::PolicyViolationDetails::LicenseScanningViolation.new(license: 'MIT License',
                dependencies: %w[A B C D], url: 'https://spdx.org/licenses/MIT.html')
            )
          end
        end
      end
    end
  end

  # rubocop:disable RSpec/MultipleMemoizedHelpers -- required for test setup
  describe 'license scanning violations' do
    let(:normal_db_policy) do
      create(:security_policy, policy_index: 1,
        security_orchestration_policy_configuration: security_orchestration_policy_configuration)
    end

    let(:normal_policy_rule) { create(:approval_policy_rule, security_policy: normal_db_policy) }

    shared_context 'with violations' do
      let(:another_normal_db_policy) do
        create(:security_policy, policy_index: 2,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration)
      end

      let(:another_normal_policy_rule) { create(:approval_policy_rule, security_policy: another_normal_db_policy) }

      let(:another_warn_mode_db_policy) do
        create(:security_policy, :enforcement_type_warn, policy_index: 4,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration)
      end

      let(:another_warn_policy_rule) { create(:approval_policy_rule, security_policy: another_warn_mode_db_policy) }

      let_it_be(:another_policy) do
        create(:scan_result_policy_read, project: project,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration)
      end

      let_it_be(:another_policy_warn) do
        create(:scan_result_policy_read, project: project,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration)
      end
    end

    describe '#enforced_license_scanning_violations' do
      subject(:enforced_license_scanning_violations) { details.enforced_license_scanning_violations }

      include_context 'with violations'

      context 'when there are both enforced and warn mode violations' do
        before do
          create_violation_with_rule(policy: policy2, approval_policy_rule: normal_policy_rule,
            violation_data: { 'violations' => { 'license_scanning' => { 'MIT License' => %w[A B] } } })

          create_violation_with_rule(policy: policy_warn_mode, approval_policy_rule: warn_mode_policy_rule,
            violation_data: { 'violations' => { 'license_scanning' => { 'Apache-2.0' => %w[C D] } } })
        end

        it 'returns only license scanning violations from enforced (non-warn mode) policies' do
          expect(enforced_license_scanning_violations).to contain_exactly(
            have_attributes(
              license: 'MIT License',
              dependencies: %w[A B],
              url: 'https://spdx.org/licenses/MIT.html'
            )
          )
        end
      end

      context 'when there are only warn mode violations' do
        before do
          create_violation_with_rule(policy: policy_warn_mode, approval_policy_rule: warn_mode_policy_rule,
            violation_data: { 'violations' => { 'license_scanning' => { 'MIT License' => %w[A B] } } })
        end

        it { is_expected.to be_empty }
      end

      context 'when there are multiple enforced violations' do
        before do
          create_violation_with_rule(policy: policy2, approval_policy_rule: normal_policy_rule,
            violation_data: { 'violations' => { 'license_scanning' => { 'MIT License' => %w[A B] } } })

          create_violation_with_rule(policy: another_policy, approval_policy_rule: another_normal_policy_rule,
            violation_data: {
              'violations' => { 'license_scanning' => { 'MIT License' => %w[C], 'w3m License' => %w[D] } }
            })
        end

        it 'merges licenses from multiple enforced violations' do
          expect(enforced_license_scanning_violations).to contain_exactly(
            have_attributes(
              license: 'MIT License',
              dependencies: %w[A B C],
              url: 'https://spdx.org/licenses/MIT.html'
            ),
            have_attributes(
              license: 'w3m License',
              dependencies: %w[D],
              url: 'https://spdx.org/licenses/w3m.html'
            )
          )
        end
      end
    end

    describe '#warn_mode_license_scanning_violations' do
      subject(:warn_mode_license_scanning_violations) { details.warn_mode_license_scanning_violations }

      include_context 'with violations'

      context 'when there are both enforced and warn mode violations' do
        before do
          create_violation_with_rule(policy: policy2, approval_policy_rule: normal_policy_rule,
            violation_data: { 'violations' => { 'license_scanning' => { 'MIT License' => %w[A B] } } })

          create_violation_with_rule(policy: policy_warn_mode, approval_policy_rule: warn_mode_policy_rule,
            violation_data: { 'violations' => { 'license_scanning' => { 'Apache-2.0' => %w[C D] } } })
        end

        it 'returns only license scanning violations from warn mode policies' do
          expect(warn_mode_license_scanning_violations).to contain_exactly(
            have_attributes(
              license: 'Apache-2.0',
              dependencies: %w[C D]
            )
          )
        end
      end

      context 'when there are only enforced violations' do
        before do
          create_violation_with_rule(policy: policy2, approval_policy_rule: normal_policy_rule,
            violation_data: { 'violations' => { 'license_scanning' => { 'MIT License' => %w[A B] } } })
        end

        it { is_expected.to be_empty }
      end

      context 'when there are multiple warn mode violations' do
        before do
          create_violation_with_rule(policy: policy_warn_mode, approval_policy_rule: warn_mode_policy_rule,
            violation_data: { 'violations' => { 'license_scanning' => { 'MIT License' => %w[A B] } } })

          create_violation_with_rule(policy: another_policy_warn, approval_policy_rule: another_warn_policy_rule,
            violation_data: {
              'violations' => { 'license_scanning' => { 'MIT License' => %w[C], 'GPL-3.0' => %w[D] } }
            })
        end

        it 'merges licenses from multiple warn mode violations' do
          expect(warn_mode_license_scanning_violations).to contain_exactly(
            have_attributes(
              license: 'MIT License',
              dependencies: %w[A B C]
            ),
            have_attributes(
              license: 'GPL-3.0',
              dependencies: %w[D]
            )
          )
        end
      end
    end
  end
  # rubocop:enable RSpec/MultipleMemoizedHelpers

  describe '#errors' do
    subject(:errors) { details.errors }

    context 'with SCAN_REMOVED error' do
      let_it_be(:violation1) do
        build_violation_with_error(policy1,
          Security::ScanResultPolicyViolation::ERRORS[:scan_removed], 'missing_scans' => %w[secret_detection])
      end

      it 'returns associated error messages' do
        expect(errors.pluck(:message)).to contain_exactly(
          'There is a mismatch between the scans of the source and target pipelines. ' \
            'The following scans are missing: Secret detection'
        )
      end
    end

    context 'with TARGET_SCAN_MISSING error' do
      let_it_be(:violation1) do
        build_violation_with_error(policy1,
          Security::ScanResultPolicyViolation::ERRORS[:target_scan_missing], 'missing_scans' => %w[secret_detection])
      end

      it 'returns associated error messages' do
        expect(errors.pluck(:message)).to contain_exactly(
          'The enforced scans could not be found in the target pipelines. ' \
            'The following scans are missing: Secret detection'
        )
      end
    end

    context 'with TARGET_PIPELINE_MISSING error' do
      let_it_be(:violation1) do
        build_violation_with_error(policy1, Security::ScanResultPolicyViolation::ERRORS[:target_pipeline_missing])
      end

      it 'returns associated error messages' do
        expect(errors.pluck(:message)).to contain_exactly(
          'Pipeline configuration error: SBOM reports required by policy `Policy` ' \
          'could not be found on the target branch.'
        )
      end
    end

    context 'with ARTIFACTS_MISSING error' do
      context 'with scan_finding report_type' do
        let_it_be(:violation1) do
          build_violation_with_error(policy1, Security::ScanResultPolicyViolation::ERRORS[:artifacts_missing])
        end

        it 'returns associated error messages' do
          expect(errors.pluck(:message)).to contain_exactly(
            'Pipeline configuration error: Security reports required by policy `Policy` could not be found.'
          )
        end
      end

      context 'with license_scanning report_type' do
        let_it_be(:violation1) do
          build_violation_with_error(policy2, Security::ScanResultPolicyViolation::ERRORS[:artifacts_missing])
        end

        it 'returns associated error messages' do
          expect(errors.pluck(:message)).to contain_exactly(
            'Pipeline configuration error: SBOM reports required by policy `Policy` could not be found.'
          )
        end
      end

      context 'with unsupported report_type' do
        let_it_be(:violation1) do
          build_violation_with_error(policy3, Security::ScanResultPolicyViolation::ERRORS[:artifacts_missing])
        end

        it 'returns associated error messages' do
          expect(errors.pluck(:message)).to contain_exactly(
            'Pipeline configuration error: Artifacts required by policy `Policy` could not be found ' \
            '(any_merge_request).'
          )
        end
      end
    end

    context 'with EVALUATION_SKIPPED error' do
      let_it_be(:violation1) do
        build_violation_with_error(policy1,
          Security::ScanResultPolicyViolation::ERRORS[:evaluation_skipped])
      end

      it 'returns associated error messages' do
        expect(errors.pluck(:message)).to contain_exactly(
          'Policy `Policy` could not be evaluated within the specified timeframe and, as a result, ' \
          'approvals are required for the policy. Ensure that scanners are present in the latest pipeline.'
        )
      end
    end

    context 'with PIPELINE_FAILED error' do
      let_it_be(:violation1) do
        build_violation_with_error(policy1,
          Security::ScanResultPolicyViolation::ERRORS[:pipeline_failed])
      end

      it 'returns associated error messages' do
        expect(errors.pluck(:message)).to contain_exactly(
          'Policy `Policy` could not be evaluated because the latest pipeline failed. ' \
            'Ensure that the pipeline is configured properly and the scanners are present.'
        )
      end
    end

    context 'with SCAN_NOT_SUCCEEDED error' do
      context 'with single scan type' do
        let_it_be(:violation1) do
          build_violation_with_error(policy1,
            Security::ScanResultPolicyViolation::ERRORS[:scan_not_succeeded],
            'missing_scans' => %w[sast])
        end

        it 'returns associated error messages' do
          expect(errors.pluck(:message)).to contain_exactly(
            'Policy `Policy` could not be evaluated because the following security scans ' \
              'did not complete successfully: Sast. Ensure security scan jobs are not canceled or failing.'
          )
        end
      end

      context 'when missing_scans is nil' do
        let_it_be(:violation1) do
          build_violation_with_error(policy1,
            Security::ScanResultPolicyViolation::ERRORS[:scan_not_succeeded])
        end

        # This is a theoretical case for extra safety
        it 'returns associated error messages with nil scans' do
          expect(errors.pluck(:message)).to contain_exactly(
            'Policy `Policy` could not be evaluated because the following security scans ' \
              'did not complete successfully: . Ensure security scan jobs are not canceled or failing.'
          )
        end
      end

      context 'with multiple scan types' do
        let_it_be(:violation1) do
          build_violation_with_error(policy2,
            Security::ScanResultPolicyViolation::ERRORS[:scan_not_succeeded],
            'missing_scans' => %w[sast dependency_scanning])
        end

        it 'renders all scan types' do
          expect(errors.pluck(:message)).to contain_exactly(
            'Policy `Policy` could not be evaluated because the following security scans ' \
              'did not complete successfully: Sast, Dependency scanning. ' \
              'Ensure security scan jobs are not canceled or failing.'
          )
        end
      end
    end

    context 'with unsupported error' do
      let_it_be(:violation1) { build_violation_with_error(policy2, 'unsupported') }

      it 'results in unknown error message' do
        expect(errors.pluck(:error)).to contain_exactly('UNKNOWN')
        expect(errors.pluck(:message)).to contain_exactly('Unknown error: unsupported')
      end
    end
  end

  describe '#fail_open_messages' do
    subject(:fail_open_messages) { details.fail_open_messages }

    context 'with a supported error' do
      context 'when violation is warn' do
        context 'when error maps to a string' do
          let_it_be(:violation1) do
            build_violation_with_error(policy1, Security::ScanResultPolicyViolation::ERRORS[:scan_removed], :warn)
          end

          it 'returns associated fail-open message' do
            expect(fail_open_messages).to contain_exactly(
              'Confirm that all scanners from the target branch are present on the source branch.'
            )
          end
        end

        context 'when error maps to a hash' do
          let_it_be(:violation1) do
            build_violation_with_error(policy1, Security::ScanResultPolicyViolation::ERRORS[:artifacts_missing], :warn)
          end

          it 'returns associated fail-open message for the policy report_type' do
            expect(fail_open_messages).to contain_exactly(
              'Confirm that scanners are properly configured and producing results. ' \
              'Vulnerability detection depends on successful execution of security scan jobs in the ' \
              'target and source branches.'
            )
          end
        end

        context 'when error is SCAN_NOT_SUCCEEDED' do
          let_it_be(:violation1) do
            build_violation_with_error(policy1,
              Security::ScanResultPolicyViolation::ERRORS[:scan_not_succeeded], :warn,
              'missing_scans' => %w[sast])
          end

          it 'returns associated fail-open message' do
            expect(fail_open_messages).to contain_exactly(
              'Confirm that all security scan jobs complete successfully. ' \
              'Canceled or failed scan jobs may produce incomplete results.'
            )
          end
        end
      end

      context 'when violation is failed' do
        let_it_be(:violation1) do
          build_violation_with_error(policy1, Security::ScanResultPolicyViolation::ERRORS[:scan_removed], :failed)
        end

        it { is_expected.to be_empty }
      end
    end

    context 'with unsupported error' do
      let_it_be(:violation1) { build_violation_with_error(policy2, 'unsupported', :failed) }

      it { is_expected.to be_empty }
    end
  end

  describe '#comparison_pipelines' do
    subject(:comparison_pipelines) { details.comparison_pipelines }

    before do
      # scan_finding
      build_violation_details(policy1, 'context' => { 'pipeline_ids' => [2, 3], 'target_pipeline_ids' => [1] })
      build_violation_details(policy3, 'context' => { 'pipeline_ids' => [3, 4], 'target_pipeline_ids' => [1, 3] })
      # license_scanning
      build_violation_details(policy2, { 'context' => { 'pipeline_ids' => [3, 4], 'target_pipeline_ids' => [1, 2] } },
        :failed, :license_scanning)
    end

    it 'returns associated, deduplicated pipeline ids grouped by report_type', :aggregate_failures do
      expect(comparison_pipelines).to contain_exactly(
        Security::ScanResultPolicies::PolicyViolationDetails::ComparisonPipelines.new(
          report_type: 'scan_finding', source: [2, 3, 4].to_set, target: [1, 3].to_set
        ),
        Security::ScanResultPolicies::PolicyViolationDetails::ComparisonPipelines.new(
          report_type: 'license_scanning', source: [3, 4].to_set, target: [1, 2].to_set
        )
      )
    end
  end

  describe '#enforced_security_policies' do
    subject(:enforced_security_policies) { details.enforced_security_policies }

    let_it_be(:enforced_policy) do
      create(:security_policy, policy_index: 4, name: 'Enforced Policy',
        security_orchestration_policy_configuration: security_orchestration_policy_configuration)
    end

    let_it_be(:warn_mode_policy) do
      create(:security_policy, :enforcement_type_warn, policy_index: 5, name: 'Warn mode',
        security_orchestration_policy_configuration: security_orchestration_policy_configuration)
    end

    before_all do
      create(:security_policy_project_link, project: project, security_policy: enforced_policy)
      create(:security_policy_project_link, project: project, security_policy: warn_mode_policy)
    end

    it { is_expected.to contain_exactly(enforced_policy) }
  end

  describe '#violations_count' do
    before do
      build_violation_details(policy3, { violations: { any_merge_request: { commits: true } } }, :failed,
        :any_merge_request)
      build_violation_details(policy1, violations: { license_scanning: { 'MIT License' => %w[B C D] } })
    end

    it 'counts all violations' do
      expect(details.violations_count).to eq(2)
    end
  end

  private

  def build_violation_with_error(policy, error, status = :failed, **extra_data)
    create_violation_with_rule(status, policy: policy, policy_name: 'Policy', report_type: report_type_for(policy),
      violation_data: { 'errors' => [{ 'error' => error, **extra_data }] })
  end

  def report_type_for(policy)
    return :license_scanning if policy == policy2
    return :any_merge_request if policy == policy3

    :scan_finding
  end
end
