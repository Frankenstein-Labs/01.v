# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Policy, feature_category: :security_policy_management do
  subject(:policy) { create(:security_policy, :require_approval) }

  describe 'associations' do
    it { is_expected.to belong_to(:security_orchestration_policy_configuration) }
    it { is_expected.to have_many(:approval_policy_rules) }
    it { is_expected.to have_many(:undeleted_approval_policy_rules) }
    it { is_expected.to have_many(:security_policy_project_links) }
    it { is_expected.to have_many(:projects).through(:security_policy_project_links) }
    it { is_expected.to have_one(:security_pipeline_execution_policy_config_link) }
    it { is_expected.to have_many(:security_pipeline_execution_project_schedules) }
    it { is_expected.to have_many(:approval_policy_merge_request_bypass_events) }
    it { is_expected.to have_many(:policy_dismissals) }
    it { is_expected.to have_many(:scan_execution_project_schedules) }
    it { is_expected.to have_many(:scheduled_pipeline_execution_policy_test_runs) }

    it do
      is_expected.to validate_uniqueness_of(:security_orchestration_policy_configuration_id).scoped_to(%i[type
        policy_index])
    end
  end

  describe 'validations' do
    shared_examples 'validates policy content' do
      it { is_expected.to be_valid }

      context 'with invalid content' do
        before do
          policy.content = { foo: "bar" }
        end

        it { is_expected.to be_invalid }
      end
    end

    describe 'content' do
      context 'when policy_type is approval_policy' do
        it_behaves_like 'validates policy content'
      end

      context 'when policy_type is scan_execution_policy' do
        subject(:policy) { create(:security_policy, :scan_execution_policy) }

        it_behaves_like 'validates policy content'
      end

      context 'when policy_type is pipeline_execution_policy' do
        subject(:policy) { create(:security_policy, :pipeline_execution_policy) }

        it_behaves_like 'validates policy content'
      end

      context 'when policy_type is pipeline_execution_schedule_policy' do
        subject(:policy) { create(:security_policy, :pipeline_execution_schedule_policy) }

        it_behaves_like 'validates policy content'
      end

      context 'when policy_type is vulnerability_management_policy' do
        subject(:policy) { create(:security_policy, :vulnerability_management_policy) }

        it_behaves_like 'validates policy content'
      end

      context 'when policy_type is dependency_firewall_policy' do
        subject(:policy) { create(:security_policy, :dependency_firewall_policy) }

        context 'when feature flag is enabled' do
          before do
            stub_feature_flags(dependency_firewall_phase1: true)
          end

          it_behaves_like 'validates policy content'
        end

        context 'when feature flag is disabled' do
          subject(:policy) { build(:security_policy, :dependency_firewall_policy) }

          before do
            stub_feature_flags(dependency_firewall_phase1: false)
          end

          it { is_expected.to be_invalid }
        end
      end
    end

    describe 'scope' do
      it { is_expected.to be_valid }

      context 'with empty scope' do
        before do
          policy.scope = {}
        end

        it { is_expected.to be_valid }
      end

      context 'with invalid scope' do
        before do
          policy.scope = { compliance_frameworks: "bar" }
        end

        it { is_expected.to be_invalid }
      end
    end

    describe 'description' do
      context 'when description is greater than the limit' do
        before do
          policy.description = 'a' * (Gitlab::Database::MAX_TEXT_SIZE_LIMIT + 1)
        end

        it { is_expected.to be_invalid }
      end

      context 'when description is less than the limit' do
        it { is_expected.to be_valid }
      end
    end
  end

  describe '.for_rule_schedule' do
    let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration) }
    let_it_be(:matching_policy) do
      create(:security_policy, :scan_execution_policy,
        security_orchestration_policy_configuration: policy_configuration,
        policy_index: 0)
    end

    let_it_be(:rule_schedule) do
      create(:security_orchestration_policy_rule_schedule,
        security_orchestration_policy_configuration: policy_configuration,
        policy_index: 0)
    end

    let_it_be(:different_index_policy) do
      create(:security_policy, :scan_execution_policy,
        security_orchestration_policy_configuration: policy_configuration,
        policy_index: 1)
    end

    let_it_be(:different_config_policy) do
      create(:security_policy, :scan_execution_policy, policy_index: 0)
    end

    let_it_be(:approval_policy) do
      create(:security_policy, :approval_policy,
        security_orchestration_policy_configuration: policy_configuration,
        policy_index: 0)
    end

    it 'returns only the scan execution policy matching the rule schedule configuration and index' do
      expect(described_class.for_rule_schedule(rule_schedule)).to contain_exactly(matching_policy)
    end
  end

  describe '.undeleted' do
    let_it_be(:policy_with_positive_index) { create(:security_policy, policy_index: 1) }
    let_it_be(:policy_with_zero_index) { create(:security_policy, policy_index: 0) }
    let_it_be(:policy_with_negative_index) { create(:security_policy, policy_index: -1) }

    it 'returns policies with policy_index greater than or equal to 0' do
      result = described_class.undeleted

      expect(result).to contain_exactly(policy_with_positive_index, policy_with_zero_index)
      expect(result).not_to include(policy_with_negative_index)
    end
  end

  describe '.preload_approval_policy_rules' do
    let_it_be(:policy) { create(:security_policy) }
    let_it_be(:active_rule) { create(:approval_policy_rule, security_policy: policy, rule_index: 0) }
    let_it_be(:deleted_rule) { create(:approval_policy_rule, security_policy: policy, rule_index: -1) }

    it 'preloads only undeleted approval policy rules' do
      result = described_class.preload_approval_policy_rules.find(policy.id)

      expect(result.undeleted_approval_policy_rules).to contain_exactly(active_rule)
    end
  end

  describe '.order_by_index' do
    let_it_be(:policy1) { create(:security_policy, policy_index: 2) }
    let_it_be(:policy2) { create(:security_policy, policy_index: 1) }
    let_it_be(:policy3) { create(:security_policy, policy_index: 3) }

    it 'orders policies by policy_index in ascending order' do
      ordered_policies = described_class.order_by_index

      expect(ordered_policies).to match_array([policy2, policy1, policy3])
    end
  end

  describe '.for_policy_configuration' do
    let_it_be(:policy_configuration1) { create(:security_orchestration_policy_configuration) }
    let_it_be(:policy_configuration2) { create(:security_orchestration_policy_configuration) }
    let_it_be(:policy1) { create(:security_policy, security_orchestration_policy_configuration: policy_configuration1) }
    let_it_be(:policy2) { create(:security_policy, security_orchestration_policy_configuration: policy_configuration2) }

    it 'returns policies for given policy configuration' do
      expect(described_class.for_policy_configuration(policy_configuration1)).to contain_exactly(policy1)
    end

    it 'returns policies for multiple policy configurations' do
      expect(described_class.for_policy_configuration([policy_configuration1, policy_configuration2]))
        .to contain_exactly(policy1, policy2)
    end
  end

  describe '.for_policy_index' do
    let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration) }
    let_it_be(:policy1) do
      create(:security_policy, policy_index: 0, security_orchestration_policy_configuration: policy_configuration)
    end

    let_it_be(:policy2) do
      create(:security_policy, policy_index: 1,
        security_orchestration_policy_configuration: policy_configuration)
    end

    it 'returns policies matching the given policy_index' do
      expect(described_class.for_policy_index(0).for_policy_configuration(policy_configuration))
        .to contain_exactly(policy1)
    end

    it 'returns empty when no policies match the policy_index' do
      expect(described_class.for_policy_index(999)).to be_empty
    end
  end

  describe '.for_policy_configuration_ids' do
    let_it_be(:policy_configuration1) { create(:security_orchestration_policy_configuration) }
    let_it_be(:policy_configuration2) { create(:security_orchestration_policy_configuration) }
    let_it_be(:policy_configuration3) { create(:security_orchestration_policy_configuration) }
    let_it_be(:policy1) { create(:security_policy, security_orchestration_policy_configuration: policy_configuration1) }
    let_it_be(:policy2) { create(:security_policy, security_orchestration_policy_configuration: policy_configuration2) }
    let_it_be(:policy3) { create(:security_policy, security_orchestration_policy_configuration: policy_configuration3) }

    it 'returns policies for given policy configuration ids' do
      expect(described_class.for_policy_configuration_ids([policy_configuration1.id]))
        .to contain_exactly(policy1)
    end

    it 'returns policies for multiple policy configuration ids' do
      expect(described_class.for_policy_configuration_ids([policy_configuration1.id, policy_configuration2.id]))
        .to contain_exactly(policy1, policy2)
    end

    it 'returns empty when no matching configuration ids' do
      expect(described_class.for_policy_configuration_ids([non_existing_record_id])).to be_empty
    end
  end

  describe '.for_projects' do
    let_it_be(:project1) { create(:project) }
    let_it_be(:project2) { create(:project) }
    let_it_be(:project3) { create(:project) }
    let_it_be(:policy1) { create(:security_policy, linked_projects: [project1]) }
    let_it_be(:policy2) { create(:security_policy, linked_projects: [project2]) }
    let_it_be(:policy3) { create(:security_policy, linked_projects: [project1, project2]) }

    it 'returns policies linked to a single project' do
      expect(described_class.for_projects([project1.id]))
        .to contain_exactly(policy1, policy3)
    end

    it 'returns policies linked to multiple projects' do
      expect(described_class.for_projects([project1.id, project2.id]))
        .to contain_exactly(policy1, policy2, policy3)
    end

    it 'returns empty when no matching project ids' do
      expect(described_class.for_projects([non_existing_record_id])).to be_empty
    end

    it 'returns empty when no matching policies for given projects' do
      expect(described_class.for_projects([project3.id]))
        .to be_empty
    end
  end

  describe '.for_configuration_id_and_name_tuples' do
    let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration) }
    let_it_be(:policy_a) do
      create(:security_policy, security_orchestration_policy_configuration: policy_configuration, policy_index: 1)
    end

    let_it_be(:policy_b) do
      create(:security_policy, security_orchestration_policy_configuration: policy_configuration, policy_index: 2)
    end

    subject(:for_configuration_id_and_name_tuples) { described_class.for_configuration_id_and_name_tuples(tuples) }

    context "with tuples" do
      let(:tuples) do
        [[policy_configuration.id, policy_a.name],
          [policy_configuration.id, policy_b.name.reverse]]
      end

      it { is_expected.to contain_exactly(policy_a) }
    end

    context "without tuples" do
      let(:tuples) { [] }

      it { is_expected.to be_empty }
    end
  end

  describe '.for_custom_role' do
    let_it_be(:custom_role_id) { 123 }
    let_it_be(:policy_with_role) do
      create(:security_policy, content: {
        actions: [{ type: 'require_approval', approvals_required: 1, role_approvers: [custom_role_id] }]
      })
    end

    let_it_be(:policy_with_different_role) do
      create(:security_policy, content: {
        actions: [{ type: 'require_approval', approvals_required: 1, role_approvers: [456] }]
      })
    end

    let_it_be(:policy_without_role) do
      create(:security_policy, :require_approval)
    end

    it 'returns policies that include the specified custom role' do
      expect(described_class.for_custom_role(custom_role_id)).to contain_exactly(policy_with_role)
    end

    it 'does not return policies without the specified custom role' do
      expect(described_class.for_custom_role(custom_role_id))
        .not_to include(policy_with_different_role, policy_without_role)
    end
  end

  describe '#link_project!' do
    let_it_be(:project) { create(:project) }
    let_it_be(:policy) { create(:security_policy) }
    let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: policy) }

    it 'creates a new link if one does not exist' do
      expect { policy.link_project!(project) }.to change { Security::PolicyProjectLink.count }.by(1)
        .and change { Security::ApprovalPolicyRuleProjectLink.count }.by(1)
    end

    it 'does not create a duplicate link' do
      policy.link_project!(project)

      expect { policy.link_project!(project) }.to not_change { Security::PolicyProjectLink.count }
        .and not_change { Security::ApprovalPolicyRuleProjectLink.count }
    end

    context 'when policy is a pipeline execution schedule policy' do
      let_it_be(:policy) do
        create(
          :security_policy,
          :pipeline_execution_schedule_policy,
          content: {
            content: { include: [{ project: 'compliance-project', file: "compliance-pipeline.yml" }] },
            schedules: [
              { type: "daily", start_time: "00:00", time_window: { value: 4000, distribution: 'random' } }
            ]
          }
        )
      end

      it 'creates a new schedule with the right attributes' do
        # Newly introduced columns will be written by https://gitlab.com/gitlab-org/gitlab/-/merge_requests/180714
        pending "schedule creation not currently in place"

        expect { policy.link_project!(project) }.to change { Security::PolicyProjectLink.count }.by(1)
        .and change { Security::PipelineExecutionProjectSchedule.count }.by(1)

        schedule = policy.security_pipeline_execution_project_schedules.first

        expect(schedule.project).to eq(project)
        expect(schedule.security_policy).to eq(policy)
      end
    end
  end

  describe '#unlink_project!' do
    let_it_be(:project) { create(:project) }
    let_it_be(:policy) { create(:security_policy) }
    let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: policy) }

    context 'when link already exists' do
      before do
        create(:security_policy_project_link, project: project, security_policy: policy)
        create(:approval_policy_rule_project_link, approval_policy_rule: approval_policy_rule, project: project)
      end

      it 'removes the link between the policy and the project' do
        expect { policy.unlink_project!(project) }
          .to change { Security::PolicyProjectLink.count }.by(-1)
          .and change { Security::ApprovalPolicyRuleProjectLink.count }.by(-1)
      end
    end

    it 'does nothing if no link exists' do
      expect { policy.unlink_project!(project) }
        .to not_change { Security::PolicyProjectLink.count }
        .and not_change { Security::ApprovalPolicyRuleProjectLink.count }
    end

    context 'when policy is a pipeline execution schedule policy' do
      let_it_be(:policy) { create(:security_policy, :pipeline_execution_schedule_policy) }

      before do
        create(:security_policy_project_link, project: project, security_policy: policy)
        create(:security_pipeline_execution_project_schedule, project: project, security_policy: policy)
      end

      it 'removes the schedule' do
        expect { policy.unlink_project!(project) }.to change { Security::PolicyProjectLink.count }.by(-1)
        .and change { Security::PipelineExecutionProjectSchedule.count }.by(-1)
      end
    end
  end

  describe '#linked_to_project?' do
    let_it_be(:project) { create(:project) }
    let_it_be(:other_project) { create(:project) }
    let_it_be(:policy) { create(:security_policy) }

    context 'when policy is linked to the project' do
      before do
        create(:security_policy_project_link, project: project, security_policy: policy)
      end

      it 'returns true' do
        expect(policy.linked_to_project?(project)).to be true
      end

      it 'returns false for a different project' do
        expect(policy.linked_to_project?(other_project)).to be false
      end
    end

    context 'when policy is not linked to the project' do
      it 'returns false' do
        expect(policy.linked_to_project?(project)).to be false
      end
    end
  end

  describe '#update_project_approval_policy_rule_links' do
    let_it_be(:project) { create(:project) }
    let_it_be(:policy) { create(:security_policy) }

    let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: policy) }
    let_it_be(:deleted_approval_policy_rule) { create(:approval_policy_rule, security_policy: policy) }

    let(:created_rules) { [approval_policy_rule] }
    let(:deleted_rules) { [deleted_approval_policy_rule] }

    before do
      create(:approval_policy_rule_project_link, approval_policy_rule: deleted_approval_policy_rule, project: project)
    end

    it 'updates links for created and deleted rules' do
      policy.update_project_approval_policy_rule_links(project, created_rules, deleted_rules)

      expect(
        Security::ApprovalPolicyRuleProjectLink.for_project(project).map(&:approval_policy_rule)
      ).to contain_exactly(approval_policy_rule)
    end
  end

  describe '.upsert_policy' do
    shared_examples 'upserts policy' do |policy_type, assoc_name|
      let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration) }
      let(:policies) { policy_configuration.security_policies.where(type: policy_type) }
      let(:policy_index) { 0 }
      let(:upserted_rules) do
        assoc_name ? upserted_policy.association(assoc_name.to_s).load_target : []
      end

      subject(:upsert!) do
        described_class.upsert_policy(policy_type, policies, policy_hash, policy_index, policy_configuration)
      end

      context 'when the policy does not exist' do
        let(:upserted_policy) { policy_configuration.security_policies.last }

        it 'creates a new policy' do
          expect { upsert! }.to change { policies.count }.by(1)
          expect(upserted_policy.name).to eq(policy_hash[:name])
          expect(upserted_rules.count).to be(assoc_name ? 1 : 0)
        end
      end

      context 'with existing policy' do
        let!(:existing_policy) do
          create(:security_policy,
            policy_type,
            security_orchestration_policy_configuration: policy_configuration,
            policy_index: policy_index)
        end

        let(:upserted_policy) { existing_policy.reload }

        it 'updates the policy' do
          expect { upsert! }.not_to change { policies.count }
          expect(upserted_policy).to eq(existing_policy)
          expect(upserted_policy.name).to eq(policy_hash[:name])
          expect(upserted_rules.count).to be(assoc_name ? 1 : 0)
        end

        context 'when existing policy has metadata persisted' do
          let!(:existing_policy) do
            create(:security_policy,
              policy_type,
              security_orchestration_policy_configuration: policy_configuration,
              policy_index: policy_index,
              metadata: { enforced_scans: ['sast'] })
          end

          it 'does not overwrite the metadata' do
            expect { upsert! }.not_to change { existing_policy.reload.metadata }.from('enforced_scans' => ['sast'])
          end
        end
      end

      unless Security::PolicyRule::SUPPORTED_POLICY_TYPES.include?(policy_type.to_sym)
        context 'when upserting with unsupported rules in policy hash' do
          let(:upserted_policy) { policy_configuration.security_policies.last }
          let(:policy_hash) { super().merge(rules: [{ type: 'pipeline', branches: [] }]) }

          it 'creates the policy without policy rules and does not raise' do
            expect { upsert! }.to change { policies.count }.by(1)
            expect(upserted_policy.name).to eq(policy_hash[:name])
            expect(upserted_rules.count).to be_zero
          end
        end
      end
    end

    context "with approval policies" do
      include_examples 'upserts policy', :approval_policy, :approval_policy_rules do
        let(:policy_hash) { build(:approval_policy, name: "foobar") }
      end
    end

    context "with scan execution policies" do
      include_examples 'upserts policy', :scan_execution_policy, :scan_execution_policy_rules do
        let(:policy_hash) { build(:scan_execution_policy, name: "foobar") }
      end
    end

    context "with pipeline execution policies" do
      include_examples 'upserts policy', :pipeline_execution_policy, nil do
        let_it_be_with_reload(:config_project) { create(:project, :empty_repo) }
        let(:policy_hash) do
          build(:pipeline_execution_policy,
            name: "foobar",
            content: { include: [{ project: config_project.full_path, file: 'compliance-pipeline.yml' }] })
        end

        it 'creates a new link to the config project' do
          expect { upsert! }.to change { Security::PipelineExecutionPolicyConfigLink.count }.by(1)
          expect(Security::PipelineExecutionPolicyConfigLink.last.project).to eq config_project
        end
      end
    end

    context "with vulnerability management policies" do
      include_examples 'upserts policy', :vulnerability_management_policy, :vulnerability_management_policy_rules do
        let(:policy_hash) { build(:vulnerability_management_policy, name: "foobar") }
      end
    end
  end

  describe '.delete_by_ids' do
    let_it_be(:policies) { create_list(:security_policy, 3) }

    subject(:delete!) { described_class.delete_by_ids(policies.first(2).pluck(:id)) }

    it 'deletes by ID' do
      expect { delete! }.to change { described_class.all }.to(contain_exactly(policies.last))
    end
  end

  describe '#to_policy_hash' do
    subject(:policy_hash) { policy.to_policy_hash }

    context 'when policy is an approval policy' do
      let_it_be(:policy) { create(:security_policy, :require_approval, :with_policy_scope) }

      let_it_be(:rule_content) do
        {
          type: 'scan_finding',
          branches: [],
          scanners: %w[container_scanning],
          vulnerabilities_allowed: 0,
          severity_levels: %w[critical],
          vulnerability_states: %w[detected]
        }
      end

      before do
        create(:approval_policy_rule, :scan_finding, security_policy: policy, content: rule_content)
      end

      it 'returns the correct hash structure' do
        expect(policy_hash).to eq(
          name: policy.name,
          description: policy.description,
          enabled: true,
          policy_scope: policy.scope.deep_symbolize_keys,
          metadata: {},
          actions: [{ approvals_required: 1, type: "require_approval", user_approvers: ["owner"] }],
          rules: [rule_content]
        )
      end
    end

    context 'when policy is a scan execution policy' do
      let_it_be(:policy) { create(:security_policy, :scan_execution_policy) }

      before do
        create(:scan_execution_policy_rule, :pipeline, security_policy: policy)
      end

      it 'returns the correct hash structure' do
        expect(policy_hash).to eq(
          name: policy.name,
          description: policy.description,
          enabled: true,
          policy_scope: {},
          metadata: {},
          actions: [{ scan: 'secret_detection' }],
          skip_ci: { allowed: true },
          no_pipeline: { allowed: true },
          rules: [{ type: 'pipeline', branches: [] }]
        )
      end
    end

    context 'when policy is a pipeline execution policy' do
      let_it_be(:policy) { create(:security_policy, :pipeline_execution_policy) }

      it 'returns the correct hash structure' do
        expect(policy_hash).to eq(
          name: policy.name,
          description: policy.description,
          enabled: true,
          policy_scope: {},
          metadata: {},
          pipeline_config_strategy: 'inject_ci',
          skip_ci: { allowed: false },
          no_pipeline: { allowed: false },
          variables_override: { allowed: false },
          content: { include: [{ file: "compliance-pipeline.yml", project: "compliance-project" }] }
        )
      end
    end

    context 'when policy is a pipeline execution schedule policy' do
      let_it_be(:policy) { create(:security_policy, :pipeline_execution_schedule_policy) }

      it 'returns the correct hash structure' do
        expect(policy_hash).to eq(
          name: policy.name,
          description: policy.description,
          enabled: true,
          policy_scope: {},
          schedules: [{ start_time: "00:00", time_window: { distribution: "random", value: 4000 }, type: "daily" }],
          metadata: {},
          content: { include: [{ file: "compliance-pipeline.yml", project: "compliance-project" }] }
        )
      end
    end

    context 'when policy is a dependency firewall policy' do
      before do
        stub_feature_flags(dependency_firewall_phase1: true)
      end

      let_it_be(:policy) do
        policy = create(:security_policy, :dependency_firewall_policy)
        Array.wrap(policy.content&.deep_symbolize_keys&.dig(:rules)).each_with_index do |rule_hash, index|
          create(:dependency_firewall_policy_rule,
            security_policy: policy,
            rule_index: index,
            type: Security::DependencyFirewallPolicyRule.types[rule_hash[:type]],
            content: rule_hash.except(:type))
        end

        policy
      end

      it 'returns the correct hash structure' do
        expect(policy_hash).to eq(
          name: policy.name,
          description: policy.description,
          enabled: true,
          enforcement_type: 'enforced',
          policy_scope: {},
          metadata: {},
          bypass_settings: { users: [{ id: 1222 }], access_tokens: [{ id: 222 }] },
          rules: [
            {
              type: "license",
              denied: [{ name: "NIST Software License" }, { name: "NTP License" }],
              exceptions: [{ purl: "pkg:npm/my-internal-lib" }]
            }
          ]
        )
      end
    end
  end

  describe '#rules' do
    let_it_be(:approval_policy) { create(:security_policy, :require_approval) }
    let_it_be(:scan_execution_policy) { create(:security_policy, :scan_execution_policy) }
    let_it_be(:pipeline_execution_policy) { create(:security_policy, :pipeline_execution_policy) }
    let_it_be(:vulnerability_management_policy) { create(:security_policy, :vulnerability_management_policy) }
    let_it_be(:dependency_firewall_policy) { create(:security_policy, :dependency_firewall_policy) }

    let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: approval_policy) }

    let_it_be(:negative_index_ap_rule) do
      create(:approval_policy_rule, security_policy: approval_policy, rule_index: -1)
    end

    let_it_be(:scan_execution_policy_rule) do
      create(:scan_execution_policy_rule, security_policy: scan_execution_policy)
    end

    let_it_be(:vulnerability_management_policy_rule) do
      create(:vulnerability_management_policy_rule, security_policy: vulnerability_management_policy)
    end

    let_it_be(:dependency_firewall_policy_rule) do
      create(:dependency_firewall_policy_rule, security_policy: dependency_firewall_policy)
    end

    let_it_be(:negative_index_se_rule) do
      create(:scan_execution_policy_rule, security_policy: scan_execution_policy, rule_index: -1)
    end

    subject(:rules) { policy.rules }

    context 'when policy is an approval policy' do
      let(:policy) { approval_policy }

      it { is_expected.to contain_exactly(approval_policy_rule) }
    end

    context 'when policy is a scan execution policy' do
      let(:policy) { scan_execution_policy }

      it { is_expected.to contain_exactly(scan_execution_policy_rule) }
    end

    context 'when policy is a pipeline execution policy' do
      let(:policy) { pipeline_execution_policy }

      it { is_expected.to be_empty }
    end

    context 'when policy is a vulnerability management policy' do
      let(:policy) { vulnerability_management_policy }

      it { is_expected.to contain_exactly(vulnerability_management_policy_rule) }
    end

    context 'when policy is a dependency firewall policy' do
      let(:policy) { dependency_firewall_policy }

      it { is_expected.to contain_exactly(dependency_firewall_policy_rule) }
    end
  end

  describe '#rules_hash' do
    let_it_be(:approval_policy) { create(:security_policy, :require_approval) }
    let_it_be(:scan_execution_policy) { create(:security_policy, :scan_execution_policy) }
    let_it_be(:vulnerability_management_policy) { create(:security_policy, :vulnerability_management_policy) }

    subject(:rules_hash) { policy.rules_hash }

    context 'when policy is an approval policy' do
      let(:policy) { approval_policy }
      let_it_be(:rule_content) do
        {
          type: 'scan_finding',
          branches: [],
          scanners: %w[container_scanning],
          vulnerabilities_allowed: 0,
          severity_levels: %w[critical],
          vulnerability_states: %w[detected]
        }
      end

      before do
        create(:approval_policy_rule, :scan_finding, security_policy: policy, content: rule_content)
      end

      it 'returns array of rule hashes with symbolized keys' do
        expect(rules_hash).to eq([rule_content])
      end
    end

    context 'when policy is a scan execution policy' do
      let(:policy) { scan_execution_policy }

      before do
        create(:scan_execution_policy_rule, :pipeline, security_policy: policy)
      end

      it 'returns array of rule hashes with symbolized keys' do
        expect(rules_hash).to match_array([{ type: 'pipeline', branches: [] }])
      end
    end

    context 'when policy is a vulnerability management policy' do
      let(:policy) { vulnerability_management_policy }

      before do
        create(:vulnerability_management_policy_rule, security_policy: policy)
      end

      it 'returns array of rule hashes with symbolized keys' do
        expect(rules_hash).to eq([
          { type: 'no_longer_detected', severity_levels: %w[low], scanners: %w[sast] }
        ])
      end
    end

    context 'when policy has no rules' do
      let(:policy) { create(:security_policy, :pipeline_execution_policy) }

      it 'returns empty array' do
        expect(rules_hash).to eq([])
      end
    end

    context 'when policy has multiple rules' do
      let(:policy) { create(:security_policy, :scan_execution_policy) }

      before do
        create(:scan_execution_policy_rule, :pipeline, security_policy: policy, rule_index: 0)
        create(:scan_execution_policy_rule, :schedule, security_policy: policy, rule_index: 1)
      end

      it 'returns all rules as hashes' do
        expect(rules_hash).to match_array([
          { type: 'pipeline', branches: [] },
          { type: 'schedule', cadence: '0 * * * *', branches: [] }
        ])
      end
    end
  end

  describe '#approval_policy' do
    context 'when policy is an approval policy' do
      let_it_be(:approval_policy) { create(:security_policy, :approval_policy, name: 'Test Approval Policy') }

      it 'returns an ApprovalPolicy instance' do
        expect(approval_policy.approval_policy).to be_a(Security::ScanResultPolicies::ApprovalPolicy)
        expect(approval_policy.approval_policy.name).to eq('Test Approval Policy')
      end
    end

    context 'when policy is not an approval policy' do
      let_it_be(:scan_execution_policy) { create(:security_policy, :scan_execution_policy) }

      it 'returns nil' do
        expect(scan_execution_policy.approval_policy).to be_nil
      end
    end
  end

  describe '#scan_execution_policy' do
    context 'when policy is a scan execution policy' do
      let_it_be(:scan_execution_policy) do
        create(:security_policy, :scan_execution_policy, name: 'Test Scan Execution Policy')
      end

      it 'returns a ScanExecutionPolicy instance' do
        expect(scan_execution_policy.scan_execution_policy).to be_a(
          Security::ScanExecutionPolicies::ScanExecutionPolicy
        )
        expect(scan_execution_policy.scan_execution_policy.name).to eq('Test Scan Execution Policy')
      end
    end

    context 'when policy is not a scan execution policy' do
      let_it_be(:approval_policy) { create(:security_policy, :approval_policy) }

      it 'returns nil' do
        expect(approval_policy.scan_execution_policy).to be_nil
      end
    end
  end

  describe '#pipeline_execution_policy' do
    context 'when policy is a pipeline execution policy' do
      let_it_be(:pipeline_execution_policy) do
        create(:security_policy, :pipeline_execution_policy, name: 'Test Pipeline Execution Policy')
      end

      it 'returns a PipelineExecutionPolicy instance' do
        expect(pipeline_execution_policy.pipeline_execution_policy).to be_a(
          Security::PipelineExecutionPolicies::PipelineExecutionPolicy
        )
      end
    end

    context 'when policy is not a pipeline execution policy' do
      let_it_be(:approval_policy) { create(:security_policy, :approval_policy) }

      it 'returns nil' do
        expect(approval_policy.pipeline_execution_policy).to be_nil
      end
    end
  end

  describe '#vulnerability_management_policy' do
    context 'when policy is a vulnerability management policy' do
      let_it_be(:vulnerability_management_policy) { create(:security_policy, :vulnerability_management_policy) }

      it 'returns a VulnerabilityManagementPolicy instance' do
        expect(vulnerability_management_policy.vulnerability_management_policy).to be_a(
          Security::VulnerabilityManagementPolicies::VulnerabilityManagementPolicy
        )
      end
    end

    context 'when policy is not a vulnerability management policy' do
      let_it_be(:approval_policy) { create(:security_policy, :approval_policy) }

      it 'returns nil' do
        expect(approval_policy.vulnerability_management_policy).to be_nil
      end
    end
  end

  describe '#pipeline_execution_schedule_policy' do
    context 'when policy is a pipeline execution schedule policy' do
      let_it_be(:pipeline_execution_schedule_policy) do
        create(:security_policy, :pipeline_execution_schedule_policy, name: 'Test Pipeline Execution Schedule Policy')
      end

      it 'returns a PipelineExecutionSchedulePolicy instance' do
        expect(pipeline_execution_schedule_policy.pipeline_execution_schedule_policy).to be_a(
          Security::PipelineExecutionSchedulePolicies::PipelineExecutionSchedulePolicy
        )
      end
    end

    context 'when policy is not a pipeline execution schedule policy' do
      let_it_be(:approval_policy) { create(:security_policy, :approval_policy) }

      it 'returns nil' do
        expect(approval_policy.pipeline_execution_schedule_policy).to be_nil
      end
    end
  end

  describe '#dependency_firewall_policy' do
    context 'when policy is a dependency firewall policy' do
      let_it_be(:dependency_firewall_policy) { create(:security_policy, :dependency_firewall_policy) }

      it 'returns a DependencyFirewallPolicy instance' do
        expect(dependency_firewall_policy.dependency_firewall_policy).to be_a(
          Security::DependencyFirewallPolicies::DependencyFirewallPolicy
        )
      end
    end

    context 'when policy is not a dependency firewall policy' do
      let_it_be(:approval_policy) { create(:security_policy, :approval_policy) }

      it 'returns nil' do
        expect(approval_policy.dependency_firewall_policy).to be_nil
      end
    end
  end

  describe '#max_rule_index' do
    let_it_be(:policy) { create(:security_policy) }
    let_it_be(:rule1) { create(:approval_policy_rule, security_policy: policy, rule_index: 0) }
    let_it_be(:rule2) { create(:approval_policy_rule, security_policy: policy, rule_index: -2) }
    let_it_be(:rule3) { create(:approval_policy_rule, security_policy: policy, rule_index: 1) }

    it 'returns the maximum absolute rule index' do
      expect(policy.max_rule_index).to eq(2)
    end

    context 'when all_rules is nil' do
      before do
        allow(policy).to receive(:all_rules).and_return(nil)
      end

      it 'returns zero' do
        expect(policy.max_rule_index).to eq(0)
      end
    end
  end

  describe '#next_rule_index' do
    let_it_be(:policy) { create(:security_policy) }

    context 'when there are no rules' do
      it 'returns 0' do
        expect(policy.next_rule_index).to eq(0)
      end
    end

    context 'when there are existing rules' do
      let_it_be(:rule1) { create(:approval_policy_rule, security_policy: policy, rule_index: 0) }
      let_it_be(:rule2) { create(:approval_policy_rule, security_policy: policy, rule_index: 1) }
      let_it_be(:deleted_rule) { create(:approval_policy_rule, security_policy: policy, rule_index: -1) }

      it 'returns the next available index' do
        expect(policy.next_rule_index).to eq(2)
      end
    end
  end

  describe '#scope_applicable?' do
    let_it_be(:project) { create(:project) }
    let(:policy) { build(:security_policy) }

    let(:policy_scope_checker) { instance_double(Security::SecurityOrchestrationPolicies::PolicyScopeChecker) }

    before do
      allow(Security::SecurityOrchestrationPolicies::PolicyScopeChecker).to receive(:new)
        .with(project: project).and_return(policy_scope_checker)
    end

    subject(:scope_applicable) { policy.scope_applicable?(project) }

    context 'when the policy is applicable to the project' do
      before do
        allow(policy_scope_checker).to receive(:security_policy_applicable?).with(policy).and_return(true)
      end

      it { is_expected.to be true }
    end

    context 'when the policy is not applicable to the project' do
      before do
        allow(policy_scope_checker).to receive(:security_policy_applicable?).with(policy).and_return(false)
      end

      it { is_expected.to be false }
    end
  end

  describe '#scope_applicable? with a group-scoped dependency firewall policy' do
    let_it_be(:group) { create(:group) }
    let_it_be(:included_project) { create(:project, group: group) }
    let_it_be(:excluded_project) { create(:project, group: group) }
    let_it_be(:configuration) do
      create(:security_orchestration_policy_configuration, :namespace, namespace: group)
    end

    let(:policy) do
      create(:security_policy, :dependency_firewall_policy,
        security_orchestration_policy_configuration: configuration,
        scope: {
          groups: { including: [{ id: group.id }] },
          projects: { excluding: [{ id: excluded_project.id }] }
        })
    end

    it 'applies to the group projects except the excluded one', :aggregate_failures do
      expect(policy.scope_applicable?(included_project)).to be(true)
      expect(policy.scope_applicable?(excluded_project)).to be(false)
    end
  end

  describe '#policy_scope' do
    let(:policy_scope_data) { { business_impact: { including: [{ id: 1 }] } } }
    let(:security_policy) { create(:security_policy, scope: policy_scope_data) }

    subject(:policy_scope) { security_policy.policy_scope }

    it 'returns a Security::PolicyScope instance built from scope_hash' do
      expect(policy_scope).to be_a(Security::PolicyScope)
    end

    it 'delegates scope data correctly' do
      expect(policy_scope.references_any_security_attribute?(1)).to be_truthy
      expect(policy_scope.references_any_security_attribute?(999)).to be_falsey
    end
  end

  describe '#scope_has_framework?' do
    let_it_be(:framework) { create(:compliance_framework) }
    let(:policy_scope) { {} }
    let(:security_policy) { create(:security_policy, scope: policy_scope) }

    subject(:scope_has_framework?) { security_policy.scope_has_framework?(framework.id) }

    context 'when scope is empty' do
      it { is_expected.to be_falsey }
    end

    context 'when scope contains framework_id' do
      let(:policy_scope) { { compliance_frameworks: [{ id: framework.id }] } }

      it { is_expected.to be_truthy }
    end

    context 'when scope has a non existing framework_id' do
      let(:policy_scope) { { compliance_frameworks: [{ id: non_existing_record_id }] } }

      it { is_expected.to be_falsey }
    end
  end

  describe '#delete_approval_policy_rules' do
    let_it_be(:policy) { create(:security_policy, :require_approval) }
    let_it_be(:other_policy) { create(:security_policy, :require_approval) }
    let_it_be(:other_policy_rule) { create(:approval_policy_rule, security_policy: other_policy) }

    let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: policy) }
    let_it_be(:approval_project_rule) do
      create(:approval_project_rule,
        security_orchestration_policy_configuration: policy.security_orchestration_policy_configuration,
        approval_policy_rule_id: approval_policy_rule.id
      )
    end

    let_it_be(:approval_merge_request_rule) do
      create(:approval_merge_request_rule,
        security_orchestration_policy_configuration: policy.security_orchestration_policy_configuration,
        approval_policy_rule_id: approval_policy_rule.id
      )
    end

    let_it_be(:violation) { create(:scan_result_policy_violation, approval_policy_rule: approval_policy_rule) }
    let_it_be(:license_policy) { create(:software_license_policy, approval_policy_rule: approval_policy_rule) }

    it 'deletes all associations and approval_policy_rule' do
      expect { policy.delete_approval_policy_rules }.to change { ApprovalProjectRule.count }.by(-1)
        .and change { ApprovalMergeRequestRule.count }.by(-1)
        .and change { Security::ScanResultPolicyViolation.count }.by(-1)
        .and change { SoftwareLicensePolicy.count }.by(-1)
        .and change { Security::ApprovalPolicyRule.count }.by(-1)
    end

    it 'does not delete approval_policy_rules from other policies' do
      expect { policy.delete_approval_policy_rules }.not_to change { other_policy_rule.reload }
    end

    context 'with merged mr rules' do
      let_it_be(:merged_rule, freeze: false) do
        create(:approval_merge_request_rule,
          security_orchestration_policy_configuration: policy.security_orchestration_policy_configuration,
          approval_policy_rule_id: approval_policy_rule.id
        )
      end

      before do
        merged_rule.merge_request.update!(state_id: MergeRequest.available_states[:merged])
      end

      it 'only deletes unmerged ApprovalMergeRequestRules' do
        expect { policy.delete_approval_policy_rules }.to change { ApprovalMergeRequestRule.count }.by(-1)
        expect(ApprovalMergeRequestRule.exists?(merged_rule.id)).to be_truthy
      end
    end
  end

  describe '#delete_scan_execution_policy_rules' do
    let_it_be(:policy) { create(:security_policy, :scan_execution_policy) }
    let_it_be(:other_policy) { create(:security_policy, :scan_execution_policy) }
    let_it_be(:other_policy_rule) { create(:scan_execution_policy_rule, security_policy: other_policy) }

    before do
      create_list(:scan_execution_policy_rule, 3, security_policy: policy)
    end

    it 'deletes all associated ScanExecutionPolicyRule' do
      expect { policy.delete_scan_execution_policy_rules }.to change { Security::ScanExecutionPolicyRule.count }.by(-3)
    end

    it 'does not delete ScanExecutionPolicyRule from other policies' do
      expect { policy.delete_scan_execution_policy_rules }.not_to change { other_policy_rule.reload }
    end
  end

  describe '#delete_security_pipeline_execution_project_schedules' do
    let_it_be(:policy) { create(:security_policy, :pipeline_execution_schedule_policy) }
    let_it_be(:other_policy) { create(:security_policy, :pipeline_execution_schedule_policy) }
    let_it_be(:other_schedule) { create(:security_pipeline_execution_project_schedule, security_policy: other_policy) }

    before do
      create_list(:security_pipeline_execution_project_schedule, 3, security_policy: policy)
    end

    it 'deletes all associated PipelineExecutionProjectSchedule' do
      expect { policy.delete_security_pipeline_execution_project_schedules }.to change {
        Security::PipelineExecutionProjectSchedule.count
      }.by(-3)
    end

    it 'does not delete PipelineExecutionProjectSchedule from other policies' do
      expect { policy.delete_security_pipeline_execution_project_schedules }.not_to change { other_schedule.reload }
    end
  end

  describe '#delete_approval_policy_rules_for_project' do
    let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration) }
    let_it_be(:policy) do
      create(:security_policy, :approval_policy, security_orchestration_policy_configuration: policy_configuration)
    end

    let_it_be(:project) { create(:project) }
    let_it_be(:merge_request) { create(:merge_request, source_project: project) }
    let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: policy) }
    let_it_be(:other_approval_policy_rule) { create(:approval_policy_rule) }

    let_it_be(:rules, freeze: false) { policy.approval_policy_rules }

    let_it_be(:approval_project_rule) do
      create(:approval_project_rule,
        project: project,
        security_orchestration_policy_configuration: policy_configuration,
        approval_policy_rule: approval_policy_rule
      )
    end

    let_it_be(:merge_request_rule) do
      create(:approval_merge_request_rule,
        approval_project_rule: approval_project_rule,
        merge_request: merge_request,
        security_orchestration_policy_configuration: policy_configuration,
        approval_policy_rule: approval_policy_rule
      )
    end

    let_it_be(:violation) do
      create(:scan_result_policy_violation,
        project: project,
        approval_policy_rule: approval_policy_rule)
    end

    let_it_be(:license_policy) do
      create(:software_license_policy,
        project: project,
        approval_policy_rule: approval_policy_rule
      )
    end

    let_it_be(:other_approval_project_rule) do
      create(:approval_project_rule,
        project: project,
        security_orchestration_policy_configuration: policy_configuration,
        approval_policy_rule: other_approval_policy_rule
      )
    end

    let_it_be(:other_merge_request_rule) do
      create(:approval_merge_request_rule,
        approval_project_rule: approval_project_rule,
        merge_request: merge_request,
        security_orchestration_policy_configuration: policy_configuration,
        approval_policy_rule: other_approval_policy_rule
      )
    end

    let_it_be(:other_violation) do
      create(:scan_result_policy_violation,
        project: project,
        approval_policy_rule: other_approval_policy_rule)
    end

    let_it_be(:other_license_policy) do
      create(:software_license_policy,
        project: project,
        approval_policy_rule: other_approval_policy_rule
      )
    end

    it 'removes all associated records' do
      expect do
        policy.delete_approval_policy_rules_for_project(project, rules)
      end.to change { ApprovalProjectRule.count }.by(-1)
        .and change { ApprovalMergeRequestRule.count }.by(-1)
        .and change { SoftwareLicensePolicy.count }.by(-1)
        .and change { Security::ScanResultPolicyViolation.count }.by(-1)
    end

    it 'does not delete records from other approval policy rules' do
      policy.delete_approval_policy_rules_for_project(project, rules)

      expect(project.approval_rules).to include(other_approval_project_rule)
      expect(project.approval_merge_request_rules).to include(other_merge_request_rule)
      expect(project.software_license_policies).to include(other_license_policy)
      expect(project.scan_result_policy_violations).to include(other_violation)
    end
  end

  describe '#delete_scan_result_policy_reads_for_project' do
    let_it_be(:project) { create(:project) }
    let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
    let_it_be(:policy) { create(:security_policy, security_orchestration_policy_configuration: policy_configuration) }
    let_it_be(:approval_policy_rules) { create_list(:approval_policy_rule, 3, security_policy: policy) }

    let_it_be(:other_policy) { create(:security_policy, :approval_policy) }
    let_it_be(:other_policy_rules) { create_list(:approval_policy_rule, 3, security_policy: other_policy) }

    let_it_be(:rules) { approval_policy_rules.first(2) }

    before do
      approval_policy_rules.each do |rule|
        create(:scan_result_policy_read,
          project: project,
          security_orchestration_policy_configuration: policy_configuration,
          approval_policy_rule: rule)
      end
      other_policy_rules.each do |rule|
        create(:scan_result_policy_read,
          project: project,
          security_orchestration_policy_configuration: other_policy.security_orchestration_policy_configuration,
          approval_policy_rule: rule)
      end
    end

    subject(:delete_scan_result_policy_reads_for_project) do
      policy.delete_scan_result_policy_reads_for_project(project, rules)
    end

    it 'deletes only the scan result policy reads for the given rules' do
      expect do
        delete_scan_result_policy_reads_for_project
      end.to change { project.scan_result_policy_reads.count }.by(-2)

      expect(project.scan_result_policy_reads.where(approval_policy_rule: approval_policy_rules).count).to eq(1)
      expect(project.scan_result_policy_reads.where(approval_policy_rule: other_policy_rules).count).to eq(3)
    end
  end

  describe '#edit_path' do
    subject(:edit_path) { policy.edit_path }

    let_it_be(:project_configuration) { create(:security_orchestration_policy_configuration) }
    let_it_be(:namespace_configuration) { create(:security_orchestration_policy_configuration, :namespace) }

    context 'when name is nil' do
      let(:policy) { build(:security_policy, name: nil) }

      it { is_expected.to be_nil }
    end

    shared_examples_for 'a valid url for policy type' do |type|
      context 'when it belongs to project configuration' do
        let(:configuration) { project_configuration }

        it 'returns a valid url' do
          expect(edit_path).to eq(
            Gitlab::Routing.url_helpers.edit_project_security_policy_url(
              project_configuration.project, id: CGI.escape('Policy'), type: type
            )
          )
        end
      end

      context 'when it belongs to namespace configuration' do
        let(:configuration) { namespace_configuration }

        it 'returns a valid url' do
          expect(edit_path).to eq(
            Gitlab::Routing.url_helpers.edit_group_security_policy_url(
              namespace_configuration.namespace, id: CGI.escape('Policy'), type: type
            )
          )
        end
      end
    end

    context 'when type is approval_policy' do
      let(:policy) do
        build(:security_policy, name: 'Policy', security_orchestration_policy_configuration: configuration)
      end

      it_behaves_like 'a valid url for policy type', 'approval_policy'
    end

    context 'when type is scan_execution_policy' do
      let(:policy) do
        build(:security_policy, :scan_execution_policy, name: 'Policy',
          security_orchestration_policy_configuration: configuration)
      end

      it_behaves_like 'a valid url for policy type', 'scan_execution_policy'
    end

    context 'when type is pipeline_execution_policy' do
      let(:policy) do
        build(:security_policy, :pipeline_execution_policy, name: 'Policy',
          security_orchestration_policy_configuration: configuration)
      end

      it_behaves_like 'a valid url for policy type', 'pipeline_execution_policy'
    end

    context 'when type is vulnerability_management_policy' do
      let(:policy) do
        build(:security_policy, :vulnerability_management_policy, name: 'Policy',
          security_orchestration_policy_configuration: configuration)
      end

      it_behaves_like 'a valid url for policy type', 'vulnerability_management_policy'
    end
  end

  describe '#update_pipeline_execution_policy_config_link!' do
    subject(:update_links) { policy.update_pipeline_execution_policy_config_link! }

    let_it_be_with_reload(:config_project) { create(:project, :empty_repo) }
    let(:policy) do
      create(:security_policy, :pipeline_execution_policy, content: {
        content: { include: [{ project: config_project.full_path, file: 'compliance-pipeline.yml' }] },
        pipeline_config_strategy: 'inject_ci'
      })
    end

    it 'creates a new link if one does not exist' do
      expect { update_links }.to change { Security::PipelineExecutionPolicyConfigLink.count }.by(1)
      expect(policy.reload.security_pipeline_execution_policy_config_link.project).to eq config_project
    end

    it 'does not create a duplicate link' do
      update_links

      expect { policy.update_pipeline_execution_policy_config_link! }
        .not_to change { Security::PipelineExecutionPolicyConfigLink.count }.from(1)
    end

    context 'when policy was previously linked to another project' do
      let_it_be(:other_config_project) { create(:project, :empty_repo) }

      before do
        create(:security_pipeline_execution_policy_config_link, security_policy: policy, project: other_config_project)
      end

      it 'replaces the link' do
        update_links

        expect(policy.reload.security_pipeline_execution_policy_config_link.project).to eq config_project
      end
    end

    context 'when the linked config project does not exist' do
      before do
        config_project.destroy!
      end

      it 'does not create any link' do
        expect { update_links }.not_to change { Security::PipelineExecutionPolicyConfigLink.count }
      end
    end

    %i[approval_policy scan_execution_policy vulnerability_management_policy].each do |type|
      context "when policy is #{type}" do
        let(:policy) { create(:security_policy, type) }

        it { expect  { update_links }.not_to change { Security::PipelineExecutionPolicyConfigLink.count } }
      end
    end
  end

  describe '#pipeline_execution_ci_config' do
    subject(:ci_config) { policy.pipeline_execution_ci_config }

    let(:policy) { build(:security_policy, :pipeline_execution_policy) }

    it 'returns CI config path' do
      expect(ci_config).to eq({ "project" => 'compliance-project', "file" => "compliance-pipeline.yml" })
    end

    context 'when policy does not include a CI config' do
      %i[approval_policy scan_execution_policy vulnerability_management_policy].each do |type|
        context "when policy is #{type}" do
          let(:policy) { build(:security_policy, type) }

          it { is_expected.to be_nil }
        end
      end
    end
  end

  describe '#dismissal_reason' do
    subject(:dismissal_reason) { policy.dismissal_reason }

    let(:policy) do
      build(:security_policy, :vulnerability_management_policy, :auto_dismiss, dismissal_reason: 'used_in_tests')
    end

    it { is_expected.to eq 'used_in_tests' }

    context 'when policy does not have a dismissal_reason' do
      let(:policy) { build(:security_policy, :vulnerability_management_policy, :auto_resolve) }

      it { is_expected.to be_nil }
    end
  end

  describe '#severity_override_operation' do
    subject { policy.severity_override_operation }

    let(:policy) do
      build(:security_policy, :vulnerability_management_policy, :severity_override,
        severity_override_operation: 'set', severity_override_value: 'high')
    end

    it { is_expected.to eq 'set' }

    context 'when policy does not have a severity_override_operation' do
      let(:policy) { build(:security_policy, :vulnerability_management_policy, :auto_resolve) }

      it { is_expected.to be_nil }
    end
  end

  describe '#severity_override_value' do
    subject { policy.severity_override_value }

    let(:policy) do
      build(:security_policy, :vulnerability_management_policy, :severity_override,
        severity_override_operation: 'set', severity_override_value: 'critical')
    end

    it { is_expected.to eq 'critical' }

    context 'when policy does not have a severity_override_value' do
      let(:policy) { build(:security_policy, :vulnerability_management_policy, :auto_resolve) }

      it { is_expected.to be_nil }
    end
  end

  describe '#enforcement_type' do
    let(:policy) { build(:security_policy, content: content) }

    subject(:enforcement_type) { policy.enforcement_type }

    context 'when enforcement_type is defined in the policy content' do
      let(:content) { { enforcement_type: 'warn' } }

      it 'returns the defined enforcement type' do
        expect(enforcement_type).to eq('warn')
      end
    end

    context 'when enforcement_type is not defined in the policy content' do
      let(:content) { { actions: [] } }

      it 'returns the default enforcement type' do
        expect(enforcement_type).to eq(described_class::DEFAULT_ENFORCEMENT_TYPE)
      end
    end
  end

  describe '#enforced_scans' do
    subject(:enforced_scans) { policy.enforced_scans }

    let(:policy) { build(:security_policy, :pipeline_execution_policy, metadata: metadata) }
    let(:metadata) { { enforced_scans: %w[secret_detection] } }

    it { is_expected.to eq %w[secret_detection] }

    context 'when metadata is empty' do
      let(:metadata) { {} }

      it { is_expected.to eq [] }
    end

    context 'when metadata does not contain enforced_scans' do
      let(:metadata) { { other: 'property' } }

      it { is_expected.to eq [] }
    end
  end

  describe '#enforced_scans=' do
    let(:policy) { build(:security_policy, :pipeline_execution_policy, metadata: metadata) }
    let(:metadata) { {} }

    it 'updates metadata' do
      policy.enforced_scans = %w[secret_detection]

      expect(policy.metadata).to eq('enforced_scans' => %w[secret_detection])
    end

    context 'when metadata contains other properties' do
      let(:metadata) { { other: 'property' } }

      it 'updates extends metadata and keeps the other property' do
        policy.enforced_scans = %w[secret_detection]

        expect(policy.metadata).to eq('enforced_scans' => %w[secret_detection], 'other' => 'property')
      end
    end
  end

  describe '#prefill_variables' do
    subject(:prefill_variables) { policy.prefill_variables }

    let(:policy) { build(:security_policy, :pipeline_execution_policy, metadata: metadata) }
    let(:metadata) { { prefill_variables: { 'VAR' => { value: 'value', description: 'description' } } } }

    it { is_expected.to eq('VAR' => { 'value' => 'value', 'description' => 'description' }) }

    context 'when metadata is empty' do
      let(:metadata) { {} }

      it { is_expected.to eq({}) }
    end

    context 'when metadata does not contain prefill_variables' do
      let(:metadata) { { other: 'property' } }

      it { is_expected.to eq({}) }
    end
  end

  describe '#prefill_variables=' do
    let(:policy) { build(:security_policy, :pipeline_execution_policy, metadata: metadata) }
    let(:metadata) { {} }

    it 'updates metadata' do
      policy.prefill_variables = { 'VAR' => { value: 'value', description: 'description' } }

      expect(policy.metadata).to eq(
        'prefill_variables' => { 'VAR' => { value: 'value', description: 'description' } }
      )
    end

    context 'when metadata contains other properties' do
      let(:metadata) { { other: 'property' } }

      it 'updates extends metadata and keeps the other property' do
        policy.prefill_variables = { 'VAR' => { value: 'value', description: 'description' } }

        expect(policy.metadata).to eq(
          'prefill_variables' => { 'VAR' => { value: 'value', description: 'description' } },
          'other' => 'property'
        )
      end
    end
  end

  describe '#framework_ids_from_scope' do
    let_it_be(:policy) { build(:security_policy) }

    subject(:framework_ids) { policy.framework_ids_from_scope }

    context 'when scope is empty' do
      let_it_be(:policy) { build(:security_policy, scope: {}) }

      it { is_expected.to be_empty }
    end

    context 'when scope has compliance frameworks' do
      let_it_be(:policy) do
        build(:security_policy, scope: {
          compliance_frameworks: [
            { id: 1 },
            { id: 2 }
          ]
        })
      end

      it 'returns framework_ids' do
        expect(framework_ids).to contain_exactly(1, 2)
      end
    end

    context 'when scope has duplicatecompliance frameworks' do
      let_it_be(:policy) do
        build(:security_policy, scope: {
          compliance_frameworks: [
            { id: 1 },
            { id: 2 },
            { id: 1 }
          ]
        })
      end

      it 'returns unique framework_ids' do
        expect(framework_ids).to contain_exactly(1, 2)
      end
    end

    context 'when scope has no compliance frameworks' do
      let_it_be(:policy) do
        build(:security_policy, scope: {
          projects: { including: [{ id: 1 }] }
        })
      end

      it { is_expected.to be_empty }
    end
  end

  describe '#upsert_rule' do
    let_it_be(:policy) { create(:security_policy, :approval_policy) }
    let_it_be(:policy_configuration) { policy.security_orchestration_policy_configuration }

    let_it_be(:rule_index) { 0 }
    let_it_be(:rule_hash) do
      {
        type: 'scan_finding',
        branches: [],
        scanners: %w[container_scanning],
        vulnerabilities_allowed: 0,
        severity_levels: %w[critical],
        vulnerability_states: %w[detected]
      }
    end

    subject(:upsert!) { policy.upsert_rule(rule_index, rule_hash) }

    context 'when rule does not exist' do
      before do
        Security::ApprovalPolicyRule.delete_all
      end

      it 'creates a new rule' do
        expect { upsert! }.to change { Security::ApprovalPolicyRule.count }.by(1)
        expect(upsert!).to have_attributes(security_policy_id: policy.id, rule_index: rule_index, type: 'scan_finding')
      end
    end

    context 'when rule exists' do
      it 'updates the existing rule' do
        expect { upsert! }.not_to change { Security::ApprovalPolicyRule.count }
        expect(upsert!).to have_attributes(security_policy_id: policy.id, rule_index: rule_index)
      end
    end
  end

  describe '.next_deletion_index' do
    let_it_be(:policy_with_positive_index) { create(:security_policy, policy_index: 1) }
    let_it_be(:policy_with_zero_index) { create(:security_policy, policy_index: 0) }
    let_it_be(:policy_with_negative_index) { create(:security_policy, policy_index: -1) }

    it 'returns the next available deletion index' do
      expect(described_class.next_deletion_index).to eq(2)
    end

    context 'when there are no policies' do
      before do
        described_class.delete_all
      end

      it 'returns 1' do
        expect(described_class.next_deletion_index).to eq(1)
      end
    end

    context 'when there are only negative indices' do
      let_it_be(:policy_with_negative_index2) { create(:security_policy, policy_index: -2) }
      let_it_be(:policy_with_negative_index3) { create(:security_policy, policy_index: -3) }

      it 'returns the next available positive index' do
        expect(described_class.next_deletion_index).to eq(4)
      end
    end

    context 'when there are only positive indices' do
      let_it_be(:policy_with_positive_index2) { create(:security_policy, policy_index: 2) }
      let_it_be(:policy_with_positive_index3) { create(:security_policy, policy_index: 3) }

      it 'returns the next available index' do
        expect(described_class.next_deletion_index).to eq(4)
      end
    end
  end

  describe '#policy_content' do
    let_it_be(:policy) { create(:security_policy, :require_approval) }

    it 'returns content with symbol keys' do
      expect(policy.policy_content).to eq({
        actions: [{ type: 'require_approval', approvals_required: 1, user_approvers: %w[owner] }]
      })
    end
  end

  describe '.with_bypass_settings' do
    let_it_be(:policy_with_bypass) do
      create(:security_policy, bypass_access_token_ids: [1])
    end

    let_it_be(:policy_without_bypass) do
      create(:security_policy, :require_approval)
    end

    let_it_be(:policy_with_empty_bypass) { create(:security_policy, content: { bypass_settings: {} }) }

    it 'returns only policies with non-empty bypass_settings' do
      result = described_class.with_bypass_settings
      expect(result).to contain_exactly(policy_with_bypass)
    end
  end

  describe '.with_warn_mode' do
    let_it_be(:policy_with_warn_mode) { create(:security_policy, :enforcement_type_warn) }
    let_it_be(:policy_without_warn_mode) { create(:security_policy, :require_approval) }
    let_it_be(:policy_with_enforce_type) do
      create(:security_policy, content: { enforcement_type: described_class::DEFAULT_ENFORCEMENT_TYPE })
    end

    it 'returns only policies with non-empty warn_mode' do
      result = described_class.with_warn_mode
      expect(result).to contain_exactly(policy_with_warn_mode)
    end
  end

  describe '.without_warn_mode' do
    let_it_be(:policy_with_warn_mode) { create(:security_policy, :enforcement_type_warn) }
    let_it_be(:policy_without_warn_mode) { create(:security_policy, :require_approval) }
    let_it_be(:policy_with_enforce_type) do
      create(:security_policy, content: { enforcement_type: described_class::DEFAULT_ENFORCEMENT_TYPE })
    end

    it 'returns only policies without warn_mode enforcement_type' do
      result = described_class.without_warn_mode
      expect(result).to contain_exactly(policy_without_warn_mode, policy_with_enforce_type)
    end
  end

  describe '.auto_dismiss_policies' do
    let_it_be(:policy_with_auto_resolve) { create(:security_policy, :vulnerability_management_policy, :auto_resolve) }
    let_it_be(:policy_with_auto_dismiss) { create(:security_policy, :vulnerability_management_policy, :auto_dismiss) }

    it 'returns only policies with auto_dismiss type' do
      result = described_class.auto_dismiss_policies
      expect(result).to contain_exactly(policy_with_auto_dismiss)
    end
  end

  describe '.severity_override_policies' do
    let_it_be(:policy_with_auto_resolve) { create(:security_policy, :vulnerability_management_policy, :auto_resolve) }
    let_it_be(:policy_with_auto_dismiss) { create(:security_policy, :vulnerability_management_policy, :auto_dismiss) }
    let_it_be(:policy_with_severity_override) do
      create(:security_policy, :vulnerability_management_policy, :severity_override)
    end

    it 'returns only policies with severity_override type' do
      result = described_class.severity_override_policies
      expect(result).to contain_exactly(policy_with_severity_override)
    end
  end

  describe '.prevent_pushing_and_force_pushing' do
    let_it_be(:policy_a) { create(:security_policy, :prevent_pushing_and_force_pushing) }
    let_it_be(:policy_b) do
      create(:security_policy, content: { approval_settings: { prevent_pushing_and_force_pushing: false } })
    end

    let_it_be(:policy_c) do
      create(:security_policy, :block_branch_modification)
    end

    let_it_be(:policy_d) { create(:security_policy, content: {}) }

    subject(:prevent_pushing_and_force_pushing) { described_class.prevent_pushing_and_force_pushing }

    it { is_expected.to contain_exactly(policy_a) }
  end

  describe '.blocking_branch_modification' do
    let_it_be(:policy_a) { create(:security_policy, :block_branch_modification) }
    let_it_be(:policy_b) do
      create(:security_policy, content: { approval_settings: { blocking_branch_modification: false } })
    end

    let_it_be(:policy_c) do
      create(:security_policy, :prevent_pushing_and_force_pushing)
    end

    let_it_be(:policy_d) { create(:security_policy, content: {}) }

    subject(:block_branch_modification) { described_class.block_branch_modification }

    it { is_expected.to contain_exactly(policy_a) }
  end

  describe '.prevent_editing_approval_rules' do
    let_it_be(:policy_a) { create(:security_policy, :prevent_editing_approval_rules) }
    let_it_be(:policy_b) do
      create(:security_policy, content: { approval_settings: { prevent_editing_approval_rules: false } })
    end

    let_it_be(:policy_c) do
      create(:security_policy, :block_branch_modification)
    end

    let_it_be(:policy_d) { create(:security_policy, content: {}) }

    subject(:prevent_editing_approval_rules) { described_class.prevent_editing_approval_rules }

    it { is_expected.to contain_exactly(policy_a) }
  end

  describe '.with_enrichment_filters' do
    let(:policy) { create(:security_policy, :approval_policy) }
    let_it_be(:policy_without_enrichment_filters) { create(:security_policy, :approval_policy) }

    let_it_be(:approval_rule_content, freeze: false) do
      {
        type: 'scan_finding',
        branches: [],
        scanners: %w[container_scanning],
        vulnerabilities_allowed: 0,
        severity_levels: %w[critical],
        vulnerability_states: %w[detected]
      }
    end

    shared_examples_for 'it returns no policy' do
      it { is_expected.to be_empty }
    end

    shared_examples_for 'it returns no policy when approval rules are deleted' do
      before do
        policy.approval_policy_rules.each { |rule| rule.update!(rule_index: (rule.rule_index * -1) - 1) }
      end

      it_behaves_like 'it returns no policy'
    end

    shared_examples_for 'it returns the policy with enrichment filters' do
      it { is_expected.to contain_exactly(policy) }
    end

    subject(:with_enrichment_filters) { described_class.with_enrichment_filters }

    context 'when there are no policies with vulnerability_attributes' do
      it_behaves_like 'it returns no policy'
    end

    context 'when there are policies with vulnerability_attributes' do
      let(:approval_rule_content_with_vulnerability_attributes) do
        approval_rule_content.merge!(vulnerability_attributes: vulnerability_attributes)
      end

      let!(:approval_policy_rule) do
        create(:approval_policy_rule, :scan_finding, security_policy: policy,
          content: approval_rule_content_with_vulnerability_attributes)
      end

      context 'when approval rule contains known_exploited' do
        let(:vulnerability_attributes) { { known_exploited: true } }

        it_behaves_like 'it returns the policy with enrichment filters'
        it_behaves_like 'it returns no policy when approval rules are deleted'
      end

      context 'when approval rule contains epss_score' do
        let(:vulnerability_attributes) { { epss_score: { operator: 'greater_than', value: 0.5 } } }

        it_behaves_like 'it returns the policy with enrichment filters'
        it_behaves_like 'it returns no policy when approval rules are deleted'
      end

      context 'when approval rule contains both known_exploited and epss_score' do
        let(:vulnerability_attributes) do
          { known_exploited: true, epss_score: { operator: 'greater_than', value: 0.5 } }
        end

        it_behaves_like 'it returns the policy with enrichment filters'
        it_behaves_like 'it returns no policy when approval rules are deleted'
      end

      context 'when a policy contain multiple approval rules with enrichment filters' do
        let(:vulnerability_attributes) { { known_exploited: true } }
        let!(:other_approval_policy_rule) do
          create(:approval_policy_rule, :scan_finding, security_policy: policy,
            content: approval_rule_content_with_vulnerability_attributes)
        end

        it_behaves_like 'it returns the policy with enrichment filters'
      end

      context 'when multiple policies contains approval rule contains with enrichment filters' do
        let(:vulnerability_attributes) { { known_exploited: true } }
        let_it_be(:other_policy) { create(:security_policy, :approval_policy) }
        let!(:other_approval_policy_rule) do
          create(:approval_policy_rule, :scan_finding, security_policy: other_policy,
            content: approval_rule_content_with_vulnerability_attributes)
        end

        it { is_expected.to contain_exactly(policy, other_policy) }
      end

      context 'when approval rule contains other attributes than known_exploited and epss_score' do
        let(:vulnerability_attributes) { { fix_available: true } }

        it_behaves_like 'it returns no policy'
      end
    end
  end

  describe '#has_enrichment_filters?' do
    context 'when policy has enrichment filter rules' do
      let_it_be(:policy_with_enrichment_filters) { create(:security_policy, :with_enrichment_filter_rule) }
      let_it_be(:policy_with_known_exploited_filters) { create(:security_policy, :with_known_exploited_filter_rule) }

      it 'returns true for policy with epss filter' do
        expect(policy_with_enrichment_filters.has_enrichment_filters?).to be true
      end

      it 'returns true for policy with known_exploited filter' do
        expect(policy_with_known_exploited_filters.has_enrichment_filters?).to be true
      end

      it 'returns true for policy with both epss and known_exploited filters' do
        policy = create(:security_policy, :approval_policy)
        create(:approval_policy_rule, :scan_finding, security_policy: policy,
          content: {
            type: 'scan_finding',
            branches: [],
            scanners: %w[container_scanning],
            vulnerabilities_allowed: 0,
            severity_levels: %w[critical],
            vulnerability_states: %w[detected],
            vulnerability_attributes: {
              known_exploited: true,
              epss_score: { operator: 'greater_than', value: 0.5 }
            }
          })

        expect(policy.has_enrichment_filters?).to be true
      end
    end

    context 'when policy does not have enrichment filter rules' do
      let_it_be(:policy_without_enrichment_filters) { create(:security_policy, :approval_policy) }

      it 'returns false' do
        expect(policy_without_enrichment_filters.has_enrichment_filters?).to be false
      end
    end

    context 'when policy has deleted enrichment filter rules' do
      let_it_be(:policy_with_enrichment_filters) { create(:security_policy, :with_enrichment_filter_rule) }

      before do
        policy_with_enrichment_filters.approval_policy_rules.update_all(rule_index: -1)
      end

      it 'returns false' do
        expect(policy_with_enrichment_filters.has_enrichment_filters?).to be false
      end
    end
  end

  describe '#bypass_settings' do
    let(:access_token_id) { 42 }
    let(:service_account_id) { 99 }

    context 'when bypass_settings is nil' do
      let(:policy) { build(:security_policy, content: {}) }

      it 'returns a BypassSettings object with empty arrays' do
        expect(policy.bypass_settings.access_token_ids).to be_empty
        expect(policy.bypass_settings.service_account_ids).to be_empty
      end
    end

    context 'when bypass_settings is empty' do
      let(:policy) { build(:security_policy, content: { bypass_settings: {} }) }

      it 'returns a BypassSettings object with empty arrays' do
        expect(policy.bypass_settings.access_token_ids).to be_empty
        expect(policy.bypass_settings.service_account_ids).to be_empty
      end
    end

    context 'when bypass_settings has access_tokens and service_accounts' do
      let(:policy) do
        build(:security_policy,
          bypass_access_token_ids: [access_token_id],
          bypass_service_account_ids: [service_account_id]
        )
      end

      it 'returns the correct ids' do
        expect(policy.bypass_settings.access_token_ids).to contain_exactly(access_token_id)
        expect(policy.bypass_settings.service_account_ids).to contain_exactly(service_account_id)
      end
    end

    context 'when policy is a dependency_firewall_policy' do
      # Factory sets bypass_settings: { users: [{ id: 1222 }], access_tokens: [{ id: 222 }] }
      let(:policy) { build(:security_policy, :dependency_firewall_policy) }

      it 'returns a DependencyFirewallPolicies::BypassSettings instance' do
        expect(policy.bypass_settings).to be_a(Security::DependencyFirewallPolicies::BypassSettings)
      end

      it 'populates user_ids from bypass_settings' do
        expect(policy.bypass_settings.user_ids).to eq([1222])
      end

      it 'populates access_token_ids from bypass_settings' do
        expect(policy.bypass_settings.access_token_ids).to eq([222])
      end
    end
  end

  describe '#security_report_time_window' do
    subject(:security_report_time_window) { policy.security_report_time_window }

    context 'when policy_tuning is present in content' do
      let(:policy) do
        build(:security_policy, content: {
          policy_tuning: {
            security_report_time_window: 1440
          }
        })
      end

      it 'returns the security_report_time_window value from policy_tuning' do
        expect(security_report_time_window).to eq(1440)
      end
    end

    context 'when policy_tuning is empty in content' do
      let(:policy) { build(:security_policy, content: { policy_tuning: {} }) }

      it 'returns nil' do
        expect(security_report_time_window).to be_nil
      end
    end
  end

  describe '#create_merge_request_bypass_event!' do
    let_it_be(:project) { create(:project) }
    let_it_be(:user) { create(:user) }
    let_it_be(:merge_request) { create(:merge_request, source_project: project) }
    let_it_be(:policy) { create(:security_policy, :approval_policy) }
    let_it_be(:reason) { 'Security policy bypassed due to emergency' }

    subject(:create_bypass_event!) do
      policy.create_merge_request_bypass_event!(
        project: project,
        user: user,
        reason: reason,
        merge_request: merge_request
      )
    end

    it 'creates the bypass event with correct attributes' do
      bypass_event = create_bypass_event!

      expect(bypass_event).to have_attributes(
        project: project,
        user: user,
        reason: reason,
        merge_request: merge_request,
        security_policy: policy
      )
    end

    context 'when creating multiple bypass events for the same merge request and policy' do
      before do
        create(:approval_policy_merge_request_bypass_event,
          security_policy: policy,
          project: project,
          merge_request: merge_request
        )
      end

      it 'raises a validation error due to uniqueness constraint' do
        expect { create_bypass_event! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'when creating bypass events for different policies on the same merge request' do
      let_it_be(:other_policy) { create(:security_policy, :approval_policy) }

      before do
        create(:approval_policy_merge_request_bypass_event,
          security_policy: policy,
          project: project,
          merge_request: merge_request
        )
      end

      it 'allows creating bypass events for different policies' do
        expect do
          other_policy.create_merge_request_bypass_event!(
            project: project,
            user: user,
            reason: reason,
            merge_request: merge_request
          )
        end.to change { Security::ApprovalPolicyMergeRequestBypassEvent.count }.by(1)
      end
    end
  end

  describe '#merge_request_bypassed?' do
    let_it_be(:project) { create(:project) }
    let_it_be(:merge_request) { create(:merge_request, source_project: project) }
    let_it_be(:policy) { create(:security_policy, :approval_policy) }

    subject(:merge_request_bypassed?) { policy.merge_request_bypassed?(merge_request) }

    context 'when policy is not an approval policy' do
      let(:policy) { create(:security_policy, :scan_execution_policy) }

      it { is_expected.to be false }
    end

    context 'when policy is approval policy' do
      context 'when no bypass events exist for the merge request' do
        it { is_expected.to be false }
      end

      context 'when bypass events exist for the merge request' do
        before do
          create(:approval_policy_merge_request_bypass_event,
            security_policy: policy,
            project: project,
            merge_request: merge_request
          )
        end

        it { is_expected.to be true }
      end

      context 'when bypass events exist for other merge requests' do
        let_it_be(:other_project) { create(:project) }
        let_it_be(:other_merge_request) { create(:merge_request, source_project: other_project) }

        before do
          create(:approval_policy_merge_request_bypass_event,
            security_policy: policy,
            project: other_project,
            merge_request: other_merge_request
          )
        end

        it { is_expected.to be false }
      end

      context 'when bypass events exist for other policies' do
        let_it_be(:other_policy) { create(:security_policy, :approval_policy) }

        before do
          create(:approval_policy_merge_request_bypass_event,
            security_policy: other_policy,
            project: project,
            merge_request: merge_request
          )
        end

        it { is_expected.to be false }
      end

      context 'when association is preloaded' do
        context 'when bypass event exists for the merge request' do
          before do
            create(:approval_policy_merge_request_bypass_event,
              security_policy: policy,
              project: project,
              merge_request: merge_request
            )
          end

          it 'returns true without executing additional queries', :aggregate_failures do
            policy_with_preload = described_class
              .where(id: policy.id)
              .preload(:approval_policy_merge_request_bypass_events)
              .first

            expect { policy_with_preload.merge_request_bypassed?(merge_request) }
              .not_to exceed_query_limit(0)
            expect(policy_with_preload.merge_request_bypassed?(merge_request)).to be true
          end
        end

        context 'when no bypass event exists for the merge request' do
          let_it_be(:another_project) { create(:project) }
          let_it_be(:another_merge_request) { create(:merge_request, source_project: another_project) }

          before do
            create(:approval_policy_merge_request_bypass_event,
              security_policy: policy,
              project: another_project,
              merge_request: another_merge_request
            )
          end

          it 'returns false without executing additional queries', :aggregate_failures do
            policy_with_preload = described_class
              .where(id: policy.id)
              .preload(:approval_policy_merge_request_bypass_events)
              .first

            expect { policy_with_preload.merge_request_bypassed?(merge_request) }
              .not_to exceed_query_limit(0)
            expect(policy_with_preload.merge_request_bypassed?(merge_request)).to be false
          end
        end
      end
    end
  end

  describe '#merge_request_bypass_allowed?' do
    let_it_be(:project) { create(:project) }
    let_it_be(:user) { create(:user) }
    let_it_be(:merge_request) { create(:merge_request, source_project: project) }
    let_it_be(:policy) { create(:security_policy, :approval_policy) }

    subject(:merge_request_bypass_allowed?) { policy.merge_request_bypass_allowed?(merge_request, user) }

    context 'when bypass_settings is empty' do
      let(:policy) do
        create(:security_policy, :approval_policy, content: {
          bypass_settings: {}
        })
      end

      it { is_expected.to be false }
    end

    context 'when policy is not an approval policy' do
      let(:policy) { create(:security_policy, :scan_execution_policy) }

      it { is_expected.to be false }
    end

    context 'when bypass_settings has users configured' do
      let(:policy) do
        create(:security_policy, :approval_policy, content: {
          bypass_settings: {
            users: [{ id: user.id }]
          }
        })
      end

      context 'when user has bypass scope via user bypass checker' do
        it { is_expected.to be true }
      end

      context 'when user does not have bypass scope via user bypass checker' do
        let(:other_user) { create(:user) }

        subject(:merge_request_bypass_allowed?) { policy.merge_request_bypass_allowed?(merge_request, other_user) }

        it { is_expected.to be false }
      end
    end

    context 'when bypass_settings has only access_tokens configured' do
      let_it_be(:bot_user) { create(:user, :project_bot) }
      let(:policy) do
        create(:security_policy, :approval_policy, content: {
          bypass_settings: {
            access_tokens: [{ id: token.id }]
          }
        })
      end

      subject(:merge_request_bypass_allowed?) { policy.merge_request_bypass_allowed?(merge_request, bot_user) }

      context 'when bot user has a matching active access token' do
        let(:token) { create(:personal_access_token, user: bot_user) }

        it { is_expected.to be true }
      end

      context 'when bot user does not have a matching access token' do
        let(:token) { create(:personal_access_token) }

        it { is_expected.to be false }
      end
    end

    context 'when bypass_settings has only service_accounts configured' do
      let_it_be(:service_account_user) { create(:user, :service_account) }
      let_it_be(:policy) do
        create(:security_policy, :approval_policy, content: {
          bypass_settings: {
            service_accounts: [{ id: service_account_user.id }]
          }
        })
      end

      subject(:merge_request_bypass_allowed?) do
        policy.merge_request_bypass_allowed?(merge_request, current_user)
      end

      context 'when service account is allowed to bypass' do
        let(:current_user) { service_account_user }

        it { is_expected.to be true }
      end

      context 'when service account is not allowed to bypass' do
        let(:current_user) { create(:user, :service_account) }

        it { is_expected.to be false }
      end
    end

    context 'when bypass_settings has both users and access_tokens configured' do
      let_it_be(:bot_user) { create(:user, :project_bot) }
      let_it_be(:token) { create(:personal_access_token, user: bot_user) }
      let_it_be(:policy) do
        create(:security_policy, :approval_policy, content: {
          bypass_settings: {
            users: [{ id: user.id }],
            access_tokens: [{ id: token.id }]
          }
        })
      end

      context 'when called with the human user' do
        it { is_expected.to be true }
      end

      context 'when called with the bot user' do
        subject(:merge_request_bypass_allowed?) { policy.merge_request_bypass_allowed?(merge_request, bot_user) }

        it { is_expected.to be true }
      end
    end
  end
end
