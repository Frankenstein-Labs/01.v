# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::ApprovalRules::CreateService, feature_category: :security_policy_management do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:security_orchestration_policy_configuration) do
    create(:security_orchestration_policy_configuration, project: project)
  end

  let_it_be(:author) { create(:user) }

  let_it_be_with_reload(:security_policy) do
    create(:security_policy,
      security_orchestration_policy_configuration: security_orchestration_policy_configuration,
      content: {
        actions: [
          {
            type: 'require_approval',
            approvals_required: 1,
            user_approvers: ['admin']
          }
        ]
      }
    )
  end

  let_it_be_with_reload(:approval_policy_rule) { create(:approval_policy_rule, security_policy: security_policy) }
  let_it_be_with_reload(:approval_policy_rules) { [approval_policy_rule] }

  let(:service) do
    described_class.new(
      project: project,
      security_policy: security_policy,
      approval_policy_rules: approval_policy_rules,
      author: author
    )
  end

  subject(:execute_service) do
    service.execute
  end

  before do
    service.clear_memoization(:approval_actions)
    security_policy.clear_memoization(:policy_content)
  end

  describe '#execute' do
    context 'when there are no approval actions' do
      before do
        security_policy.update!(content: { actions: [] })
      end

      it 'creates scan result policy read and approval rule' do
        expect { execute_service }
          .to change { project.scan_result_policy_reads.count }.by(1)
          .and change { project.approval_rules.count }.by(1)
      end

      context 'when rule type is any_merge_request' do
        before do
          approval_policy_rule.update!(
            type: Security::ApprovalPolicyRule.types[:any_merge_request],
            content: {
              type: 'any_merge_request',
              branches: [],
              commits: 'any'
            }
          )
        end

        it 'does not create approval rule' do
          expect { execute_service }.not_to change { project.approval_rules.count }
        end
      end
    end

    context 'when there are approval actions' do
      it 'creates scan result policy read and approval rule' do
        expect { execute_service }.to change { project.scan_result_policy_reads.count }.by(1)
          .and change { project.approval_rules.count }.by(1)
      end

      it 'tracks approval rule creation event', :clean_gitlab_redis_shared_state do
        expect { execute_service }
          .to trigger_internal_events('create_approval_rule_from_merge_request_approval_policy')
          .with(project: project, additional_properties: {
            label: approval_policy_rule.type,
            enforcement_type: 'enforce'
          })
          .and increment_usage_metrics(
            'redis_hll_counters.count_distinct_namespace_id_from_applied_enforce_merge_request_approval_policies_monthly', # rubocop disable Layout/LineLength
            'redis_hll_counters.count_distinct_project_id_from_applied_enforce_merge_request_approval_policies_monthly'
          )
      end

      context 'when policy is in warn mode', :clean_gitlab_redis_shared_state do
        before do
          allow(security_policy).to receive(:enforcement_type).and_return('warn')
        end

        it 'tracks approval rule creation with warn enforcement_type' do
          expect { execute_service }
            .to trigger_internal_events('create_approval_rule_from_merge_request_approval_policy')
            .with(project: project, additional_properties: {
              label: approval_policy_rule.type,
              enforcement_type: 'warn'
            })
            .and increment_usage_metrics(
              'redis_hll_counters.count_distinct_namespace_id_from_applied_warn_merge_request_approval_policies_monthly', # rubocop disable Layout/LineLength
              'redis_hll_counters.count_distinct_project_id_from_applied_warn_merge_request_approval_policies_monthly'
            )
        end
      end

      context 'with multiple approval actions' do
        before do
          security_policy.update!(content: {
            actions: [
              { type: 'require_approval', approvals_required: 1, user_approvers: ['admin'] },
              { type: 'require_approval', approvals_required: 2, user_approvers: ['owner'] }
            ]
          })
        end

        it 'tracks multiple approval actions event' do
          expect { execute_service }
            .to trigger_internal_events('check_multiple_approval_actions_for_approval_policy')
            .with(project: project)
            .and increment_usage_metrics(
              "redis_hll_counters." \
                "count_distinct_project_id_from_check_multiple_approval_actions_for_approval_policy_monthly"
            )
        end
      end

      context 'when rule type is license_finding' do
        before do
          approval_policy_rule.update!(type: Security::ApprovalPolicyRule.types[:license_finding], content: content)
        end

        shared_examples_for 'creates scan result policy read, software license policies and approval rule' do
          it 'creates scan result policy read, software license policies and approval rule' do
            expect { execute_service }.to change { project.scan_result_policy_reads.count }.by(1)
              .and change { project.software_license_policies.count }.by(1)
              .and change { project.approval_rules.count }.by(1)
          end
        end

        context 'when using the license_types property' do
          let(:content) do
            {
              type: 'license_finding',
              match_on_inclusion_license: true,
              branches: [],
              license_states: ['newly_detected'],
              license_types: ['MIT']
            }
          end

          it_behaves_like 'creates scan result policy read, software license policies and approval rule'
        end

        context 'when using the licenses property' do
          let(:content) do
            {
              type: 'license_finding',
              match_on_inclusion_license: true,
              branches: [],
              license_states: ['newly_detected'],
              licenses: licenses
            }
          end

          context 'when using the denied property' do
            let(:licenses) { { denied: [{ name: 'MIT' }] } }

            it_behaves_like 'creates scan result policy read, software license policies and approval rule'
          end

          context 'when using the allowed property' do
            let(:licenses) { { allowed: [{ name: 'MIT' }] } }

            it_behaves_like 'creates scan result policy read, software license policies and approval rule'
          end
        end
      end
    end

    context 'when policy uses wildcard branch patterns with wildcard protected branches' do
      let(:wildcard_protected_branch) do
        create(:protected_branch, project: project, name: 'production-*')
      end

      let(:wildcard_approval_policy_rule) do
        create(:approval_policy_rule, security_policy: security_policy, content: policy_content)
      end

      let(:wildcard_approval_policy_rules) { [wildcard_approval_policy_rule] }

      let(:wildcard_service) do
        described_class.new(
          project: project,
          security_policy: security_policy,
          approval_policy_rules: wildcard_approval_policy_rules,
          author: author
        )
      end

      before do
        stub_feature_flags(wildcard_pattern_overlap_for_mrap: project)
        stub_licensed_features(multiple_approval_rules: true)
        allow(project).to receive(:multiple_approval_rules_available?).and_return(true)
        wildcard_protected_branch
        project.all_protected_branches.reset
        wildcard_service.clear_memoization(:approval_actions)
        security_policy.clear_memoization(:policy_content)
      end

      subject(:execute_wildcard_service) { wildcard_service.execute }

      context 'when policy pattern overlaps with protected branch pattern' do
        let(:policy_content) do
          {
            type: 'scan_finding',
            branches: ['prod*'],
            scanners: %w[container_scanning],
            vulnerabilities_allowed: 0,
            severity_levels: %w[critical],
            vulnerability_states: %w[detected]
          }
        end

        it 'creates approval rule linked to the wildcard protected branch' do
          expect { execute_wildcard_service }
            .to change { project.approval_rules.count }.by(1)

          approval_rule = project.approval_rules.last
          expect(approval_rule.protected_branches).to include(wildcard_protected_branch)
        end
      end

      context 'when policy pattern is a subset of protected branch pattern' do
        let(:policy_content) do
          {
            type: 'scan_finding',
            branches: ['production-v1*'],
            scanners: %w[container_scanning],
            vulnerabilities_allowed: 0,
            severity_levels: %w[critical],
            vulnerability_states: %w[detected]
          }
        end

        it 'creates approval rule linked to the wildcard protected branch' do
          expect { execute_wildcard_service }
            .to change { project.approval_rules.count }.by(1)

          approval_rule = project.approval_rules.last
          expect(approval_rule.protected_branches).to include(wildcard_protected_branch)
        end
      end

      context 'when policy pattern does not overlap with protected branch pattern' do
        let(:policy_content) do
          {
            type: 'scan_finding',
            branches: ['release/*'],
            scanners: %w[container_scanning],
            vulnerabilities_allowed: 0,
            severity_levels: %w[critical],
            vulnerability_states: %w[detected]
          }
        end

        it 'creates approval rule not linked to the wildcard protected branch' do
          expect { execute_wildcard_service }
            .to change { project.approval_rules.count }.by(1)

          approval_rule = project.approval_rules.last
          expect(approval_rule.protected_branches).not_to include(wildcard_protected_branch)
        end
      end

      context 'when wildcard_pattern_overlap_for_mrap feature flag is disabled' do
        let(:policy_content) do
          {
            type: 'scan_finding',
            branches: ['prod*'],
            scanners: %w[container_scanning],
            vulnerabilities_allowed: 0,
            severity_levels: %w[critical],
            vulnerability_states: %w[detected]
          }
        end

        before do
          stub_feature_flags(wildcard_pattern_overlap_for_mrap: false)
        end

        it 'creates approval rule not linked to the wildcard protected branch' do
          expect { execute_wildcard_service }
            .to change { project.approval_rules.count }.by(1)

          approval_rule = project.approval_rules.last
          expect(approval_rule.protected_branches).not_to include(wildcard_protected_branch)
        end
      end

      context 'when policy uses branch_type instead of branches' do
        let(:policy_content) do
          {
            type: 'scan_finding',
            branch_type: 'protected',
            scanners: %w[container_scanning],
            vulnerabilities_allowed: 0,
            severity_levels: %w[critical],
            vulnerability_states: %w[detected]
          }
        end

        it 'creates approval rule with applies_to_all_protected_branches and no pattern overlap matching' do
          expect { execute_wildcard_service }
            .to change { project.approval_rules.count }.by(1)

          approval_rule = project.approval_rules.last
          expect(approval_rule.applies_to_all_protected_branches).to be true
        end
      end
    end

    context 'when multiple approval policy rules exist' do
      let_it_be(:another_approval_policy_rule) do
        create(:approval_policy_rule, security_policy: security_policy)
      end

      let_it_be(:approval_policy_rules) { [approval_policy_rule, another_approval_policy_rule] }

      it 'creates rules and scan result policy reads for each policy' do
        expect { execute_service }
          .to change { project.approval_rules.count }.by(2)
          .and change { project.scan_result_policy_reads.count }.by(2)
      end
    end

    context 'when approval rule already exists' do
      let_it_be(:existing_approval_rule) do
        create(:approval_project_rule, project: project, approval_policy_rule: approval_policy_rule,
          approval_policy_action_idx: 0)
      end

      it 'does not create duplicate approval rule' do
        expect { execute_service }
          .to not_change { project.scan_result_policy_reads.count }
          .and not_change { project.approval_rules.count }
      end
    end

    context 'when scan_result_policy_read was already created' do
      before do
        create(:scan_result_policy_read,
          project: project,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration,
          approval_policy_rule_id: approval_policy_rule.id,
          action_idx: 0
        )
      end

      it 'does not create duplicate scan result policy read or approval rule' do
        expect { execute_service }
          .to not_change { project.scan_result_policy_reads.count }
          .and not_change { project.approval_rules.count }
      end
    end

    context 'when approval rule creation fails' do
      before do
        allow_next_instance_of(::ApprovalRules::CreateService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'failed'))
        end
      end

      it 'logs the error with Gitlab::AppJsonLogger.debug' do
        expect(Gitlab::AppJsonLogger).to receive(:debug).with(hash_including(
          "event" => "approval_rule_creation_failed",
          "project_id" => project.id,
          "project_path" => project.full_path,
          "scan_result_policy_read_id" => an_instance_of(Integer),
          "approval_policy_rule_id" => approval_policy_rule.id,
          "action_index" => 0,
          "errors" => ['failed']
        ))

        execute_service
      end
    end
  end
end
