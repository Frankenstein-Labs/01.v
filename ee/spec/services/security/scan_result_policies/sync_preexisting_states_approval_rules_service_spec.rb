# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::SyncPreexistingStatesApprovalRulesService, feature_category: :security_policy_management do
  include RepoHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_reload(:project) { create(:project, :repository) }
  let(:service) { described_class.new(merge_request) }
  let_it_be_with_reload(:merge_request) do
    create(:ee_merge_request, :simple, source_project: project)
  end

  let_it_be_with_reload(:approval_policy_rule) { create(:approval_policy_rule) }
  let_it_be_with_reload(:scan_result_policy_read) do
    create(:scan_result_policy_read, project: project, approval_policy_rule: approval_policy_rule)
  end

  let_it_be_with_reload(:protected_branch) do
    create(:protected_branch, name: merge_request.target_branch, project: project)
  end

  let_it_be(:author) { create(:user) }

  before do
    stub_licensed_features(security_orchestration_policies: true)
  end

  describe '#execute' do
    subject(:execute) { service.execute }

    let(:approvals_required) { 1 }

    let!(:approval_project_rule) do
      create(:approval_project_rule, :scan_finding, project: project, approvals_required: approvals_required,
        scan_result_policy_read: scan_result_policy_read)
    end

    let!(:approver_rule) do
      create(:report_approver_rule, :scan_finding,
        merge_request: merge_request, vulnerability_states: ['detected'],
        approval_project_rule: approval_project_rule, approvals_required: approvals_required)
    end

    shared_examples_for 'does not update approval rules' do
      it 'does not update approval rules' do
        expect { execute }.not_to change { approver_rule.reload.approvals_required }
      end
    end

    shared_examples_for 'sets approvals_required to 0' do
      it 'sets approvals_required to 0' do
        expect { execute }.to change { approver_rule.reload.approvals_required }.to(0)
      end
    end

    shared_examples_for 'does not log violations' do
      it 'does not log violations' do
        expect(Gitlab::AppJsonLogger).not_to receive(:info)

        execute
      end
    end

    shared_examples_for 'logs only evaluation' do
      it 'logs the start of the evaluation' do
        expect(Gitlab::AppJsonLogger).to receive(:info).with(hash_including(
          message: 'Evaluating pre_existing scan_finding rules from approval policies'))

        execute
      end
    end

    context 'when merge_request is merged' do
      before do
        merge_request.update!(state: 'merged')
      end

      it_behaves_like 'does not update approval rules'
      it_behaves_like 'does not trigger policy bot comment'
      it_behaves_like 'does not log violations'
    end

    context 'when approvals are optional' do
      let(:approvals_required) { 0 }

      it_behaves_like 'does not update approval rules'
      it_behaves_like 'triggers policy bot comment', false
      it_behaves_like 'logs only evaluation'
    end

    context 'when rules do not contain pre-existing states' do
      let!(:approver_rule) do
        create(:report_approver_rule, :scan_finding, merge_request: merge_request,
          approval_project_rule: approval_project_rule, approvals_required: approvals_required,
          vulnerability_states: ['new_needs_triage']
        )
      end

      it_behaves_like 'does not update approval rules'
      it_behaves_like 'does not trigger policy bot comment'
      it_behaves_like 'merge request without scan result violations', previous_violation: false
      it_behaves_like 'does not log violations'
    end

    context 'when rules contain pre-existing states' do
      let!(:approver_rule) do
        create(:report_approver_rule, :scan_finding, merge_request: merge_request,
          approval_project_rule: approval_project_rule, approvals_required: approvals_required,
          vulnerability_states: ['detected'],
          scan_result_policy_read: scan_result_policy_read, approval_policy_rule: approval_policy_rule)
      end

      context 'with non-matching vulnerabilities and merge_request targeting non-default branch' do
        let_it_be(:vulnerabilities) do
          create_list(:vulnerability, 5, :with_finding,
            severity: :low,
            report_type: :sast,
            state: :resolved,
            project: project,
            author: author
          )
        end

        let_it_be_with_reload(:merge_request) do
          create(:ee_merge_request, :simple, source_project: project, source_branch: 'feature',
            target_branch: 'target')
        end

        before do
          create(:protected_branch, name: merge_request.target_branch, project: project)
        end

        it_behaves_like 'sets approvals_required to 0'
        it_behaves_like 'triggers policy bot comment', false
        it_behaves_like 'logs only evaluation'
        it_behaves_like 'merge request without scan result violations'
      end

      context 'when vulnerabilities count matches the pre-existing states' do
        let_it_be(:vulnerabilities) do
          create_list(:vulnerability, 5, :with_finding,
            severity: :low,
            report_type: :sast,
            state: :detected,
            project: project,
            author: author
          )
        end

        let(:uuids) { vulnerabilities.map(&:finding_uuid) }

        before do
          config = scan_result_policy_read.security_orchestration_policy_configuration
          policy_rule = create(:approval_policy_rule, :scan_finding,
            security_policy: create(:security_policy, :approval_policy,
              security_orchestration_policy_configuration: config))
          scan_result_policy_read.update!(approval_policy_rule: policy_rule)
          approval_project_rule.update!(approval_policy_rule: policy_rule)
          approver_rule.update!(approval_policy_rule: policy_rule)
        end

        it_behaves_like 'does not update approval rules'
        it_behaves_like 'triggers policy bot comment', true

        it 'logs update' do
          expect(Gitlab::AppJsonLogger).to receive(:info).with(hash_including(
            message: 'Evaluating pre_existing scan_finding rules from approval policies'))
          expect(::Gitlab::AppJsonLogger)
            .to receive(:info).once.ordered
            .with(
              workflow: 'approval_policy_evaluation',
              event: 'update_approvals',
              message: 'Updating MR approval rule with pre_existing states',
              approval_rule_id: approver_rule.id,
              approval_rule_name: approver_rule.name,
              merge_request_id: merge_request.id,
              merge_request_iid: merge_request.iid,
              reason: 'pre_existing scan_finding rule violated',
              project_path: project.full_path
            ).and_call_original

          execute
        end

        it 'persists violation details', :aggregate_failures do
          execute

          violation_data = merge_request.scan_result_policy_violations.last.violation_data
          expect(violation_data)
            .to match({ 'violations' => { 'scan_finding' =>
              { 'uuids' => { 'previously_existing' => array_including(uuids) } } } })
          expect(violation_data.dig('violations', 'scan_finding', 'uuids', 'previously_existing'))
            .to match_array(uuids)
        end
      end

      context 'when vulnerabilities count does not match the pre-existing states' do
        it_behaves_like 'sets approvals_required to 0'
        it_behaves_like 'triggers policy bot comment', false
        it_behaves_like 'logs only evaluation'
        it_behaves_like 'merge request without scan result violations'

        context 'when there are other scan_finding violations' do
          let_it_be_with_reload(:scan_result_policy_read_other_scan_finding) do
            create(:scan_result_policy_read, :with_approval_policy_rule, project: project)
          end

          let_it_be(:approval_project_rule_other) do
            create(:approval_project_rule, :scan_finding, project: project, approvals_required: 1,
              scan_result_policy_read: scan_result_policy_read_other_scan_finding,
              approval_policy_rule: scan_result_policy_read_other_scan_finding.approval_policy_rule)
          end

          let_it_be(:approver_rule_other) do
            create(:report_approver_rule, :scan_finding,
              merge_request: merge_request, vulnerability_states: ['new_needs_triage'],
              approval_project_rule: approval_project_rule_other, approvals_required: 1,
              scan_result_policy_read: scan_result_policy_read_other_scan_finding,
              approval_policy_rule: scan_result_policy_read_other_scan_finding.approval_policy_rule)
          end

          let_it_be_with_reload(:other_violation) do
            create(:scan_result_policy_violation, scan_result_policy_read: scan_result_policy_read_other_scan_finding,
              approval_policy_rule: scan_result_policy_read_other_scan_finding.approval_policy_rule,
              merge_request: merge_request)
          end

          it_behaves_like 'triggers policy bot comment', true

          context 'when there are other running violations' do
            before do
              create(:scan_result_policy_violation, merge_request: merge_request, status: :running)
            end

            it_behaves_like 'does not trigger policy bot comment'
          end
        end
      end

      context 'when the approval rule has vulnerability attributes' do
        context 'when vulnerability_attributes include CVE enrichment filters' do
          before do
            # With deprecate_scan_result_policies enabled, vulnerability_attributes are read from the approval rule.
            approval_policy_rule.update!(content: approval_policy_rule.content.merge(
              'vulnerability_attributes' => {
                'known_exploited' => true,
                'epss_score' => { 'operator' => 'greater_than', 'value' => 0.5 },
                'enrichment_data_unavailable' => { 'action' => 'block' }
              }))
          end

          specify do
            expect(Security::ScanResultPolicies::VulnerabilitiesFinder).to receive(:new).at_least(:once).with(
              anything,
              hash_including(
                fix_available: nil,
                false_positive: nil,
                known_exploited: true,
                epss_score: { operator: 'greater_than', value: 0.5 },
                enrichment_data_unavailable_action: 'block'
              )
            ).and_call_original

            execute
          end
        end

        context 'when vulnerability_attributes include other attributes' do
          before do
            # With deprecate_scan_result_policies enabled, vulnerability_attributes are read from the approval rule.
            approval_policy_rule.update!(content: approval_policy_rule.content.merge(
              'vulnerability_attributes' => { 'fix_available' => false, 'false_positive' => false }))
          end

          specify do
            expect(Security::ScanResultPolicies::VulnerabilitiesFinder).to receive(:new).at_least(:once).with(
              anything,
              hash_including(
                fix_available: false,
                false_positive: false
              )
            ).and_call_original

            execute
          end
        end
      end

      context 'with atomic scanner rule criteria' do
        let_it_be(:atomic_policy_rule) do
          create(:approval_policy_rule, :scan_finding, content: {
            'type' => 'scan_finding',
            'branches' => [],
            'scanners' => [
              { 'type' => 'dependency_scanning', 'severity_levels' => %w[high] }
            ],
            'severity_levels' => %w[high],
            'vulnerability_states' => %w[detected],
            'vulnerabilities_allowed' => 0
          })
        end

        before do
          approver_rule.update!(approval_policy_rule: atomic_policy_rule)
        end

        it 'uses GroupedVulnerabilitiesEvaluator for evaluation' do
          expect(Security::ScanResultPolicies::GroupedVulnerabilitiesEvaluator).to receive(:new).and_call_original

          execute
        end

        context 'when grouped findings violate the policy' do
          let_it_be(:vulnerabilities) do
            create_list(:vulnerability, 3, :with_finding,
              severity: :high,
              report_type: :dependency_scanning,
              state: :detected,
              project: project,
              author: author
            )
          end

          it 'does not update approvals_required' do
            expect { execute }.not_to change { approver_rule.reload.approvals_required }
          end

          it 'persists violation details with vulnerability UUIDs' do
            execute

            violation = merge_request.scan_result_policy_violations.last
            expect(violation.violation_data).to include('violations')
          end
        end

        context 'when grouped findings do not violate the policy' do
          let_it_be(:atomic_policy_rule_high_allowed) do
            create(:approval_policy_rule, :scan_finding, content: {
              'type' => 'scan_finding',
              'branches' => [],
              'scanners' => [
                { 'type' => 'dependency_scanning', 'severity_levels' => %w[high] }
              ],
              'severity_levels' => %w[high],
              'vulnerability_states' => %w[detected],
              'vulnerabilities_allowed' => 100
            })
          end

          before do
            approver_rule.update!(approval_policy_rule: atomic_policy_rule_high_allowed)
          end

          it 'sets approvals_required to 0' do
            expect { execute }.to change { approver_rule.reload.approvals_required }.to(0)
          end
        end

        context 'when only some scanner groups violate the policy' do
          let_it_be(:atomic_policy_rule_multi_scanner) do
            create(:approval_policy_rule, :scan_finding, content: {
              'type' => 'scan_finding',
              'branches' => [],
              'scanners' => [
                { 'type' => 'dependency_scanning', 'severity_levels' => %w[high], 'vulnerabilities_allowed' => 0 },
                { 'type' => 'sast', 'severity_levels' => %w[high], 'vulnerabilities_allowed' => 10 }
              ],
              'severity_levels' => %w[high],
              'vulnerability_states' => %w[detected],
              'vulnerabilities_allowed' => 0
            })
          end

          let_it_be(:violating_vulnerabilities) do
            create_list(:vulnerability, 3, :with_finding,
              severity: :high,
              report_type: :dependency_scanning,
              state: :detected,
              project: project,
              author: author
            )
          end

          let_it_be(:non_violating_vulnerabilities) do
            create_list(:vulnerability, 2, :with_finding,
              severity: :high,
              report_type: :sast,
              state: :detected,
              project: project,
              author: author
            )
          end

          before do
            approver_rule.update!(approval_policy_rule: atomic_policy_rule_multi_scanner)

            violating_group = Security::ScanResultPolicies::GroupedVulnerabilitiesEvaluator::GroupResult.new(
              vulnerabilities: project.vulnerabilities.where(id: violating_vulnerabilities.map(&:id)),
              vulnerabilities_allowed: 0,
              vulnerability_states: %w[detected]
            )
            non_violating_group = Security::ScanResultPolicies::GroupedVulnerabilitiesEvaluator::GroupResult.new(
              vulnerabilities: project.vulnerabilities.where(id: non_violating_vulnerabilities.map(&:id)),
              vulnerabilities_allowed: 10,
              vulnerability_states: %w[detected]
            )

            allow_next_instance_of(Security::ScanResultPolicies::GroupedVulnerabilitiesEvaluator) do |evaluator|
              allow(evaluator).to receive(:grouped_results).and_return([violating_group, non_violating_group])
            end
          end

          it 'only includes vulnerabilities from the violating scanner group' do
            execute

            violation = merge_request.scan_result_policy_violations.last
            violation_uuids = violation.violation_data.dig('violations', 'scan_finding', 'uuids',
              'previously_existing')
            violating_uuids = violating_vulnerabilities.map(&:finding_uuid)
            non_violating_uuids = non_violating_vulnerabilities.map(&:finding_uuid)

            expect(violation_uuids).to match_array(violating_uuids)
            expect(violation_uuids).not_to include(*non_violating_uuids)
          end
        end

        context 'when grouped results are blank' do
          before do
            allow_next_instance_of(Security::ScanResultPolicies::GroupedVulnerabilitiesEvaluator) do |evaluator|
              allow(evaluator).to receive(:grouped_results).and_return([])
            end
          end

          it 'does not violate and sets approvals_required to 0' do
            expect { execute }.to change { approver_rule.reload.approvals_required }.to(0)
          end
        end

        context 'when approver rule has no scan_result_policy_read' do
          before do
            approver_rule.update!(scan_result_policy_read: nil)
          end

          it 'does not raise an error' do
            expect { execute }.not_to raise_error
          end
        end
      end
    end

    context 'when approval rule has no approval_policy_source' do
      before do
        approver_rule.update!(scan_result_policy_read: nil, approval_policy_rule: nil)
      end

      it 'evaluates without error' do
        expect { execute }.not_to raise_error
      end

      context 'and the rule reports grouped scanner_configurations' do
        before do
          allow_next_found_instance_of(ApprovalMergeRequestRule) do |found_rule|
            allow(found_rule).to receive_messages(
              scanner_configurations: [{ scanner: 'dependency_scanning' }],
              approval_policy_source: nil
            )
          end
        end

        it 'evaluates grouped_vulnerabilities without error' do
          expect { execute }.not_to raise_error
        end
      end
    end

    context 'when approval rule is backed by approval_policy_rule' do
      include_context 'with approval rule backed by approval_policy_rule'
      include_context 'with divergent vulnerability_age across approval_policy_source'

      let(:approval_policy_source_read) { scan_result_policy_read }
      let(:approval_policy_source_rule) { approver_rule }

      before do
        approver_rule.update!(scan_result_policy_read: scan_result_policy_read)
      end

      it 'queries vulnerabilities using vulnerability_age from approval_policy_rule content' do
        expect(Security::ScanResultPolicies::VulnerabilitiesFinder)
          .to receive(:new)
          .with(project, hash_including(vulnerability_age: { operator: :greater_than, interval: :day, value: 10 }))
          .at_least(:once).and_call_original

        execute
      end
    end
  end
end
