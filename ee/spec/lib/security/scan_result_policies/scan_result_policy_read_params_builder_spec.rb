# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::ScanResultPolicyReadParamsBuilder, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:security_orchestration_policy_configuration) do
    create(:security_orchestration_policy_configuration, project: project)
  end

  let(:security_policy) do
    build(:security_policy,
      security_orchestration_policy_configuration: security_orchestration_policy_configuration,
      policy_index: 0,
      content: policy_content)
  end

  let(:approval_policy_rule) do
    build(:approval_policy_rule, :scan_finding, security_policy: security_policy, rule_index: 0)
  end

  let(:action_index) { 0 }
  let(:approval_action) do
    {
      type: 'require_approval',
      approvals_required: 1,
      role_approvers: ['maintainer', 'developer', 42]
    }
  end

  let(:policy_content) do
    {
      approval_settings: {},
      fallback_behavior: {},
      policy_tuning: {},
      actions: [
        approval_action,
        {
          type: 'send_bot_message',
          enabled: true
        }
      ]
    }
  end

  let(:builder) do
    described_class.new(
      project: project,
      security_policy: security_policy,
      approval_policy_rule: approval_policy_rule,
      action_index: action_index,
      approval_action: approval_action
    )
  end

  describe '#build' do
    subject(:params) { builder.build }

    it 'returns hash with correct parameters', :aggregate_failures do
      expect(params).to include(
        orchestration_policy_idx: 0,
        rule_idx: 0,
        action_idx: 0,
        match_on_inclusion_license: false,
        role_approvers: [Gitlab::Access::MAINTAINER, Gitlab::Access::DEVELOPER],
        custom_roles: [42],
        vulnerability_attributes: nil,
        project_id: project.id,
        age_operator: nil,
        age_interval: nil,
        age_value: nil,
        commits: nil,
        license_states: nil,
        project_approval_settings: {},
        send_bot_message: { enabled: true },
        fallback_behavior: {},
        policy_tuning: {},
        approval_policy_rule_id: approval_policy_rule.id,
        malicious_rule: false
      )
    end

    context 'when match_on_inclusion_license is not set' do
      before do
        approval_policy_rule.content.delete('match_on_inclusion_license')
      end

      it 'defaults to false' do
        expect(params[:match_on_inclusion_license]).to be false
      end
    end

    context 'when role_approvers is not set' do
      let(:approval_action) { { type: 'require_approval', approvals_required: 1 } }

      it 'returns empty arrays for role_approvers and custom_roles' do
        expect(params[:role_approvers]).to be_empty
        expect(params[:custom_roles]).to be_empty
      end
    end

    context 'when send_bot_message action is not present' do
      let(:policy_content) do
        {
          actions: [approval_action]
        }
      end

      it 'returns empty hash for send_bot_message' do
        expect(params[:send_bot_message]).to eq({})
      end
    end

    context 'when optional policy settings are not present' do
      let(:policy_content) do
        {
          actions: [approval_action]
        }
      end

      it 'returns empty hashes for optional settings' do
        expect(params[:project_approval_settings]).to eq({})
        expect(params[:fallback_behavior]).to eq({})
        expect(params[:policy_tuning]).to eq({})
      end
    end

    describe 'malicious_rule' do
      before do
        approval_policy_rule.content = rule_content
      end

      context 'when scanners contains a hash with is_malicious set to true' do
        let(:rule_content) do
          {
            type: 'scan_finding',
            scanners: [{ name: 'sast', is_malicious: true }]
          }
        end

        it 'is true' do
          expect(params[:malicious_rule]).to be true
        end
      end

      context 'when scanners is absent' do
        let(:rule_content) { { type: 'scan_finding' } }

        it 'is false' do
          expect(params[:malicious_rule]).to be false
        end
      end

      context 'when scanners is nil' do
        let(:rule_content) { { type: 'scan_finding', scanners: nil } }

        it 'is false' do
          expect(params[:malicious_rule]).to be false
        end
      end

      context 'when scanners contains plain string scanners' do
        let(:rule_content) do
          {
            type: 'scan_finding',
            scanners: %w[sast container_scanning]
          }
        end

        it 'is false' do
          expect(params[:malicious_rule]).to be false
        end
      end

      context 'when scanners contains a hash with is_malicious absent or false' do
        let(:rule_content) do
          {
            type: 'scan_finding',
            scanners: [{ name: 'sast' }, { name: 'dast', is_malicious: false }]
          }
        end

        it 'is false' do
          expect(params[:malicious_rule]).to be false
        end
      end
    end
  end
end
