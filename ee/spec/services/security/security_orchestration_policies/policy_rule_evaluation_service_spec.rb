# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::PolicyRuleEvaluationService, feature_category: :security_policy_management do
  # rubocop:disable RSpec/MultipleMemoizedHelpers -- policy evaluation setup requires many memoized helpers
  def update_policy_content(scan_result_policy_read, attrs)
    scan_result_policy_read.update!(attrs)
    apr = scan_result_policy_read.approval_policy_rule
    return unless apr

    security_policy = apr.security_policy
    updated_content = security_policy.content.deep_stringify_keys.merge(attrs.deep_stringify_keys)
    security_policy.update_column(:content, updated_content)
    security_policy.reload
    apr.reload
  end

  let(:service) { described_class.new(merge_request) }
  let_it_be_with_reload(:project) { create(:project, :repository) }
  let_it_be_with_reload(:merge_request) do
    create(:merge_request, source_project: project, target_project: project)
  end

  let_it_be(:security_policy_project) { create(:project, :repository) }
  let_it_be_with_reload(:policy_configuration) do
    create(:security_orchestration_policy_configuration, project: project,
      security_policy_management_project: security_policy_project)
  end

  let_it_be(:protected_branch) do
    create(:protected_branch, name: merge_request.target_branch, project: project)
  end

  let_it_be_with_reload(:policy_a_security_policy) do
    create(:security_policy, :approval_policy,
      security_orchestration_policy_configuration: policy_configuration, policy_index: 0)
  end

  let_it_be_with_reload(:policy_a_approval_policy_rule) do
    create(:approval_policy_rule, :scan_finding, security_policy: policy_a_security_policy)
  end

  let_it_be_with_reload(:policy_a) do
    create(:scan_result_policy_read, project: project,
      security_orchestration_policy_configuration: policy_configuration, orchestration_policy_idx: 0, rule_idx: 0,
      approval_policy_rule: policy_a_approval_policy_rule)
  end

  let_it_be_with_reload(:policy_b_security_policy) do
    create(:security_policy, :approval_policy,
      security_orchestration_policy_configuration: policy_configuration, policy_index: 1)
  end

  let_it_be_with_reload(:policy_b_approval_policy_rule) do
    create(:approval_policy_rule, :scan_finding, security_policy: policy_b_security_policy)
  end

  let_it_be_with_reload(:policy_b) do
    create(:scan_result_policy_read, project: project,
      security_orchestration_policy_configuration: policy_configuration, orchestration_policy_idx: 1, rule_idx: 0,
      approval_policy_rule: policy_b_approval_policy_rule)
  end

  let_it_be(:policy_a_project_link) do
    create(:approval_policy_rule_project_link, project: project, approval_policy_rule: policy_a.approval_policy_rule)
  end

  let_it_be(:policy_b_project_link) do
    create(:approval_policy_rule_project_link, project: project, approval_policy_rule: policy_b.approval_policy_rule)
  end

  let(:vulnerability_states) { %w[new_needs_triage new_dismissed] }
  let(:rule_scanners) { %w[dependency_scanning container_scanning] }
  let(:approval_project_rule_1) do
    create(:approval_project_rule, report_type, name: "Rule 1", project: project,
      approvals_required: 1,
      vulnerability_states: vulnerability_states,
      protected_branches: [protected_branch],
      scanners: rule_scanners,
      scan_result_policy_read: policy_a,
      approval_policy_rule: policy_a.approval_policy_rule,
      security_orchestration_policy_configuration: policy_configuration)
  end

  let!(:approval_rule_1) do
    create(:report_approver_rule, report_type, name: "Rule 1", merge_request: merge_request,
      approvals_required: 1,
      approval_project_rule: approval_project_rule_1,
      vulnerability_states: vulnerability_states,
      scanners: rule_scanners,
      scan_result_policy_read: policy_a,
      approval_policy_rule: policy_a.approval_policy_rule,
      security_orchestration_policy_configuration: policy_configuration)
  end

  let!(:approval_project_rule_2) do
    create(:approval_project_rule, report_type, name: "Rule 2", project: project,
      approvals_required: 1,
      vulnerability_states: vulnerability_states,
      protected_branches: [protected_branch],
      scanners: rule_scanners,
      scan_result_policy_read: policy_b,
      approval_policy_rule: policy_b.approval_policy_rule,
      security_orchestration_policy_configuration: policy_configuration)
  end

  let!(:approval_rule_2) do
    create(:report_approver_rule, report_type, name: "Rule 2", merge_request: merge_request,
      approvals_required: 1,
      approval_project_rule: approval_project_rule_2,
      vulnerability_states: vulnerability_states,
      scanners: rule_scanners,
      scan_result_policy_read: policy_b,
      approval_policy_rule: policy_b.approval_policy_rule,
      security_orchestration_policy_configuration: policy_configuration)
  end

  let(:report_type) { :scan_finding }

  def violated_policies
    merge_request.scan_result_policy_violations.reload.map(&:scan_result_policy_read)
  end

  describe '#save' do
    subject(:execute) { service.save } # rubocop:disable Rails/SaveBang -- false positive

    describe '#fail!' do
      it 'creates violations for failed rules' do
        service.fail!(approval_rule_1)
        execute

        expect(violated_policies).to contain_exactly policy_a
      end

      it 'blocks the rule by resetting approvals' do
        approval_rule_1.update!(approvals_required: 0)
        service.fail!(approval_rule_1)

        expect { execute }.to change { approval_rule_1.reload.approvals_required }.to(1)
      end

      context 'when approval rule has no policy source' do
        it 'does not create violations' do
          approval_rule_1.update!(scan_result_policy_read: nil, approval_policy_rule: nil)
          approval_project_rule_1.update!(scan_result_policy_read: nil, approval_policy_rule: nil)
          service.fail!(approval_rule_1)

          expect { execute }.not_to change { violated_policies }
        end
      end
    end

    describe '#pass!' do
      before do
        create(:scan_result_policy_violation, project: project, merge_request: merge_request,
          scan_result_policy_read: policy_b, approval_policy_rule: policy_b.approval_policy_rule)
      end

      it 'removes violations for passed rules' do
        service.pass!(approval_rule_2)
        execute

        expect(violated_policies).to be_empty
      end

      it 'unblocks the rule by removing required approvals' do
        service.pass!(approval_rule_2)
        expect { execute }.to change { approval_rule_2.reload.approvals_required }.to(0)
      end

      context 'when approval rule has no policy source' do
        it 'does not create violations' do
          approval_rule_2.update!(scan_result_policy_read: nil, approval_policy_rule: nil)
          approval_project_rule_2.update!(scan_result_policy_read: nil, approval_policy_rule: nil)
          service.pass!(approval_rule_2)

          expect { execute }.not_to change { violated_policies }
        end
      end
    end

    describe '#error!' do
      it 'adds violations for errored rules' do
        service.error!(approval_rule_1, :scan_removed, missing_scans: rule_scanners)
        execute

        expect(violated_policies).to contain_exactly policy_a
        violation = merge_request.scan_result_policy_violations.first
        expect(violation.violation_data)
          .to eq({ 'errors' => ['error' => 'SCAN_REMOVED', 'missing_scans' => rule_scanners] })
      end

      context 'when approval rule has no policy source' do
        it 'does not create violations' do
          approval_project_rule_1.update!(scan_result_policy_read: nil, approval_policy_rule: nil)
          approval_rule_1.update!(scan_result_policy_read: nil, approval_policy_rule: nil)
          service.error!(approval_rule_1, :scan_removed, missing_scans: rule_scanners)

          expect { execute }.not_to change { violated_policies }
        end
      end

      context 'when rule is excluded' do
        context 'when security policy does not apply to target branch' do
          let_it_be(:security_policy) { create(:security_policy) }

          let_it_be(:approval_policy_rule) do
            build(:approval_policy_rule, :scan_finding, security_policy: security_policy) do |policy_rule|
              policy_rule.update!(content: policy_rule.content.merge("branches" => ["foobar"]))
            end
          end

          before do
            approval_rule_1.update!(approval_policy_rule: approval_policy_rule)
          end

          subject(:execute_with_inapplicable_error) do
            service.error!(approval_rule_1, :scan_removed, missing_scans: rule_scanners)
            execute
          end

          it 'does not create violations' do
            expect { execute_with_inapplicable_error }.not_to change { violated_policies }.from(be_empty)
          end

          it 'does not require approval' do
            expect { execute_with_inapplicable_error }.to change { approval_rule_1.reload.approvals_required }
                                                            .from(1).to(0)
          end
        end

        context 'when rule should fail open' do
          before do
            update_policy_content(policy_a, fallback_behavior: { fail: 'open' })
          end

          it 'creates a warning violation' do
            service.error!(approval_rule_1, :scan_removed, missing_scans: rule_scanners)

            expect { execute }.to change { violated_policies.size }.by(1)
            expect(violated_policies).to contain_exactly policy_a
            expect(merge_request.scan_result_policy_violations.last).to be_warn
          end
        end

        shared_examples_for 'does not create a violation' do
          it 'does not create violations' do
            expect { execute_with_error }.not_to change { violated_policies }
            expect(violated_policies).to be_empty
          end
        end

        shared_examples_for 'creates a violation' do
          it 'creates violations' do
            execute_with_error

            expect(violated_policies).to contain_exactly policy_a
          end
        end

        shared_examples_for 'rule scanners enforced by execution policy' do
          let(:scans) { %w[dependency_scanning container_scanning] }
          let(:unblock_enabled) { true }

          subject(:execute_with_error) do
            service.error!(approval_rule_1, :scan_removed, missing_scans: rule_scanners)
            execute
          end

          before do
            update_policy_content(policy_a, policy_tuning: { unblock_rules_using_execution_policies: unblock_enabled })
            allow_next_instance_of(Repository) do |repository|
              allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
            end
          end

          it_behaves_like 'does not create a violation'

          describe 'events' do
            subject { service.error!(approval_rule_1, :missing_artifacts, missing_scans: rule_scanners) }

            it_behaves_like 'internal event tracking' do
              let(:category) { described_class.name }
              let(:event) { 'unblock_approval_rule_using_scan_execution_policy' }
              let(:additional_properties) do
                {
                  label: 'dependency_scanning,container_scanning'
                }
              end
            end

            context 'when extract_scanners returns nil' do
              before do
                allow(service).to receive_messages(execution_policy_scan_enforced?: true, extract_scanners: nil)
              end

              it 'tracks the event with nil label' do
                expect(Gitlab::InternalEvents).to receive(:track_event).with(
                  'unblock_approval_rule_using_scan_execution_policy',
                  hash_including(additional_properties: { label: nil })
                )

                subject
              end
            end
          end

          context 'when the unblocking is not enabled by the policy' do
            let(:unblock_enabled) { false }

            it_behaves_like 'creates a violation'
          end

          context 'when rule has default vulnerability_states' do
            let(:vulnerability_states) { [] }

            it_behaves_like 'does not create a violation'
          end

          context 'when rule targets different scanners' do
            let(:rule_scanners) { %w[secret_detection] }

            it_behaves_like 'creates a violation'
          end

          context 'when rule is not excludable' do
            context 'when report is scan_finding' do
              let(:report_type) { :scan_finding }
              let(:vulnerability_states) { %w[detected] }

              it_behaves_like 'creates a violation'
            end

            context 'when report is license_scanning' do
              let(:report_type) { :license_scanning }

              before do
                policy_a.update!(license_states: ['detected'])
              end

              it_behaves_like 'creates a violation'
            end

            context 'when report is any_merge_request' do
              let(:report_type) { :any_merge_request }

              it_behaves_like 'creates a violation'
            end
          end

          context 'when security scan job exists but did not succeed' do
            let(:pipeline) { create(:ci_pipeline, project: project, ref: merge_request.source_branch) }

            before do
              merge_request.update!(head_pipeline: pipeline)
            end

            describe 'violations based on security job status' do
              before do
                create(:ci_build, job_status, pipeline: pipeline, name: 'dependency_scanning',
                  options: { artifacts: { reports: { dependency_scanning: 'gl-dependency-scanning-report.json' } } })
              end

              %i[canceled failed running].each do |blocking_status|
                context "when status is #{blocking_status}" do
                  let(:job_status) { blocking_status }

                  it_behaves_like 'creates a violation'
                end
              end

              context 'when security job succeeded' do
                let(:job_status) { :success }

                it_behaves_like 'does not create a violation'
              end
            end

            context 'when security job does not exist (excluded by rules)' do
              # No build created - simulates job excluded by rules:exists or rules:changes

              it_behaves_like 'does not create a violation'
            end

            context 'when one scanner job succeeded but another was canceled' do
              before do
                create(:ci_build, :success, pipeline: pipeline, name: 'dependency_scanning',
                  options: { artifacts: { reports: { dependency_scanning: 'gl-dependency-scanning-report.json' } } })
                create(:ci_build, :canceled, pipeline: pipeline, name: 'container_scanning',
                  options: { artifacts: { reports: { container_scanning: 'gl-container-scanning-report.json' } } })
              end

              it_behaves_like 'creates a violation'
            end

            context 'when one scanner job was canceled but it was retried and succeeded' do
              before do
                create(:ci_build, :canceled, :retried, pipeline: pipeline, name: 'dependency_scanning',
                  options: { artifacts: { reports: { dependency_scanning: 'gl-dependency-scanning-report.json' } } })
                create(:ci_build, :success, pipeline: pipeline, name: 'dependency_scanning',
                  options: { artifacts: { reports: { dependency_scanning: 'gl-dependency-scanning-report.json' } } })
              end

              it_behaves_like 'does not create a violation'
            end
          end
        end

        context 'with pipeline execution policies defined for the errored rule' do
          let(:pipeline_execution_policy) { build(:pipeline_execution_policy) }
          let(:policy_yaml) do
            build(:orchestration_policy_yaml, pipeline_execution_policy: [pipeline_execution_policy])
          end

          let(:policy_metadata) { { enforced_scans: scans } }
          let(:pipeline_execution_policy_configuration) { policy_configuration }

          before do
            create(:security_policy, :pipeline_execution_policy,
              security_orchestration_policy_configuration: pipeline_execution_policy_configuration,
              linked_projects: [project],
              metadata: policy_metadata)
          end

          include_context 'rule scanners enforced by execution policy'

          context 'when policy metadata is not present' do
            let(:policy_metadata) { {} }

            it_behaves_like 'creates a violation'
          end

          context 'when scans are enforced by both pipeline and scan execution policies' do
            let(:scans) { %w[dependency_scanning] }
            let(:scan_execution_policy) do
              build(:scan_execution_policy, actions: scan_execution_policy_scans.map { |scan| { scan: scan } })
            end

            let(:policy_yaml) do
              build(:orchestration_policy_yaml,
                pipeline_execution_policy: [pipeline_execution_policy],
                scan_execution_policy: [scan_execution_policy])
            end

            context 'when some scans are enforced by PEP and some by SEP' do
              let(:scan_execution_policy_scans) { %w[container_scanning] }

              it_behaves_like 'does not create a violation'
            end

            context 'when SEP enforces scans unrelated to the rule' do
              let(:scan_execution_policy_scans) { %w[secret_detection] }

              it_behaves_like 'creates a violation'
            end
          end

          context 'with group policies' do
            let_it_be(:parent_group) { create(:group) }
            let_it_be(:group) { create(:group, parent: parent_group) }

            before do
              project.update!(group: group)
            end

            context 'when policy is defined for a configuration in a group' do
              let_it_be(:pipeline_execution_policy_configuration) do
                create(:security_orchestration_policy_configuration, :namespace,
                  security_policy_management_project: security_policy_project, namespace: group)
              end

              it_behaves_like 'does not create a violation'
            end

            context 'when policy is defined for a configuration in a parent group' do
              let_it_be(:pipeline_execution_policy_configuration) do
                create(:security_orchestration_policy_configuration, :namespace,
                  security_policy_management_project: security_policy_project, namespace: parent_group)
              end

              it_behaves_like 'does not create a violation'
            end

            context 'when policy is defined for a configuration in a descendent group' do
              let_it_be(:descendent_group) { create(:group, parent: group) }
              let_it_be(:pipeline_execution_policy_configuration) do
                create(:security_orchestration_policy_configuration, :namespace,
                  security_policy_management_project: security_policy_project, namespace: descendent_group)
              end

              # NOTE: Approval rules belong to `group` config,
              # but pipeline execution policy is defined in the `descendant_group`.
              # Rules only get unblocked by ancestors of the configuration that created them.
              it_behaves_like 'creates a violation'
            end
          end
        end

        context 'with scan execution policies defined for the errored rule' do
          let(:scan_execution_policy) do
            build(:scan_execution_policy, actions: scans.map { |scan| { scan: scan } })
          end

          let(:policy_yaml) { build(:orchestration_policy_yaml, scan_execution_policy: [scan_execution_policy]) }

          include_context 'rule scanners enforced by execution policy'
        end

        context 'with atomic scanner rule criteria' do
          let(:scans) { %w[dependency_scanning container_scanning] }
          let(:unblock_enabled) { true }

          let(:atomic_policy_rule) do
            create(:approval_policy_rule, :scan_finding, security_policy: create(:security_policy), content: {
              'branches' => [],
              'scanners' => [
                { 'type' => 'dependency_scanning', 'vulnerability_attributes' => { 'fix_available' => true } },
                { 'type' => 'container_scanning', 'vulnerability_attributes' => { 'known_exploited' => true } }
              ],
              'severity_levels' => %w[critical],
              'vulnerability_states' => %w[new_needs_triage new_dismissed],
              'vulnerabilities_allowed' => 0
            })
          end

          subject(:execute_with_error) do
            service.error!(approval_rule_1, :scan_removed, missing_scans: rule_scanners)
            execute
          end

          before do
            approval_rule_1.update!(approval_policy_rule: atomic_policy_rule)
            update_policy_content(policy_a, policy_tuning: { unblock_rules_using_execution_policies: unblock_enabled })
            # Also update the atomic_policy_rule's security_policy since approval_policy_source wraps it
            atomic_security_policy = atomic_policy_rule.security_policy
            atomic_security_policy.update_column(:content,
              atomic_security_policy.content.deep_stringify_keys.merge(
                'policy_tuning' => { 'unblock_rules_using_execution_policies' => unblock_enabled }))
            atomic_security_policy.reload
            atomic_policy_rule.reload
          end

          context 'when scanners are enforced by scan execution policies' do
            let(:scan_execution_policy) do
              build(:scan_execution_policy, actions: scans.map { |scan| { scan: scan } })
            end

            let(:policy_yaml) do
              build(:orchestration_policy_yaml, scan_execution_policy: [scan_execution_policy])
            end

            before do
              allow_next_instance_of(Repository) do |repository|
                allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
              end
            end

            it 'extracts scanner types from scanner_configurations' do
              expect { execute_with_error }.not_to change { violated_policies }.from(be_empty)
            end

            describe 'events' do
              subject { service.error!(approval_rule_1, :scan_removed, missing_scans: rule_scanners) }

              it_behaves_like 'internal event tracking' do
                let(:category) { described_class.name }
                let(:event) { 'unblock_approval_rule_using_scan_execution_policy' }
                let(:additional_properties) do
                  { label: 'dependency_scanning,container_scanning' }
                end
              end
            end
          end

          context 'when rule has mixed vulnerability_states' do
            let(:atomic_policy_rule_mixed) do
              create(:approval_policy_rule, :scan_finding, security_policy: create(:security_policy), content: {
                'branches' => [],
                'scanners' => [
                  {
                    'type' => 'dependency_scanning',
                    'vulnerability_attributes' => { 'fix_available' => true }
                  },
                  {
                    'type' => 'container_scanning',
                    'vulnerability_attributes' => { 'known_exploited' => true }
                  }
                ],
                'severity_levels' => %w[critical],
                'vulnerability_states' => %w[new_needs_triage detected],
                'vulnerabilities_allowed' => 0
              })
            end

            let(:scan_execution_policy) do
              build(:scan_execution_policy, actions: scans.map { |scan| { scan: scan } })
            end

            let(:policy_yaml) do
              build(:orchestration_policy_yaml, scan_execution_policy: [scan_execution_policy])
            end

            before do
              approval_rule_1.update!(
                approval_policy_rule: atomic_policy_rule_mixed,
                vulnerability_states: %w[new_needs_triage detected]
              )
              atomic_policy_rule_mixed.security_policy.update!(
                content: atomic_policy_rule_mixed.security_policy.content.merge(
                  'policy_tuning' => { 'unblock_rules_using_execution_policies' => unblock_enabled }
                ))
              allow_next_instance_of(Repository) do |repository|
                allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
              end
            end

            it 'is not excludable when rule has pre-existing states' do
              allow(merge_request).to receive(:target_default_branch?).and_return(true)
              execute_with_error

              expect(violated_policies).to contain_exactly policy_a
            end
          end

          context 'when all scanner configurations target only newly detected states' do
            let(:atomic_policy_rule_newly_detected) do
              create(:approval_policy_rule, :scan_finding, security_policy: create(:security_policy), content: {
                'branches' => [],
                'scanners' => [
                  {
                    'type' => 'dependency_scanning',
                    'vulnerability_attributes' => { 'fix_available' => true },
                    'vulnerability_states' => %w[new_needs_triage new_dismissed]
                  },
                  {
                    'type' => 'container_scanning',
                    'vulnerability_states' => %w[new_needs_triage]
                  }
                ],
                'severity_levels' => %w[critical],
                'vulnerability_states' => %w[new_needs_triage new_dismissed],
                'vulnerabilities_allowed' => 0
              })
            end

            let(:scan_execution_policy) do
              build(:scan_execution_policy, actions: scans.map { |scan| { scan: scan } })
            end

            let(:policy_yaml) do
              build(:orchestration_policy_yaml, scan_execution_policy: [scan_execution_policy])
            end

            before do
              approval_rule_1.update!(approval_policy_rule: atomic_policy_rule_newly_detected)
              sec_policy = atomic_policy_rule_newly_detected.security_policy
              sec_policy.update_column(:content,
                sec_policy.content.deep_stringify_keys.merge(
                  'policy_tuning' => { 'unblock_rules_using_execution_policies' => true }))
              sec_policy.reload
              atomic_policy_rule_newly_detected.reload
              allow_next_instance_of(Repository) do |repository|
                allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
              end
            end

            it 'is excludable and does not create a violation' do
              expect { execute_with_error }.not_to change { violated_policies }.from(be_empty)
            end
          end
        end
      end
    end

    describe '#skip!' do
      it 'adds violations for the skipped rules', :aggregate_failures do
        service.skip!(approval_rule_1)
        execute

        expect(violated_policies).to contain_exactly policy_a
        violation = merge_request.scan_result_policy_violations.first
        expect(violation).to be_skipped
        expect(violation.violation_data).to eq({ 'errors' => ['error' => 'EVALUATION_SKIPPED'] })
      end

      it 'blocks the rule by resetting approvals' do
        approval_rule_1.update!(approvals_required: 0)
        service.skip!(approval_rule_1)

        expect { execute }.to change { approval_rule_1.reload.approvals_required }.from(0).to(1)
      end

      context 'when approval rule has no policy source' do
        it 'does not create violations' do
          approval_project_rule_1.update!(scan_result_policy_read: nil, approval_policy_rule: nil)
          approval_rule_1.update!(scan_result_policy_read: nil, approval_policy_rule: nil)
          service.skip!(approval_rule_1)

          expect { execute }.not_to change { violated_policies }
        end
      end

      context 'when rule should fail open' do
        before do
          update_policy_content(policy_b, fallback_behavior: { fail: 'open' })
          service.skip!(approval_rule_2)
        end

        it 'adds warning violations for the skipped rules' do
          expect { execute }.to change { violated_policies.size }.from(0).to(1)
          violation = merge_request.scan_result_policy_violations.first
          expect(violation).to be_warn
          expect(violation.violation_data).to eq({ 'errors' => ['error' => 'EVALUATION_SKIPPED'] })
        end

        it 'unblocks the rule by removing required approvals' do
          expect { execute }.to change { approval_rule_2.reload.approvals_required }.from(1).to(0)
        end
      end
    end

    describe 'policy bot comment' do
      context 'with failing rules' do
        before do
          service.fail!(approval_rule_1, data: { uuids: { newly_detected: ['123'] } })
          service.pass!(approval_rule_2)
        end

        it_behaves_like 'triggers policy bot comment', true
        it_behaves_like 'does not trigger policy bot comment for archived project' do
          let(:archived_project) { merge_request.project }
        end
      end

      context 'with passing rules' do
        before do
          service.pass!(approval_rule_1)
          service.pass!(approval_rule_2)
        end

        it_behaves_like 'triggers policy bot comment', false
        it_behaves_like 'does not trigger policy bot comment for archived project' do
          let(:archived_project) { merge_request.project }
        end
      end
    end

    context 'when approval rule has no approval_policy_source' do
      let!(:license_rule) do
        create(:report_approver_rule, :license_scanning, merge_request: merge_request,
          approvals_required: 1, scan_result_policy_read: nil, approval_policy_rule: nil)
      end

      it 'save completes without error and leaves the rule unchanged' do
        expect { service.save }.not_to change { license_rule.reload.approvals_required } # rubocop:disable Rails/SaveBang -- PolicyRuleEvaluationService#save is a custom service method, not ActiveRecord
      end

      context 'when the license rule passes the unblock check but resolves to nil source afterwards' do
        let(:approval_policy_source_stub) do
          instance_double(Security::ApprovalPolicySource, unblock_rules_using_execution_policies?: true)
        end

        before do
          call_count = 0
          allow(license_rule).to receive(:approval_policy_source) do
            call_count += 1
            call_count == 1 ? approval_policy_source_stub : nil
          end
        end

        it 'marks the rule as failed after error!' do
          expect(merge_request).to receive(:reset_required_approvals)
            .with(a_collection_including(license_rule)).and_call_original

          service.error!(license_rule, :scan_removed)
          service.save # rubocop:disable Rails/SaveBang -- PolicyRuleEvaluationService#save is a custom service method, not ActiveRecord
        end
      end
    end

    context 'when approval rule is backed by approval_policy_rule' do
      include_context 'with approval rule backed by approval_policy_rule'
      include_context 'with divergent fallback_behavior across approval_policy_source'

      let(:approval_policy_source_read) { policy_a }
      let(:approval_policy_source_rule) { approval_rule_1 }
      let(:approval_policy_rule_trait) { :scan_finding }

      it 'removes the required approvals because approval_policy_rule resolves fail_open' do
        expect(ApprovalMergeRequestRule).to receive(:remove_required_approved)
          .with(a_collection_including(approval_rule_1)).and_call_original

        service.skip!(approval_rule_1.reload)
        service.save # rubocop:disable Rails/SaveBang -- PolicyRuleEvaluationService#save is a custom service method, not ActiveRecord
      end

      context 'when the deprecate_scan_result_policies flag is disabled' do
        include_context 'with deprecate_scan_result_policies flag disabled'

        it 'resets required approvals because scan_result_policy_read resolves fail_closed' do
          expect(merge_request).to receive(:reset_required_approvals)
            .with(a_collection_including(approval_rule_1)).and_call_original

          service.skip!(approval_rule_1.reload)
          service.save # rubocop:disable Rails/SaveBang -- PolicyRuleEvaluationService#save is a custom service method, not ActiveRecord
        end
      end
    end
  end

  describe '#add_violation_detail_data!' do
    let(:violations_service) do
      instance_double(
        Security::SecurityOrchestrationPolicies::UpdateViolationsService,
        add_violation_detail_data: nil,
        violation_detail_data: {}
      )
    end

    before do
      allow(Security::SecurityOrchestrationPolicies::UpdateViolationsService)
        .to receive(:new).with(merge_request).and_return(violations_service)
    end

    it 'delegates to UpdateViolationsService#add_violation_detail_data with the policy source' do
      expect(violations_service).to receive(:add_violation_detail_data)
        .with(approval_rule_1.approval_policy_source, { total_commit_shas_count: 42 })

      service.add_violation_detail_data!(approval_rule_1, total_commit_shas_count: 42)
    end

    context 'when approval_rule has no approval_policy_source' do
      before do
        allow(approval_rule_1).to receive(:approval_policy_source).and_return(nil)
      end

      it 'does nothing' do
        expect(violations_service).not_to receive(:add_violation_detail_data)

        service.add_violation_detail_data!(approval_rule_1, total_commit_shas_count: 10)
      end
    end
  end
  # rubocop:enable RSpec/MultipleMemoizedHelpers
end
