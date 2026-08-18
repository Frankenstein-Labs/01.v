# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ApprovalPolicySource, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
  let_it_be(:security_policy) do
    create(:security_policy, :approval_policy,
      security_orchestration_policy_configuration: policy_configuration,
      linked_projects: [project])
  end

  let_it_be(:approval_policy_rule) { create(:approval_policy_rule, :scan_finding, security_policy: security_policy) }
  let_it_be(:scan_result_policy_read) do
    create(:scan_result_policy_read,
      project: project,
      security_orchestration_policy_configuration: policy_configuration)
  end

  def build_source(action_idx: 0, project: self.project, scan_result_policy_read: nil, approval_policy_rule: nil)
    described_class.new(
      action_idx: action_idx,
      project: project,
      scan_result_policy_read: scan_result_policy_read,
      approval_policy_rule: approval_policy_rule
    )
  end

  describe 'source routing' do
    context 'when approval_policy_rule is present and flag is enabled' do
      subject(:source) { build_source(approval_policy_rule: approval_policy_rule) }

      it 'forwards delegated calls to approval_policy_rule' do
        expect(approval_policy_rule).to receive(:fail_open?).and_return(true)

        expect(source.fail_open?).to be(true)
      end

      it 'resolves to approval_policy_rule' do
        expect(source.resolved_approval_policy_rule).to eq(approval_policy_rule)
      end
    end

    context 'when flag is disabled' do
      before do
        stub_feature_flags(deprecate_scan_result_policies: false)
      end

      subject(:source) do
        build_source(
          approval_policy_rule: approval_policy_rule,
          scan_result_policy_read: scan_result_policy_read
        )
      end

      it 'forwards delegated calls to scan_result_policy_read' do
        expect(scan_result_policy_read).to receive(:fail_open?).and_return(false)

        expect(source.fail_open?).to be(false)
      end

      it 'resolves via scan_result_policy_read' do
        expect(source.resolved_approval_policy_rule)
          .to eq(scan_result_policy_read.approval_policy_rule)
      end
    end

    context 'when only scan_result_policy_read is present (flag on)' do
      subject(:source) { build_source(scan_result_policy_read: scan_result_policy_read) }

      it 'forwards delegated calls to scan_result_policy_read' do
        expect(scan_result_policy_read).to receive(:bot_message_disabled?).and_return(true)

        expect(source.bot_message_disabled?).to be(true)
      end
    end
  end

  describe 'source presence' do
    it 'is true when either source is set' do
      expect(build_source(approval_policy_rule: approval_policy_rule).has_source?).to be(true)
      expect(build_source(scan_result_policy_read: scan_result_policy_read).has_source?).to be(true)
    end

    it 'is false when neither source is set' do
      expect(build_source.has_source?).to be(false)
    end
  end

  describe 'underlying source ids' do
    it 'returns the underlying ids when present' do
      source = build_source(
        approval_policy_rule: approval_policy_rule,
        scan_result_policy_read: scan_result_policy_read
      )

      expect(source.scan_result_policy_id).to eq(scan_result_policy_read.id)
      expect(source.approval_policy_rule_id).to eq(approval_policy_rule.id)
    end

    it 'returns nil when the source is absent' do
      source = build_source

      expect(source.scan_result_policy_id).to be_nil
      expect(source.approval_policy_rule_id).to be_nil
    end
  end

  describe 'collection defaults and action_idx forwarding' do
    it 'returns empty defaults when the source is absent' do
      source = build_source

      expect(source.role_approvers).to eq([])
      expect(source.custom_roles).to eq([])
      expect(source.custom_role_ids_with_permission).to eq([])
      expect(source.license_states).to eq([])
      expect(source.licenses).to eq({})
    end

    it 'delegates license_states and licenses to approval_policy_rule when flag is on' do
      source = build_source(approval_policy_rule: approval_policy_rule)

      expect(approval_policy_rule).to receive(:license_states).and_return(%w[newly_detected])
      expect(approval_policy_rule).to receive(:licenses).and_return('denied' => [{ 'name' => 'MIT' }])

      expect(source.license_states).to eq(%w[newly_detected])
      expect(source.licenses).to eq('denied' => [{ 'name' => 'MIT' }])
    end

    it 'passes action_idx when delegating role_approvers / custom_roles' do
      source = build_source(action_idx: 3, approval_policy_rule: approval_policy_rule)

      expect(approval_policy_rule).to receive(:role_approvers).with(action_idx: 3).and_return([])
      expect(approval_policy_rule).to receive(:custom_roles).with(action_idx: 3).and_return([])

      source.role_approvers
      source.custom_roles
    end

    it 'returns scan_result_policy_read values when flag is disabled' do
      stub_feature_flags(deprecate_scan_result_policies: false)
      srp = create(:scan_result_policy_read,
        project: project,
        security_orchestration_policy_configuration: policy_configuration,
        role_approvers: [Gitlab::Access::DEVELOPER],
        custom_roles: [42],
        license_states: %w[newly_detected],
        licenses: { 'denied' => [{ 'name' => 'MIT' }] })
      source = build_source(scan_result_policy_read: srp)

      expect(source.role_approvers).to eq([Gitlab::Access::DEVELOPER])
      expect(source.custom_roles).to eq([42])
      expect(source.license_states).to eq(%w[newly_detected])
      expect(source.licenses).to eq('denied' => [{ 'name' => 'MIT' }])
    end
  end

  describe 'custom role permission lookup' do
    context 'when project is nil' do
      subject(:source) { build_source(project: nil, approval_policy_rule: approval_policy_rule) }

      it 'returns an empty array' do
        expect(source.custom_role_ids_with_permission).to eq([])
      end
    end

    context 'when on gitlab.com subscription', :saas do
      let_it_be(:group) { create(:group_with_plan, plan: :ultimate_plan) }
      let_it_be(:saas_project) { create(:project, group: group) }
      let_it_be(:member_role) { create(:member_role, :guest, namespace: group, admin_merge_request: true) }
      let_it_be(:saas_policy_config) do
        create(:security_orchestration_policy_configuration, project: saas_project)
      end

      let_it_be(:saas_security_policy) do
        create(:security_policy, :require_approval,
          security_orchestration_policy_configuration: saas_policy_config,
          content: {
            'actions' => [
              { 'type' => 'require_approval', 'approvals_required' => 1,
                'role_approvers' => [member_role.id] }
            ]
          })
      end

      let(:saas_apr) { create(:approval_policy_rule, security_policy: saas_security_policy) }

      subject(:source) { build_source(project: saas_project, approval_policy_rule: saas_apr) }

      it 'looks up member_roles from root ancestor' do
        expect(source.custom_role_ids_with_permission).to include(member_role.id)
      end
    end
  end

  describe 'resolved policy metadata' do
    it 'reads from the resolved security_policy when a rule is available' do
      allow(security_policy).to receive_messages(warn_mode?: true, security_report_time_window: 7)
      source = build_source(approval_policy_rule: approval_policy_rule)

      expect(source.policy_name('fallback')).to eq(security_policy.name)
      expect(source.warn_mode_policy?).to be(true)
      expect(source.security_report_time_window).to eq(7)
    end

    it 'falls back to safe defaults when no source rule is available' do
      source = build_source

      expect(source.policy_name('My Policy 3')).to eq('My Policy')
      expect(source.warn_mode_policy?).to be(false)
      expect(source.security_report_time_window).to be_nil
    end
  end

  describe 'scanner configurations' do
    it 'returns scanner configs from the resolved rule when overrides are present' do
      rule_obj = approval_policy_rule.rule
      config_hash = { type: 'container_scanning', severity_levels: %w[critical] }
      allow(rule_obj).to receive_messages(has_scanner_overrides?: true,
        scanner_configurations: [instance_double(Security::ScanResultPolicies::ScannerConfig, to_h: config_hash)])
      allow(approval_policy_rule).to receive(:rule).and_return(rule_obj)

      expect(build_source(approval_policy_rule: approval_policy_rule).scanner_configurations)
        .to eq([config_hash])
    end

    it 'returns nil when no source rule is available' do
      expect(build_source.scanner_configurations).to be_nil
    end
  end
end
