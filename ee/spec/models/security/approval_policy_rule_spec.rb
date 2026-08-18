# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ApprovalPolicyRule, feature_category: :security_policy_management do
  it_behaves_like 'policy rule' do
    let(:rule_hash) { build(:approval_policy)[:rules].first }
    let(:policy_type) { :approval_policy }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:security_policy) }
    it { is_expected.to belong_to(:security_policy_management_project) }
    it { is_expected.to have_many(:approval_merge_request_rules) }
    it { is_expected.to have_many(:violations) }
    it { is_expected.to have_many(:approval_policy_rule_project_links) }
    it { is_expected.to have_many(:projects).through(:approval_policy_rule_project_links) }
  end

  describe 'validations' do
    describe 'content' do
      subject(:rule) { build(:approval_policy_rule, trait) }

      context 'when scan_finding' do
        let(:trait) { :scan_finding }

        it { is_expected.to be_valid }
      end

      context 'when license_finding' do
        let(:trait) { :license_finding }

        it { is_expected.to be_valid }
      end

      context 'when any_merge_request' do
        let(:trait) { :any_merge_request }

        it { is_expected.to be_valid }
      end

      context 'when license_finding_with_allowed_licenses' do
        let(:trait) { :license_finding_with_allowed_licenses }

        it { is_expected.to be_valid }
      end

      context 'when license_finding_with_denied_licenses' do
        let(:trait) { :license_finding_with_denied_licenses }

        it { is_expected.to be_valid }
      end

      context 'when license_finding defines the license list using both the current and new set of keys' do
        let(:trait) { :license_finding_with_current_and_new_keys }

        it { is_expected.not_to be_valid }
      end
    end

    describe 'typed_content size limit' do
      let(:rule) { build(:approval_policy_rule, :scan_finding) }

      context 'when typed_content exceeds size limit' do
        before do
          rule.content = { large_field: 'x' * 1_100_000 }
        end

        it 'is invalid with size error' do
          expect(rule).not_to be_valid
          expect(rule.errors[:typed_content].first).to include('is too large')
        end
      end

      context 'when typed_content is within size limit' do
        it { expect(rule).to be_valid }
      end
    end

    describe 'license_override_purls_are_valid' do
      subject(:rule) { build(:approval_policy_rule, :license_finding) }

      context 'when there are no license overrides' do
        it { is_expected.to be_valid }
      end

      context 'when all purls are valid' do
        before do
          rule.content['license_overrides'] = [
            { 'purl' => 'pkg:pypi/urllib3', 'license' => 'MIT', 'mode' => 'patch' },
            { 'purl' => 'pkg:gem/rails', 'license' => 'Apache-2.0', 'mode' => 'overwrite' }
          ]
        end

        it { is_expected.to be_valid }
      end

      context 'when a purl is invalid' do
        before do
          rule.content['license_overrides'] = [
            { 'purl' => 'not-a-purl', 'license' => 'MIT', 'mode' => 'patch' }
          ]
        end

        it { is_expected.not_to be_valid }

        it 'includes the invalid purl in the error message' do
          rule.valid?

          expect(rule.errors[:typed_content]).to include(a_string_including('not-a-purl'))
        end
      end

      context 'when the rule is not a license_finding' do
        subject(:rule) { build(:approval_policy_rule, :scan_finding) }

        it 'does not run the validation' do
          expect(rule).not_to receive(:license_override_purls_are_valid)

          rule.valid?
        end
      end
    end
  end

  describe '.by_policy_rule_index' do
    let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration) }
    let_it_be(:security_policy) do
      create(:security_policy, security_orchestration_policy_configuration: policy_configuration, policy_index: 1)
    end

    let_it_be(:approval_policy_rule) do
      create(:approval_policy_rule, security_policy: security_policy, rule_index: 2)
    end

    let_it_be(:other_approval_policy_rule) { create(:approval_policy_rule, rule_index: 3) }

    it 'returns the correct approval policy rule' do
      result = described_class.by_policy_rule_index(policy_configuration, policy_index: 1, rule_index: 2)

      expect(result).to eq(approval_policy_rule)
    end

    it 'does not return approval policy rules with different policy configuration' do
      other_policy_configuration = create(:security_orchestration_policy_configuration)
      result = described_class.by_policy_rule_index(other_policy_configuration, policy_index: 1, rule_index: 2)

      expect(result).to be_nil
    end

    it 'does not return approval policy rules with different policy index' do
      result = described_class.by_policy_rule_index(policy_configuration, policy_index: 2, rule_index: 2)

      expect(result).to be_nil
    end

    it 'does not return approval policy rules with different rule index' do
      result = described_class.by_policy_rule_index(policy_configuration, policy_index: 1, rule_index: 3)

      expect(result).to be_nil
    end

    it 'returns an empty relation when no matching rules are found' do
      result = described_class.by_policy_rule_index(policy_configuration, policy_index: 99, rule_index: 99)

      expect(result).to be_nil
    end
  end

  describe '.deleted' do
    let_it_be(:rule_with_positive_index) { create(:approval_policy_rule, rule_index: 1) }
    let_it_be(:rule_with_zero_index) { create(:approval_policy_rule, rule_index: 0) }
    let_it_be(:rule_with_negative_index) { create(:approval_policy_rule, rule_index: -1) }

    it 'returns rules with rule_index lesser than 0' do
      result = described_class.deleted

      expect(result).to contain_exactly(rule_with_negative_index)
      expect(result).not_to include(rule_with_positive_index, rule_with_zero_index)
    end
  end

  describe '.undeleted' do
    let_it_be(:rule_with_positive_index) { create(:approval_policy_rule, rule_index: 1) }
    let_it_be(:rule_with_zero_index) { create(:approval_policy_rule, rule_index: 0) }
    let_it_be(:rule_with_negative_index) { create(:approval_policy_rule, rule_index: -1) }

    it 'returns rules with rule_index greater than or equal to 0' do
      result = described_class.undeleted

      expect(result).to contain_exactly(rule_with_positive_index, rule_with_zero_index)
      expect(result).not_to include(rule_with_negative_index)
    end
  end

  describe '.with_enrichment_filters' do
    let_it_be(:deleted_rule_with_epss_filter) do
      create(:approval_policy_rule, :scan_finding_with_epss_filter, :deleted)
    end

    let_it_be(:rule_without_enrichment_filters) do
      create(:approval_policy_rule, :scan_finding)
    end

    subject(:with_enrichment_filters) { described_class.with_enrichment_filters }

    it 'returns empty when no undeleted rules have enrichment filters' do
      expect(with_enrichment_filters).to be_empty
    end

    context 'when there are rules with enrichment filters' do
      let_it_be(:rule_with_epss_filter) do
        create(:approval_policy_rule, :scan_finding_with_epss_filter)
      end

      let_it_be(:rule_with_known_exploited_filter) do
        create(:approval_policy_rule, :scan_finding_with_known_exploited_filter)
      end

      it 'returns all rules with enrichment filters' do
        expect(with_enrichment_filters).to contain_exactly(rule_with_epss_filter, rule_with_known_exploited_filter)
      end
    end
  end

  describe '.targeting_commits' do
    let_it_be(:any_merge_request_rule_with_commits) do
      create(:approval_policy_rule, :any_merge_request)
    end

    let_it_be(:scan_finding_rule) do
      create(:approval_policy_rule, :scan_finding)
    end

    let_it_be(:license_finding_rule) do
      create(:approval_policy_rule, :license_finding)
    end

    subject(:targeting_commits) { described_class.targeting_commits }

    it 'returns only any_merge_request rules with commits in content' do
      expect(targeting_commits).to contain_exactly(any_merge_request_rule_with_commits)
    end

    it 'excludes scan_finding rules' do
      expect(targeting_commits).not_to include(scan_finding_rule)
    end

    it 'excludes license_finding rules' do
      expect(targeting_commits).not_to include(license_finding_rule)
    end
  end

  describe '.license_finding_with_overrides_for_project' do
    let_it_be(:project) { create(:project) }

    let(:rule_with_overrides) do
      create(:approval_policy_rule, :license_finding_with_allowed_licenses,
        content: {
          type: 'license_finding',
          branches: [],
          license_states: %w[newly_detected],
          licenses: { allowed: [{ name: 'MIT License' }] },
          license_overrides: [{ purl: 'pkg:pypi/urllib3', license: 'MIT License', mode: 'patch' }]
        })
    end

    let(:rule_without_overrides) do
      create(:approval_policy_rule, :license_finding_with_allowed_licenses,
        content: {
          type: 'license_finding',
          branches: [],
          license_states: %w[newly_detected],
          licenses: { allowed: [{ name: 'MIT License' }] }
        })
    end

    let(:scan_finding_rule) do
      create(:approval_policy_rule, :scan_finding)
    end

    before do
      create(:approval_policy_rule_project_link, approval_policy_rule: rule_with_overrides, project: project)
      create(:approval_policy_rule_project_link, approval_policy_rule: rule_without_overrides, project: project)
      create(:approval_policy_rule_project_link, approval_policy_rule: scan_finding_rule, project: project)
    end

    it 'returns only license_finding rules with license_overrides linked to the project' do
      result = described_class.license_finding_with_overrides_for_project(project.id)

      expect(result).to contain_exactly(rule_with_overrides)
    end

    it 'does not return rules linked to other projects' do
      other_project = create(:project)

      result = described_class.license_finding_with_overrides_for_project(other_project.id)

      expect(result).to be_empty
    end
  end

  describe '.licenses' do
    let_it_be(:rule) { build(:approval_policy_rule, :any_merge_request) }

    subject(:licenses) { rule.licenses }

    context 'when typed_content does not contain licenses information' do
      it 'returns nil' do
        expect(licenses).to be_nil
      end
    end

    context 'when typed_content contain licenses information' do
      let_it_be(:allowed_licenses) do
        { "allowed" => [{ "name" => "MIT License",
                          "packages" => { "excluding" => { "purls" => ["pkg:gem/bundler@1.0.0"] } } }] }
      end

      let_it_be(:rule) { build(:approval_policy_rule, :license_finding_with_allowed_licenses) }

      it 'returns the list of licenses' do
        expect(licenses).to eq(allowed_licenses)
      end
    end
  end

  describe '.license_states' do
    let_it_be(:rule) { build(:approval_policy_rule, :any_merge_request) }

    subject(:license_states) { rule.license_states }

    context 'when typed_content does not contain license_states information' do
      it 'returns nil' do
        expect(license_states).to be_nil
      end
    end

    context 'when typed_content contain license_states information' do
      let_it_be(:expected_license_states) { %w[newly_detected detected] }

      let_it_be(:rule) { build(:approval_policy_rule, :license_finding_with_allowed_licenses) }

      it 'returns the list of licenses' do
        expect(license_states).to eq(expected_license_states)
      end
    end
  end

  describe '.license_types' do
    let_it_be(:rule) { build(:approval_policy_rule, :any_merge_request) }

    subject(:license_types) { rule.license_types }

    context 'when typed_content does not contain license_types information' do
      it 'returns nil' do
        expect(license_types).to be_nil
      end
    end

    context 'when typed_content contain license_states information' do
      let_it_be(:expected_license_types) { %w[BSD MIT] }

      let_it_be(:rule) { build(:approval_policy_rule, :license_finding) }

      it 'returns the list of licenses' do
        expect(license_types).to eq(expected_license_types)
      end
    end
  end

  describe '#rule' do
    let_it_be(:approval_policy_rule) { build(:approval_policy_rule, :scan_finding) }

    it 'returns a Rule object built from symbolized content' do
      rule = approval_policy_rule.rule

      expect(rule).to be_a(Security::ScanResultPolicies::Rule)
      expect(rule.type).to eq('scan_finding')
    end

    context 'when content is nil' do
      let_it_be(:approval_policy_rule) { build(:approval_policy_rule, :scan_finding, content: nil) }

      it 'returns a Rule object with nil content' do
        rule = approval_policy_rule.rule

        expect(rule).to be_a(Security::ScanResultPolicies::Rule)
      end
    end
  end

  describe 'delegations' do
    it { is_expected.to delegate_method(:newly_detected?).to(:rule) }
    it { is_expected.to delegate_method(:only_newly_detected_licenses?).to(:rule) }
    it { is_expected.to delegate_method(:commits_any?).to(:rule) }
    it { is_expected.to delegate_method(:commits_unsigned?).to(:rule) }
    it { is_expected.to delegate_method(:vulnerability_age).to(:rule) }
    it { is_expected.to delegate_method(:vulnerability_attributes).to(:rule) }
    it { is_expected.to delegate_method(:match_on_inclusion_license).to(:rule) }

    it { is_expected.to delegate_method(:fail_open?).to(:approval_policy) }
    it { is_expected.to delegate_method(:bot_message_disabled?).to(:approval_policy) }
    it { is_expected.to delegate_method(:unblock_rules_using_execution_policies?).to(:approval_policy) }
    it { is_expected.to delegate_method(:prevent_approval_by_author?).to(:approval_policy) }
    it { is_expected.to delegate_method(:prevent_approval_by_commit_author?).to(:approval_policy) }
    it { is_expected.to delegate_method(:approval_settings).to(:approval_policy) }
  end

  describe 'role approvers' do
    let(:policy_content) do
      {
        'actions' => [
          { 'type' => 'require_approval', 'approvals_required' => 1, 'role_approvers' => role_approvers }
        ]
      }
    end

    let(:security_policy) { create(:security_policy, :require_approval, content: policy_content) }
    let(:approval_policy_rule) { create(:approval_policy_rule, :scan_finding, security_policy: security_policy) }

    describe '#role_approvers' do
      let(:role_approvers) { %w[developer maintainer] }

      it 'maps allowed role strings to access levels' do
        expect(approval_policy_rule.role_approvers(action_idx: 0))
          .to contain_exactly(Gitlab::Access::DEVELOPER, Gitlab::Access::MAINTAINER)
      end

      context 'with non-allowed roles' do
        let(:role_approvers) { %w[guest] }

        it { expect(approval_policy_rule.role_approvers(action_idx: 0)).to be_empty }
      end

      context 'with action_idx pointing at a non-existent action' do
        it { expect(approval_policy_rule.role_approvers(action_idx: 99)).to eq([]) }
      end
    end

    describe '#custom_roles' do
      context 'with integer role_approvers' do
        let(:role_approvers) { ['developer', 42, 43] }

        it 'returns only integer role ids' do
          expect(approval_policy_rule.custom_roles(action_idx: 0)).to contain_exactly(42, 43)
        end
      end

      context 'with no integer role_approvers' do
        let(:role_approvers) { %w[developer] }

        it { expect(approval_policy_rule.custom_roles(action_idx: 0)).to eq([]) }
      end
    end
  end

  describe '#approval_policy' do
    let(:approval_policy_rule) { create(:approval_policy_rule, :scan_finding) }

    it 'returns the security_policy approval_policy' do
      expect(approval_policy_rule.approval_policy).to be_a(Security::ScanResultPolicies::ApprovalPolicy)
    end
  end

  describe '#policy_applies_to_target_branch?' do
    let(:target_branch) { 'main' }
    let(:default_branch) { 'master' }

    let_it_be(:project) { build_stubbed(:project) }
    let_it_be(:security_policy) { create(:security_policy) }

    before do
      allow(project).to receive(:default_branch).and_return(default_branch)
    end

    subject(:policy_applies_to_target_branch?) do
      approval_policy_rule.policy_applies_to_target_branch?(target_branch, project)
    end

    context 'with `branches`' do
      let(:approval_policy_rule) do
        build(:approval_policy_rule, :scan_finding, security_policy: security_policy) do |policy_rule|
          policy_rule.update!(content: policy_rule.content.merge("branches" => branches))
        end
      end

      context 'with empty branches' do
        let(:branches) { [] }

        it { is_expected.to be(true) }
      end

      context 'when matching target branch' do
        let(:branches) { [target_branch] }

        it { is_expected.to be(true) }
      end

      context 'when mismatching target branch' do
        let(:branches) { [target_branch.reverse] }

        it { is_expected.to be(false) }
      end
    end

    context 'with `branch_type`' do
      let(:approval_policy_rule) do
        build(:approval_policy_rule, :scan_finding, security_policy: security_policy) do |policy_rule|
          policy_rule.update!(content: policy_rule.content.excluding("branches").merge("branch_type" => branch_type))
        end
      end

      context 'with `default`' do
        let(:branch_type) { 'default' }

        context 'with default branch' do
          let(:target_branch) { default_branch }

          it { is_expected.to be(true) }
        end

        context 'with other branch' do
          it { is_expected.to be(false) }
        end
      end

      context 'with `protected`' do
        let(:branch_type) { 'protected' }

        before do
          allow(ProtectedBranch).to receive(:protected?).with(project, target_branch).and_return(branch_protected?)
        end

        context 'with protected branch' do
          let(:branch_protected?) { true }

          it { is_expected.to be(true) }
        end

        context 'with unprotected branch' do
          let(:branch_protected?) { false }

          it { is_expected.to be(false) }
        end
      end
    end
  end

  describe '#branches_exempted_by_policy?' do
    let(:source_branch) { 'feature' }
    let(:target_branch) { 'main' }

    let(:bypass_settings) { {} }
    let(:content) { { bypass_settings: bypass_settings } }

    let(:security_policy) { build(:security_policy, content: content) }

    let(:approval_policy_rule) do
      build(:approval_policy_rule, :scan_finding, security_policy: security_policy)
    end

    subject(:branches_exempted_by_policy) do
      approval_policy_rule.branches_exempted_by_policy?(source_branch, target_branch)
    end

    context 'when content is empty' do
      let(:content) { {} }

      it { is_expected.to be false }
    end

    context 'when bypass_settings is empty' do
      let(:bypass_settings) { {} }

      it { is_expected.to be false }
    end

    context 'when bypass_settings branches is empty' do
      let(:bypass_settings) { { branches: [] } }

      it { is_expected.to be false }
    end

    context 'when bypass_settings has a matching source and target branches' do
      let(:bypass_settings) { { branches: [{ source: { name: source_branch }, target: { name: target_branch } }] } }

      it { is_expected.to be true }
    end

    context 'when bypass_settings uses a pattern for source and target branches' do
      let(:bypass_settings) do
        { branches: [{ 'source' => { 'pattern' => 'feat*' }, 'target' => { 'pattern' => 'ma*' } }] }
      end

      it { is_expected.to be true }

      context 'when source does not match the pattern' do
        let(:source_branch) { 'bugfix' }

        it { is_expected.to be false }
      end

      context 'when target does not match the pattern' do
        let(:target_branch) { 'develop' }

        it { is_expected.to be false }
      end
    end

    context 'when bypass_settings branches does not match source or target' do
      let(:bypass_settings) do
        { branches:
          [{ 'source' => { 'name' => 'other' }, 'target' => { 'name' => 'main' } },
            { 'source' => { 'name' => 'feature' }, 'target' => { 'name' => 'develop' } }] }
      end

      it { is_expected.to be false }
    end

    context 'when bypass_settings branches partially matches (only source or only target)' do
      let(:bypass_settings) do
        { branches:
          [{ 'source' => { 'name' => 'feature' }, 'target' => { 'name' => 'develop' } },
            { 'source' => { 'name' => 'other' }, 'target' => { 'name' => 'main' } }] }
      end

      it { is_expected.to be false }
    end

    context 'when security_policy is nil (parent policy was deleted)' do
      let(:approval_policy_rule) do
        build(:approval_policy_rule, :scan_finding).tap do |rule|
          allow(rule).to receive(:security_policy).and_return(nil)
        end
      end

      it 'returns false instead of raising NoMethodError' do
        expect { branches_exempted_by_policy }.not_to raise_error
        expect(branches_exempted_by_policy).to be false
      end
    end
  end

  describe '#custom_role_ids_with_permission' do
    let_it_be(:project) { create(:project) }
    let_it_be(:group) { create(:group) }

    let(:action_idx) { 0 }
    let(:role_ids) { %w[developer] }
    let(:policy_content) do
      {
        'actions' => [
          { 'type' => 'require_approval', 'approvals_required' => 1, 'role_approvers' => role_ids }
        ]
      }
    end

    let(:security_policy) do
      create(:security_policy, :require_approval, content: policy_content)
    end

    let(:approval_policy_rule) do
      create(:approval_policy_rule, :scan_finding, security_policy: security_policy)
    end

    subject(:custom_role_ids_with_permission) do
      approval_policy_rule.custom_role_ids_with_permission(project: project, action_idx: action_idx)
    end

    context 'when project is nil' do
      subject(:custom_role_ids_with_permission) do
        approval_policy_rule.custom_role_ids_with_permission(project: nil, action_idx: action_idx)
      end

      it { is_expected.to eq([]) }
    end

    context 'when on gitlab.com' do
      let_it_be(:role_with_permission) { create(:member_role, :admin_merge_request, namespace: group) }
      let_it_be(:role_without_permission) { create(:member_role, :guest, namespace: group) }
      let_it_be(:base_role_with_permission) { create(:member_role, :developer, namespace: group) }

      let(:role_ids) { [role_with_permission.id, role_without_permission.id, base_role_with_permission.id] }

      before do
        allow(approval_policy_rule).to receive(:gitlab_com_subscription?).and_return(true)
        allow(project).to receive(:root_ancestor).and_return(group)
      end

      it { is_expected.to contain_exactly(role_with_permission.id, base_role_with_permission.id) }

      context 'with action_idx pointing at a non-existent action' do
        let(:action_idx) { 99 }

        it { is_expected.to eq([]) }
      end
    end

    context 'when not on gitlab.com' do
      let_it_be(:role_with_permission) { create(:member_role, :admin_merge_request, :instance) }
      let_it_be(:role_without_permission) { create(:member_role, :guest, :instance) }
      let_it_be(:base_role_with_permission) { create(:member_role, :developer, :instance) }

      let(:role_ids) { [role_with_permission.id, role_without_permission.id, base_role_with_permission.id] }

      before do
        allow(approval_policy_rule).to receive(:gitlab_com_subscription?).and_return(false)
      end

      it { is_expected.to contain_exactly(role_with_permission.id, base_role_with_permission.id) }
    end
  end
end
