# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::ApprovalPolicy, feature_category: :security_policy_management do
  let(:policy_content) do
    {
      enforcement_type: 'warn',
      fallback_behavior: { fail: 'open' },
      policy_tuning: { security_report_time_window: 7 },
      bypass_settings: {
        branches: [{ source: { name: 'feature' }, target: { name: 'main' } }]
      },
      actions: [{ type: 'require_approval', role_approvers: ['developer'], approvals_required: 2 }],
      approval_settings: { prevent_approval_by_author: true }
    }
  end

  let(:scope) do
    { groups: { including: [{ id: 1 }] }, projects: { excluding: [{ id: 5 }] } }
  end

  let(:policy_record) do
    create(:security_policy, :approval_policy,
      name: 'Test Approval Policy',
      description: 'Test Description',
      enabled: true,
      scope: scope.as_json,
      content: policy_content,
      approval_policy_rule_traits: [])
  end

  let(:approval_policy) { described_class.new(policy_record) }

  describe '#enforcement_type' do
    subject(:enforcement_type) { approval_policy.enforcement_type }

    it 'returns an EnforcementType instance with correct values' do
      expect(enforcement_type).to be_a(Security::ScanResultPolicies::EnforcementType)

      expect(enforcement_type.warn?).to be(true)
    end

    it 'passes the enforcement_type data from policy_content' do
      expect(Security::ScanResultPolicies::EnforcementType).to receive(:new).with('warn')

      enforcement_type
    end

    context 'when enforcement_type is not present in policy_content' do
      let(:policy_content) { {} }

      it 'returns an EnforcementType instance with default values' do
        expect(enforcement_type.enforce?).to be(true)
      end

      it 'passes nil to EnforcementType which defaults to enforce' do
        expect(Security::ScanResultPolicies::EnforcementType).to receive(:new).with(nil)

        enforcement_type
      end
    end
  end

  describe '#fallback_behavior' do
    subject(:fallback_behavior) { approval_policy.fallback_behavior }

    it 'returns a FallbackBehavior instance with correct values' do
      expect(fallback_behavior).to be_a(Security::ScanResultPolicies::FallbackBehavior)

      expect(fallback_behavior.fail_open?).to be(true)
    end

    it 'passes the fallback_behavior data from policy_content' do
      expect(Security::ScanResultPolicies::FallbackBehavior).to receive(:new).with({ fail: 'open' })

      fallback_behavior
    end

    context 'when fallback_behavior is not present in policy_content' do
      let(:policy_content) { {} }

      it 'returns a FallbackBehavior instance with default values' do
        expect(fallback_behavior.fail_open?).to be_falsey
      end

      it 'passes an empty hash to FallbackBehavior' do
        expect(Security::ScanResultPolicies::FallbackBehavior).to receive(:new).with({})

        fallback_behavior
      end
    end
  end

  describe '#policy_tuning' do
    subject(:policy_tuning) { approval_policy.policy_tuning }

    it 'returns a PolicyTuning instance with correct values' do
      expect(policy_tuning).to be_a(Security::ScanResultPolicies::PolicyTuning)

      expect(policy_tuning.security_report_time_window).to eq(7)
    end

    it 'passes the policy_tuning data from policy_content' do
      expect(Security::ScanResultPolicies::PolicyTuning).to receive(:new).with({ security_report_time_window: 7 })

      policy_tuning
    end

    context 'when policy_tuning is not present in policy_content' do
      let(:policy_content) { {} }

      it 'returns a PolicyTuning instance with default values' do
        expect(policy_tuning.security_report_time_window).to be_nil
      end

      it 'passes an empty hash to PolicyTuning' do
        expect(Security::ScanResultPolicies::PolicyTuning).to receive(:new).with({})

        policy_tuning
      end
    end
  end

  describe '#bypass_settings' do
    subject(:bypass_settings) { approval_policy.bypass_settings }

    it 'returns a BypassSettings instance with correct values' do
      expect(bypass_settings).to be_a(Security::ScanResultPolicies::BypassSettings)

      expect(bypass_settings.branches).to match_array([{ source: { name: 'feature' }, target: { name: 'main' } }])
    end

    it 'passes the bypass_settings data from policy_content' do
      expect(Security::ScanResultPolicies::BypassSettings).to receive(:new).with({ branches: [{
        source: { name: 'feature' }, target: { name: 'main' }
      }] })

      bypass_settings
    end

    context 'when bypass_settings is not present in policy_content' do
      let(:policy_content) { {} }

      it 'returns a BypassSettings instance with default values' do
        expect(bypass_settings.branches).to be_empty
      end

      it 'passes an empty hash to BypassSettings' do
        expect(Security::ScanResultPolicies::BypassSettings).to receive(:new).with({})

        bypass_settings
      end
    end
  end

  describe '#actions' do
    subject(:actions) { approval_policy.actions }

    it 'returns an Actions instance with correct values' do
      expect(actions).to be_a(Security::ScanResultPolicies::Actions)

      expect(actions.require_approval_actions.first.approvals_required).to eq(2)
      expect(actions.require_approval_actions.first.role_approvers).to match_array(['developer'])
    end

    it 'passes the actions data from policy_content' do
      expect(Security::ScanResultPolicies::Actions).to receive(:new).with(
        [{ type: 'require_approval', role_approvers: ['developer'], approvals_required: 2 }]
      )

      actions
    end

    context 'when actions is not present in policy_content' do
      let(:policy_content) { {} }

      it 'returns an empty Actions instance' do
        expect(actions.require_approval_actions).to be_empty
      end

      it 'passes an empty array to Actions' do
        expect(Security::ScanResultPolicies::Actions).to receive(:new).with([])

        actions
      end
    end
  end

  describe '#approval_settings' do
    subject(:approval_settings) { approval_policy.approval_settings }

    it 'returns an ApprovalSettings instance with correct values' do
      expect(approval_settings).to be_a(Security::ScanResultPolicies::ApprovalSettings)

      expect(approval_settings.prevent_approval_by_author).to be(true)
    end

    it 'passes the approval_settings data from policy_content' do
      expect(Security::ScanResultPolicies::ApprovalSettings).to receive(:new).with({ prevent_approval_by_author: true })

      approval_settings
    end

    context 'when approval_settings is not present in policy_content' do
      let(:policy_content) { {} }

      it 'returns an ApprovalSettings instance with default values' do
        expect(approval_settings.prevent_approval_by_author).to be_nil
      end

      it 'passes an empty hash to ApprovalSettings' do
        expect(Security::ScanResultPolicies::ApprovalSettings).to receive(:new).with({})

        approval_settings
      end
    end
  end

  describe '#fail_open?' do
    subject { approval_policy.fail_open? }

    it { is_expected.to be(true) }

    context 'when fallback_behavior is closed' do
      before do
        policy_content[:fallback_behavior] = { fail: 'closed' }
      end

      it { is_expected.to be(false) }
    end

    context 'when fallback_behavior is missing' do
      before do
        policy_content.delete(:fallback_behavior)
      end

      it { is_expected.to be_falsey }
    end
  end

  describe '#bot_message_disabled?' do
    subject { approval_policy.bot_message_disabled? }

    context 'when send_bot_message action is explicitly disabled' do
      before do
        policy_content[:actions] << { type: 'send_bot_message', enabled: false }
      end

      it { is_expected.to be(true) }
    end

    context 'when send_bot_message action is enabled' do
      before do
        policy_content[:actions] << { type: 'send_bot_message', enabled: true }
      end

      it { is_expected.to be(false) }
    end

    context 'when send_bot_message action is missing' do
      it { is_expected.to be(false) }
    end
  end

  describe '#unblock_rules_using_execution_policies?' do
    subject { approval_policy.unblock_rules_using_execution_policies? }

    context 'when set to true' do
      before do
        policy_content[:policy_tuning] = { unblock_rules_using_execution_policies: true }
      end

      it { is_expected.to be(true) }
    end

    context 'when unset' do
      it { is_expected.to be(false) }
    end
  end

  describe '#prevent_approval_by_author?' do
    subject { approval_policy.prevent_approval_by_author? }

    it { is_expected.to be(true) }

    context 'when approval_settings is missing' do
      before do
        policy_content.delete(:approval_settings)
      end

      it { is_expected.to be(false) }
    end
  end

  describe '#prevent_approval_by_commit_author?' do
    subject { approval_policy.prevent_approval_by_commit_author? }

    context 'when set to true' do
      before do
        policy_content[:approval_settings] = { prevent_approval_by_commit_author: true }
      end

      it { is_expected.to be(true) }
    end

    context 'when unset' do
      it { is_expected.to be(false) }
    end
  end

  describe '#rules' do
    subject(:rules) { approval_policy.rules }

    let!(:approval_policy_rule) do
      create(:approval_policy_rule,
        security_policy: policy_record,
        content: {
          branches: ['main'],
          scanners: %w[container_scanning],
          vulnerabilities_allowed: 0,
          severity_levels: %w[critical],
          vulnerability_states: %w[detected]
        })
    end

    let(:expected_rule_content) do
      {
        branches: ['main'],
        scanners: %w[container_scanning],
        type: "scan_finding",
        vulnerabilities_allowed: 0,
        severity_levels: %w[critical],
        vulnerability_states: %w[detected]
      }
    end

    it 'returns a Rules instance with correct values' do
      expect(rules).to be_a(Security::ScanResultPolicies::Rules)

      rule = rules.rules.first
      expect(rule).to be_a(Security::ScanResultPolicies::Rule)
      expect(rule.branches).to eq(expected_rule_content[:branches])
    end

    it 'passes the rules data from policy_record.rules' do
      expect(Security::ScanResultPolicies::Rules).to receive(:new).with([expected_rule_content])

      rules
    end

    context 'when rules is not present in policy_record' do
      before do
        Security::ApprovalPolicyRule.where(security_policy: policy_record).delete_all
      end

      it 'passes an empty array to Rules' do
        expect(rules.rules).to be_empty
      end

      it 'passes an empty array to Rules' do
        expect(Security::ScanResultPolicies::Rules).to receive(:new).with([])

        rules
      end
    end
  end

  describe 'inherited methods from BaseSecurityPolicy' do
    it 'delegates name to policy_record' do
      expect(approval_policy.name).to eq('Test Approval Policy')
    end

    it 'delegates description to policy_record' do
      expect(approval_policy.description).to eq('Test Description')
    end

    it 'delegates enabled to policy_record' do
      expect(approval_policy.enabled).to be true
    end

    describe '#policy_scope' do
      subject(:policy_scope) { approval_policy.policy_scope }

      it 'returns a PolicyScope instance with correct values' do
        expect(policy_scope).to be_a(Security::PolicyScope)

        expect(policy_scope.projects).to eq({ excluding: [{ id: 5 }] })
        expect(policy_scope.groups).to eq({ including: [{ id: 1 }] })
      end

      it 'passes the policy scope data to PolicyScope' do
        expect(Security::PolicyScope).to receive(:new).with(scope)

        policy_scope
      end

      context 'when scope is not present in policy' do
        let(:scope) { {} }

        it 'returns a PolicyScope instance with default values' do
          expect(policy_scope.projects).to eq({})
          expect(policy_scope.groups).to eq({})
        end

        it 'passes an empty hash to PolicyScope' do
          expect(Security::PolicyScope).to receive(:new).with({})

          policy_scope
        end
      end
    end
  end
end
