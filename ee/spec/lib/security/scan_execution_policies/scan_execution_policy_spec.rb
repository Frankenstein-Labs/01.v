# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanExecutionPolicies::ScanExecutionPolicy, feature_category: :security_policy_management do
  let(:policy_content) do
    {
      actions: [
        { scan: 'sast', template: 'default' },
        { scan: 'dast', site_profile: 'production-site', scanner_profile: 'production-scanner' }
      ],
      skip_ci: {
        allowed: false,
        allowlist: {
          users: [
            { id: 1 },
            { id: 2 }
          ]
        }
      }
    }
  end

  let(:scope) do
    { groups: { including: [{ id: 1 }] }, projects: { excluding: [{ id: 5 }] } }
  end

  let(:policy_record) do
    create(:security_policy, :scan_execution_policy,
      name: 'Test Scan Execution Policy',
      description: 'Test Description',
      enabled: true,
      scope: scope.as_json,
      content: policy_content)
  end

  let(:scan_execution_policy) { described_class.new(policy_record) }

  describe '#actions' do
    subject(:actions) { scan_execution_policy.actions }

    it 'returns an Actions instance with correct values' do
      expect(actions).to be_a(Security::ScanExecutionPolicies::Actions)

      expect(actions.actions.length).to eq(2)
      expect(actions.actions.map(&:scan)).to match_array(%w[sast dast])
      expect(actions.actions.find { |a| a.scan == 'sast' }.template).to eq('default')
      expect(actions.actions.find { |a| a.scan == 'dast' }.site_profile).to eq('production-site')
      expect(actions.actions.find { |a| a.scan == 'dast' }.scanner_profile).to eq('production-scanner')
    end

    context 'when actions is not present in policy_content' do
      let(:policy_content) { { skip_ci: { allowed: true } } }

      it 'returns an empty Actions instance' do
        expect(actions.actions).to be_empty
      end
    end
  end

  describe '#skip_ci' do
    subject(:skip_ci) { scan_execution_policy.skip_ci }

    it 'returns a SkipCi instance with correct values' do
      expect(skip_ci).to be_a(Security::ScanExecutionPolicies::SkipCi)

      expect(skip_ci.allowed).to be false
      expect(skip_ci.allowlist_users.length).to eq(2)
      expect(skip_ci.allowlist_users.pluck(:id)).to match_array([1, 2])
    end

    context 'when skip_ci is not present in policy_content' do
      let(:policy_content) { { actions: [{ scan: 'sast' }] } }

      it 'returns a SkipCi instance with default values' do
        expect(skip_ci.allowed).to be_nil
        expect(skip_ci.allowlist_users).to be_empty
      end
    end
  end

  describe '#rules' do
    subject(:rules) { scan_execution_policy.rules }

    let!(:scan_execution_policy_rule) do
      create(:scan_execution_policy_rule, :pipeline,
        security_policy: policy_record,
        content: {
          type: 'pipeline',
          branches: %w[main],
          pipeline_sources: {
            including: %w[push web]
          }
        })
    end

    let(:expected_rule_content) do
      {
        type: 'pipeline',
        branches: %w[main],
        pipeline_sources: {
          including: %w[push web]
        }
      }
    end

    it 'returns a Rules instance with correct values' do
      expect(rules).to be_a(Security::ScanExecutionPolicies::Rules)

      rule = rules.rules.first
      expect(rule).to be_a(Security::ScanExecutionPolicies::Rule)
      expect(rule.type).to eq('pipeline')
      expect(rule.branches).to eq(%w[main])
      expect(rule.pipeline_sources.including).to match_array(%w[push web])
    end

    context 'when rules is not present in policy_record' do
      before do
        Security::ScanExecutionPolicyRule.where(security_policy: policy_record).delete_all
      end

      it 'passes an empty array to Rules' do
        expect(rules.rules).to be_empty
      end
    end

    context 'with schedule rule' do
      let!(:schedule_rule) do
        create(:scan_execution_policy_rule, :schedule,
          security_policy: policy_record,
          content: {
            type: 'schedule',
            branches: [],
            cadence: '0 22 * * 1-5',
            timezone: 'America/New_York',
            time_window: {
              distribution: 'random',
              value: 7200
            }
          })
      end

      it 'handles schedule rules correctly' do
        schedule_rule_obj = rules.rules.find { |r| r.type == 'schedule' }
        expect(schedule_rule_obj).to be_a(Security::ScanExecutionPolicies::Rule)
        expect(schedule_rule_obj.cadence).to eq('0 22 * * 1-5')
        expect(schedule_rule_obj.timezone).to eq('America/New_York')
        expect(schedule_rule_obj.time_window.distribution).to eq('random')
        expect(schedule_rule_obj.time_window.value).to eq(7200)
      end
    end

    context 'with pipeline rule using branch_type' do
      let!(:branch_type_rule) do
        create(:scan_execution_policy_rule, :pipeline,
          security_policy: policy_record,
          content: {
            type: 'pipeline',
            branch_type: 'protected'
          })
      end

      it 'handles branch_type rules correctly' do
        branch_type_rule_obj = rules.rules.find { |r| r.branch_type == 'protected' }
        expect(branch_type_rule_obj).to be_a(Security::ScanExecutionPolicies::Rule)
        expect(branch_type_rule_obj.type).to eq('pipeline')
        expect(branch_type_rule_obj.branch_type).to eq('protected')
      end
    end

    context 'with pipeline rule using agents' do
      let!(:agents_rule) do
        create(:scan_execution_policy_rule, :pipeline,
          security_policy: policy_record,
          content: {
            type: 'pipeline',
            agents: {
              'my-agent' => {
                namespaces: %w[default production]
              }
            }
          })
      end

      it 'handles agents rules correctly' do
        agents_rule_obj = rules.rules.find { |r| r.agents.agent_names.any? }
        expect(agents_rule_obj).to be_a(Security::ScanExecutionPolicies::Rule)
        expect(agents_rule_obj.type).to eq('pipeline')
        expect(agents_rule_obj.agents.agent_names).to match_array([:'my-agent'])
        expect(agents_rule_obj.agents.namespaces_for_agent(:'my-agent')).to match_array(%w[default production])
      end
    end
  end
end
