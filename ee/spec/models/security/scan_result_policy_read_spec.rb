# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicyRead, feature_category: :security_policy_management do
  describe 'associations' do
    it { is_expected.to belong_to(:security_orchestration_policy_configuration) }
  end

  describe 'validations' do
    let_it_be(:scan_result_policy_read, freeze: false) { create(:scan_result_policy_read) }

    subject { scan_result_policy_read }

    it { is_expected.not_to allow_value(nil).for(:role_approvers) }
    it { is_expected.to(validate_inclusion_of(:role_approvers).in_array(Gitlab::Access.values)) }

    it { is_expected.not_to allow_value(-1).for(:age_value) }
    it { is_expected.to allow_value(0, 1).for(:age_value) }
    it { is_expected.to allow_value(nil).for(:age_value) }

    it { is_expected.not_to allow_value("string").for(:vulnerability_attributes) }
    it { is_expected.to allow_value({}).for(:vulnerability_attributes) }
    it { is_expected.to allow_value(nil).for(:vulnerability_attributes) }

    it do
      is_expected.to allow_value({ false_positive: true, fix_available: false }).for(:vulnerability_attributes)
    end

    it { is_expected.not_to allow_value("string").for(:project_approval_settings) }
    it { is_expected.to allow_value({}).for(:project_approval_settings) }

    it { is_expected.not_to allow_value("string").for(:fallback_behavior) }
    it { is_expected.to allow_value({}).for(:fallback_behavior) }
    it { is_expected.to allow_value({ fail: described_class::FALLBACK_BEHAVIORS[:open] }).for(:fallback_behavior) }
    it { is_expected.to allow_value({ fail: described_class::FALLBACK_BEHAVIORS[:closed] }).for(:fallback_behavior) }
    it { is_expected.not_to allow_value({ fail: "foo" }).for(:fallback_behavior) }

    it { is_expected.not_to allow_value("string").for(:policy_tuning) }
    it { is_expected.to allow_value({}).for(:policy_tuning) }
    it { is_expected.to allow_value({ unblock_rules_using_execution_policies: true }).for(:policy_tuning) }
    it { is_expected.to allow_value({ unblock_rules_using_execution_policies: false }).for(:policy_tuning) }
    it { is_expected.not_to allow_value({ unblock_rules_using_execution_policies: "foo" }).for(:policy_tuning) }

    it do
      is_expected.to allow_value(
        { prevent_approval_by_author: true, prevent_approval_by_commit_author: false,
          remove_approvals_with_new_commit: true, require_password_to_approve: false,
          block_branch_modification: true, block_group_branch_modification: true }
      ).for(:project_approval_settings)
    end

    it do
      is_expected.to allow_value(
        { block_group_branch_modification: { enabled: true, exceptions: [{ id: 1231 }] } }
      ).for(:project_approval_settings)
    end

    it { is_expected.not_to allow_value('string').for(:send_bot_message) }
    it { is_expected.to allow_value({}).for(:send_bot_message) }
    it { is_expected.to allow_value({ enabled: true }).for(:send_bot_message) }
    it { is_expected.to allow_value({ enabled: false }).for(:send_bot_message) }
    it { is_expected.not_to allow_value({ enabled: 'foo' }).for(:send_bot_message) }

    it do
      is_expected.to(
        validate_uniqueness_of(:rule_idx)
          .scoped_to(%i[security_orchestration_policy_configuration_id project_id orchestration_policy_idx action_idx]))
    end

    it { is_expected.to validate_numericality_of(:rule_idx).is_greater_than_or_equal_to(0).only_integer }

    describe "#licenses" do
      it { is_expected.not_to allow_value("string").for(:licenses) }
      it { is_expected.to allow_value({}).for(:licenses) }
      it { is_expected.to allow_value(nil).for(:licenses) }

      [:allowed, :denied].each do |license_list_type|
        it { is_expected.not_to allow_value({ license_list_type => [] }).for(:licenses) }
        it { is_expected.to allow_value({ license_list_type => [{ name: "MIT License" }] }).for(:licenses) }

        it do
          is_expected.not_to allow_value(
            { license_list_type => [
              {
                name: "MIT License",
                packages: {}
              }
            ] }
          ).for(:licenses)
        end

        it do
          is_expected.not_to allow_value(
            { license_list_type => [
              {
                name: "MIT License",
                packages: { excluding: [] }
              }
            ] }
          ).for(:licenses)
        end

        it do
          is_expected.to allow_value(
            { license_list_type => [
              {
                name: "MIT License",
                packages: { excluding: { purls: ["pkg:gem/bundler@1.0.0"] } }
              }
            ] }
          ).for(:licenses)
        end
      end
    end
  end

  describe 'enums' do
    let(:age_operator_values) { { greater_than: 0, less_than: 1 } }
    let(:age_interval_values) { { day: 0, week: 1, month: 2, year: 3 } }

    it { is_expected.to define_enum_for(:age_operator).with_values(**age_operator_values) }
    it { is_expected.to define_enum_for(:age_interval).with_values(**age_interval_values) }
  end

  describe 'scopes' do
    describe '.blocking_branch_modification' do
      let_it_be(:non_blocking_read) { create(:scan_result_policy_read) }
      let_it_be(:blocking_read) do
        create(:scan_result_policy_read, project_approval_settings: { block_branch_modification: true })
      end

      it 'returns blocking reads' do
        expect(described_class.blocking_branch_modification).to contain_exactly(blocking_read)
      end
    end

    describe '.prevent_pushing_and_force_pushing' do
      let_it_be(:non_blocking_read) { create(:scan_result_policy_read) }
      let_it_be(:blocking_read) do
        create(:scan_result_policy_read, project_approval_settings: { prevent_pushing_and_force_pushing: true })
      end

      it 'returns blocking reads' do
        expect(described_class.prevent_pushing_and_force_pushing).to contain_exactly(blocking_read)
      end
    end

    describe '.for_policy_configuration' do
      let_it_be(:policy_configuration_1) { create(:security_orchestration_policy_configuration) }
      let_it_be(:policy_configuration_2) { create(:security_orchestration_policy_configuration) }

      let_it_be(:scan_result_policy_1) do
        create(:scan_result_policy_read,
          security_orchestration_policy_configuration: policy_configuration_1,
          orchestration_policy_idx: 0,
          rule_idx: 1
        )
      end

      let_it_be(:scan_result_policy_2) do
        create(:scan_result_policy_read,
          security_orchestration_policy_configuration: policy_configuration_2,
          orchestration_policy_idx: 1,
          rule_idx: 2
        )
      end

      it 'returns policies for the specified policy configuration' do
        expect(
          described_class.for_policy_configuration(policy_configuration_1)
        ).to contain_exactly(scan_result_policy_1)
      end
    end

    describe '.for_policy_index' do
      let_it_be(:approval_policy) do
        create(:scan_result_policy_read, orchestration_policy_idx: 1)
      end

      it 'returns policies with matching orchestration policy index' do
        expect(described_class.for_policy_index(1)).to contain_exactly(approval_policy)
      end

      it 'returns empty when no matching policy index exists' do
        expect(described_class.for_policy_index(99)).to be_empty
      end
    end

    describe '.for_rule_index' do
      let_it_be(:approval_policy) do
        create(:scan_result_policy_read, rule_idx: 1)
      end

      it 'returns policies with matching rule index' do
        expect(described_class.for_rule_index(1)).to contain_exactly(approval_policy)
      end

      it 'returns empty when no matching rule index exists' do
        expect(described_class.for_rule_index(99)).to be_empty
      end
    end

    describe '.for_approval_policy_rules' do
      let_it_be(:approval_policy_rule_1) { create(:approval_policy_rule) }
      let_it_be(:approval_policy_rule_2) { create(:approval_policy_rule) }
      let_it_be(:scan_result_policy_1) do
        create(:scan_result_policy_read, approval_policy_rule: approval_policy_rule_1)
      end

      let_it_be(:scan_result_policy_2) do
        create(:scan_result_policy_read, approval_policy_rule: approval_policy_rule_2)
      end

      let_it_be(:scan_result_policy_3) { create(:scan_result_policy_read) }

      it 'returns policies for the specified approval policy rules' do
        expect(
          described_class.for_approval_policy_rules([approval_policy_rule_1])
        ).to contain_exactly(scan_result_policy_1)
      end

      it 'returns policies for multiple approval policy rules' do
        expect(
          described_class.for_approval_policy_rules([approval_policy_rule_1, approval_policy_rule_2])
        ).to contain_exactly(scan_result_policy_1, scan_result_policy_2)
      end

      it 'returns empty when no matching approval policy rules exist' do
        expect(
          described_class.for_approval_policy_rules([create(:approval_policy_rule)])
        ).to be_empty
      end
    end

    describe '.without_warn_mode_policy' do
      let_it_be(:read_without_approval_policy_rule) do
        create(:scan_result_policy_read)
      end

      let_it_be(:read_default) do
        create(:scan_result_policy_read,
          approval_policy_rule: create(:approval_policy_rule, security_policy: create(:security_policy)))
      end

      let_it_be(:read_warn_mode) do
        create(:scan_result_policy_read,
          approval_policy_rule: create(:approval_policy_rule,
            security_policy: create(:security_policy, :enforcement_type_warn)))
      end

      let_it_be(:read_default_mode) do
        create(:scan_result_policy_read,
          approval_policy_rule: create(:approval_policy_rule,
            security_policy: create(:security_policy, :enforcement_type_enforce)))
      end

      subject(:without_warn_mode_policy) { described_class.without_warn_mode_policy }

      it { is_expected.to contain_exactly(read_without_approval_policy_rule, read_default, read_default_mode) }
    end
  end

  describe '#newly_detected?' do
    subject { scan_result_policy_read.newly_detected? }

    context 'when license_states contains newly_detected' do
      let_it_be(:scan_result_policy_read, freeze: false) do
        create(:scan_result_policy_read, license_states: ['newly_detected'])
      end

      it { is_expected.to be_truthy }
    end

    context 'when license_states does not contain newly_detected' do
      let_it_be(:scan_result_policy_read, freeze: false) do
        create(:scan_result_policy_read, license_states: ['detected'])
      end

      it { is_expected.to be_falsey }
    end
  end

  describe '#only_newly_detected_licenses?' do
    subject { scan_result_policy_read.only_newly_detected_licenses? }

    context 'when license_states contains newly_detected' do
      let_it_be(:scan_result_policy_read, freeze: false) do
        create(:scan_result_policy_read, license_states: ['newly_detected'])
      end

      it { is_expected.to be_truthy }
    end

    context 'when license_states contains both newly_detected and detected' do
      let_it_be(:scan_result_policy_read, freeze: false) do
        create(:scan_result_policy_read, license_states: %w[newly_detected detected])
      end

      it { is_expected.to be_falsey }
    end

    context 'when license_states does not contain newly_detected' do
      let_it_be(:scan_result_policy_read, freeze: false) do
        create(:scan_result_policy_read, license_states: ['detected'])
      end

      it { is_expected.to be_falsey }
    end
  end

  describe '#approval_policy_rule' do
    let(:approval_policy) { create(:scan_result_policy_read) }
    let(:policy_configuration) { approval_policy.security_orchestration_policy_configuration }

    context 'when approval_policy_rule_id is present' do
      let_it_be(:approval_policy_rule) { create(:approval_policy_rule) }
      let_it_be(:approval_policy) do
        create(:scan_result_policy_read, approval_policy_rule: approval_policy_rule)
      end

      it 'returns the associated approval_policy_rule' do
        expect(approval_policy.approval_policy_rule).to eq(approval_policy_rule)
      end
    end

    context 'when real_policy_index is negative' do
      before do
        allow(approval_policy).to receive(:real_policy_index).and_return(-1)
      end

      it 'returns nil' do
        expect(approval_policy.approval_policy_rule).to be_nil
      end
    end

    context 'when real_policy_index is non-negative' do
      let(:real_policy_index) { 1 }
      let(:rule_idx) { 2 }
      let(:approval_policy_rule) { instance_double(Security::ApprovalPolicyRule) }

      before do
        allow(approval_policy).to receive(:real_policy_index).and_return(real_policy_index)
        allow(approval_policy).to receive(:rule_idx).and_return(rule_idx)
        allow(Security::ApprovalPolicyRule).to receive(:by_policy_rule_index).and_return(approval_policy_rule)
      end

      it 'calls Security::ApprovalPolicyRule.by_policy_rule_index with correct arguments' do
        expect(Security::ApprovalPolicyRule).to receive(:by_policy_rule_index)
          .with(policy_configuration, policy_index: real_policy_index, rule_index: rule_idx)

        approval_policy.approval_policy_rule
      end

      it 'returns the result from Security::ApprovalPolicyRule.by_policy_rule_index' do
        expect(approval_policy.approval_policy_rule).to eq(approval_policy_rule)
      end
    end
  end

  describe '#real_policy_index' do
    let_it_be(:project) { create(:project) }
    let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration) }
    let_it_be(:scan_result_policy_read, freeze: false) do
      create(:scan_result_policy_read,
        project: project,
        security_orchestration_policy_configuration: policy_configuration,
        orchestration_policy_idx: 1)
    end

    let_it_be(:policy_0) do
      create(:security_policy, security_orchestration_policy_configuration: policy_configuration, policy_index: 0,
        enabled: true)
    end

    let_it_be(:policy_1) do
      create(:security_policy, security_orchestration_policy_configuration: policy_configuration, policy_index: 1,
        enabled: false)
    end

    let_it_be(:policy_2) do
      create(:security_policy, security_orchestration_policy_configuration: policy_configuration, policy_index: 2,
        enabled: true)
    end

    let_it_be(:policy_3) do
      create(:security_policy, security_orchestration_policy_configuration: policy_configuration, policy_index: 3,
        enabled: true)
    end

    let(:policy_scope_checker) { instance_double(Security::SecurityOrchestrationPolicies::PolicyScopeChecker) }

    before do
      allow(Security::SecurityOrchestrationPolicies::PolicyScopeChecker).to receive(:new)
        .with(project: project).and_return(policy_scope_checker)
      scan_result_policy_read.clear_memoization(:real_policy_index)
    end

    context 'when all policies are applicable' do
      before do
        allow(policy_scope_checker).to receive(:security_policy_applicable?).and_return(true)
      end

      it 'returns the correct index' do
        expect(scan_result_policy_read.real_policy_index).to eq(2)
      end
    end

    context 'when some policies are not applicable' do
      before do
        allow(policy_scope_checker).to receive(:security_policy_applicable?).and_return(true)
        allow(policy_scope_checker).to receive(:security_policy_applicable?).with(policy_2).and_return(false)
      end

      it 'returns the correct index' do
        expect(scan_result_policy_read.real_policy_index).to eq(3)
      end
    end

    context 'when the target policy is not found' do
      let_it_be(:scan_result_policy_read, freeze: false) do
        create(:scan_result_policy_read,
          project: project,
          security_orchestration_policy_configuration: policy_configuration,
          orchestration_policy_idx: 10)
      end

      before do
        allow(policy_scope_checker).to receive(:security_policy_applicable?).and_return(true)
      end

      it 'returns negative index' do
        expect(scan_result_policy_read.real_policy_index).to eq(-1)
      end
    end
  end

  describe '#custom_role_ids_with_permission' do
    let_it_be(:project) { create(:project) }
    let_it_be(:group) { create(:group) }

    subject(:custom_role_ids_with_permission) { scan_result_policy_read.custom_role_ids_with_permission }

    context 'when on gitlab.com' do
      let_it_be(:role_with_permission) { create(:member_role, :admin_merge_request, namespace: group) }
      let_it_be(:role_without_permission) { create(:member_role, :guest, namespace: group) }
      let_it_be(:base_role_with_permission) { create(:member_role, :developer, namespace: group) }
      let_it_be(:scan_result_policy_read, freeze: false) do
        create(:scan_result_policy_read, project: project,
          custom_roles: [role_with_permission.id, role_without_permission.id, base_role_with_permission.id])
      end

      before do
        allow(scan_result_policy_read).to receive(:gitlab_com_subscription?).and_return(true)
        allow(project).to receive(:root_ancestor).and_return(group)
      end

      it { is_expected.to contain_exactly(role_with_permission.id, base_role_with_permission.id) }
    end

    context 'when not on gitlab.com' do
      let_it_be(:role_with_permission) { create(:member_role, :admin_merge_request, :instance) }
      let_it_be(:role_without_permission) { create(:member_role, :guest, :instance) }
      let_it_be(:base_role_with_permission) { create(:member_role, :developer, :instance) }
      let_it_be(:scan_result_policy_read, freeze: false) do
        create(:scan_result_policy_read, project: project,
          custom_roles: [role_with_permission.id, role_without_permission.id, base_role_with_permission.id])
      end

      before do
        allow(scan_result_policy_read).to receive(:gitlab_com_subscription?).and_return(false)
      end

      it { is_expected.to contain_exactly(role_with_permission.id, base_role_with_permission.id) }
    end
  end

  describe '.for_project' do
    let_it_be(:project) { create(:project) }
    let_it_be(:scan_result_policy_read_1) { create(:scan_result_policy_read, project: project) }
    let_it_be(:scan_result_policy_read_2) { create(:scan_result_policy_read, project: project) }
    let_it_be(:scan_result_policy_read_3) { create(:scan_result_policy_read) }

    subject { described_class.for_project(project) }

    it 'returns records for given projects' do
      is_expected.to contain_exactly(scan_result_policy_read_1, scan_result_policy_read_2)
    end
  end

  describe '#vulnerability_age' do
    let_it_be(:scan_result_policy_read, freeze: false) do
      create(:scan_result_policy_read, age_operator: 'less_than', age_interval: 'day', age_value: 1)
    end

    subject { scan_result_policy_read.vulnerability_age }

    context 'when vulnerability age attributes are present' do
      it { is_expected.to eq({ operator: :less_than, interval: :day, value: 1 }) }
    end

    context 'when vulnerability age attributes are not present' do
      let_it_be(:scan_result_policy_read, freeze: false) do
        create(:scan_result_policy_read)
      end

      it { is_expected.to eq({}) }
    end
  end

  describe '#bot_message_disabled?' do
    subject { scan_result_policy_read.bot_message_disabled? }

    let_it_be(:project) { create(:project) }
    let_it_be(:configuration) { create(:security_orchestration_policy_configuration, project: project) }
    let(:scan_result_policy_read) do
      create(:scan_result_policy_read, :with_send_bot_message, project: project, bot_message_enabled: false)
    end

    it { is_expected.to be true }

    context 'when send_bot_message data is present and enabled is true' do
      let(:scan_result_policy_read) do
        create(:scan_result_policy_read, :with_send_bot_message, project: project, bot_message_enabled: true)
      end

      it { is_expected.to be false }
    end

    context 'when send_bot_message data is not present' do
      let(:scan_result_policy_read) { create(:scan_result_policy_read, project: project) }

      it { is_expected.to be false }
    end
  end

  describe "#fail_open?" do
    subject(:fail_open) { read.fail_open? }

    context "when failing open" do
      let(:read) { create(:scan_result_policy_read, :fail_open) }

      it { is_expected.to be(true) }
    end

    context "when failing closed" do
      let(:read) { create(:scan_result_policy_read, :fail_closed) }

      it { is_expected.to be(false) }
    end

    context "without fallback_behavior" do
      let(:read) { create(:scan_result_policy_read) }

      it { is_expected.to be(false) }
    end
  end

  describe "#unblock_rules_using_execution_policies?" do
    let_it_be(:project) { create(:project) }
    let_it_be(:security_orchestration_policy_configuration) { create(:security_orchestration_policy_configuration) }
    let(:read) do
      create(:scan_result_policy_read,
        project: project,
        security_orchestration_policy_configuration: security_orchestration_policy_configuration,
        **read_attributes)
    end

    subject { read.unblock_rules_using_execution_policies? }

    context "when unblock_rules_using_execution_policies is set as true" do
      let(:read_attributes) { { policy_tuning: { unblock_rules_using_execution_policies: true } } }

      it { is_expected.to be(true) }
    end

    context "when unblock_rules_using_execution_policies is set as false" do
      let(:read_attributes) { { policy_tuning: { unblock_rules_using_execution_policies: false } } }

      it { is_expected.to be(false) }
    end

    context "without unblock_rules_using_execution_policies" do
      let(:read_attributes) { { policy_tuning: {} } }

      it { is_expected.to be(false) }
    end

    context "without policy_tuning" do
      let(:read_attributes) { {} }

      it { is_expected.to be(false) }
    end
  end

  describe '#prevent_approval_by_author?' do
    subject(:prevent_approval_by_author) { policy_read.prevent_approval_by_author? }

    context 'with approval setting' do
      let_it_be(:policy_read) { create(:scan_result_policy_read, :prevent_approval_by_author) }

      it { is_expected.to be(true) }
    end

    context 'without approval setting' do
      let_it_be(:policy_read) { create(:scan_result_policy_read) }

      it { is_expected.to be(false) }
    end
  end

  describe '#prevent_approval_by_commit_author?' do
    subject(:prevent_approval_by_commit_author) { policy_read.prevent_approval_by_commit_author? }

    context 'with approval setting' do
      let_it_be(:policy_read) { create(:scan_result_policy_read, :prevent_approval_by_commit_author) }

      it { is_expected.to be(true) }
    end

    context 'without approval setting' do
      let_it_be(:policy_read) { create(:scan_result_policy_read) }

      it { is_expected.to be(false) }
    end
  end

  describe 'namespace_id assignment trigger (trigger_b83b7e51e2f5)' do
    let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, :namespace) }

    context 'when project_id is present' do
      it 'does not populate namespace_id from the policy configuration' do
        record = create(:scan_result_policy_read,
          security_orchestration_policy_configuration: policy_configuration,
          project: create(:project),
          namespace_id: nil)

        expect(record.reload.namespace_id).to be_nil
      end
    end

    context 'when project_id is absent' do
      it 'populates namespace_id from the policy configuration' do
        record = create(:scan_result_policy_read,
          security_orchestration_policy_configuration: policy_configuration,
          project: nil,
          namespace_id: nil)

        expect(record.reload.namespace_id).to eq(policy_configuration.namespace_id)
      end
    end
  end
end
