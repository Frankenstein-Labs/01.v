# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::PolicyComparer, feature_category: :security_policy_management do
  let_it_be(:db_policy) do
    create(:security_policy, name: 'Old Policy', description: 'Old description')
  end

  let_it_be(:rule_content_1) do
    {
      type: 'scan_finding',
      branches: [],
      scanners: %w[container_scanning],
      vulnerabilities_allowed: 0,
      severity_levels: %w[critical],
      vulnerability_states: %w[detected]
    }
  end

  let_it_be(:rule_content_2) do
    {
      type: 'scan_finding',
      branches: [],
      scanners: %w[dependency_scanning],
      vulnerabilities_allowed: 0,
      severity_levels: %w[critical],
      vulnerability_states: %w[detected]
    }
  end

  let_it_be(:rule_content_3) do
    {
      type: 'license_finding',
      branches: [],
      match_on_inclusion_license: true,
      license_types: %w[BSD MIT],
      license_states: %w[newly_detected detected]
    }
  end

  let_it_be(:yaml_policy) do
    {
      name: 'New Policy',
      type: 'approval_policy',
      description: 'New description',
      enabled: true,
      metadata: {},
      policy_scope: {},
      rules: [rule_content_1, rule_content_2, rule_content_3]
    }
  end

  let_it_be(:approval_policy_rule_1) do
    create(:approval_policy_rule, :scan_finding, security_policy: db_policy, content: rule_content_1)
  end

  let_it_be(:approval_policy_rule_2) do
    create(:approval_policy_rule, :scan_finding, security_policy: db_policy, content: rule_content_2)
  end

  let(:policy_comparer) { described_class.new(db_policy: db_policy, yaml_policy: yaml_policy, policy_index: 0) }

  describe '#diff' do
    subject(:policy_diffs) { policy_comparer.diff }

    it 'returns the correct changes for policy fields' do
      diff = policy_diffs.diff

      expect(diff[:name]).to have_attributes(from: 'Old Policy', to: 'New Policy')
      expect(diff[:description]).to have_attributes(from: 'Old description', to: 'New description')
      expect(diff[:rules]).to be_nil
      expect(diff[:type]).to be_nil
    end

    it 'returns the correct changes for rules' do
      rules_diff = policy_diffs.rules_diff

      expect(rules_diff.created.first).to have_attributes(id: nil, from: nil, to: rule_content_3)
      expect(rules_diff.updated).to be_empty
      expect(rules_diff.deleted).to be_empty
    end

    context 'when yaml_policy has fewer rules than db_policy' do
      let_it_be(:yaml_policy) do
        {
          name: 'New Policy',
          description: 'New description',
          rules: [rule_content_1]
        }
      end

      it 'correctly identifies deleted rules' do
        rules_diff = policy_diffs.rules_diff

        expect(rules_diff.created).to be_empty
        expect(rules_diff.updated).to be_empty
        expect(rules_diff.deleted.first.id).to eq(approval_policy_rule_2.id)
        expect(rules_diff.deleted.first.from).to eq(approval_policy_rule_2)
        expect(rules_diff.deleted.first.to).to be_nil
      end
    end

    context 'when rules are updated' do
      let_it_be(:yaml_policy) do
        {
          name: 'New Policy',
          description: 'New description',
          rules: [rule_content_1, rule_content_3]
        }
      end

      it 'handles the comparison correctly' do
        rules_diff = policy_diffs.rules_diff

        expect(rules_diff.created).to be_empty
        expect(rules_diff.deleted).to be_empty
        expect(rules_diff.updated.first.id).to eq(approval_policy_rule_2.id)
        expect(rules_diff.updated.first.from).to eq(approval_policy_rule_2)
        expect(rules_diff.updated.first.to).to eq(rule_content_3)
      end
    end

    context 'when policies have no rules' do
      let_it_be(:yaml_policy) { { name: 'New Policy' } }
      let_it_be(:db_policy) do
        create(:security_policy, :pipeline_execution_policy, name: 'Old Policy', description: 'Old description')
      end

      it 'handles the comparison correctly' do
        rules_diff = policy_diffs.rules_diff

        expect(rules_diff.created).to be_empty
        expect(rules_diff.updated).to be_empty
        expect(rules_diff.deleted).to be_empty
      end
    end

    context 'when policy fields are blank' do
      let_it_be(:yaml_policy) do
        {
          name: 'New Policy',
          description: 'Description',
          metadata: nil,
          policy_scope: nil
        }
      end

      let_it_be(:db_policy) do
        create(:security_policy, name: 'Old Policy', description: 'Description', metadata: {}, scope: {})
      end

      it 'considers blank values equal and does not create a diff' do
        diff = policy_diffs.diff

        expect(diff[:name]).to have_attributes(from: 'Old Policy', to: 'New Policy')
        expect(diff[:description]).to be_nil
        expect(diff[:metadata]).to be_nil
        expect(diff[:policy_scope]).to be_nil
      end
    end
  end

  describe '#event_payload' do
    subject(:event_payload) { policy_comparer.event_payload }

    it 'returns a hash with the expected keys' do
      expect(event_payload.keys).to match_array([:security_policy_id, :diff, :rules_diff])
    end

    it 'includes the security policy id' do
      expect(event_payload[:security_policy_id]).to eq(db_policy.id)
    end

    it 'includes the diff from the diff object' do
      expect(event_payload[:diff]).to eq({
        name: { from: 'Old Policy', to: 'New Policy' },
        description: { from: 'Old description', to: 'New description' }
      })
    end

    it 'includes the rules_diff from the diff object' do
      expect(event_payload[:rules_diff]).to eq({ created: [id: nil, from: nil, to: rule_content_3], deleted: [],
updated: [] })
    end

    context 'when diff is empty' do
      let_it_be(:yaml_policy) { db_policy.to_policy_hash }

      it 'returns empty hashes for diff and rules_diff' do
        payload = event_payload
        expect(payload[:diff]).to eq({})
        expect(payload[:rules_diff]).to eq({ created: [], updated: [], deleted: [] })
      end
    end
  end
end
