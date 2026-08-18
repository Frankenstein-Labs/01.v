# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::PolicyDiff::RulesDiff, feature_category: :security_policy_management do
  describe '.from_json' do
    let(:json_input) do
      {
        'created' => [{ 'id' => 1, 'from' => nil, 'to' => { name: 'New Rule' } }],
        'updated' => [{ 'id' => 2, 'from' => { 'name' => 'Old Rule' }, 'to' => { 'name' => 'Updated Rule' } }],
        'deleted' => [{ 'id' => 3, 'from' => { 'name' => 'Deleted Rule' }, 'to' => nil }]
      }.deep_symbolize_keys
    end

    subject(:from_json) { described_class.from_json(json_input) }

    it 'sets the created rules correctly' do
      expect(from_json.created.first.id).to eq(1)
      expect(from_json.created.first.from).to be_nil
      expect(from_json.created.first.to).to eq({ name: 'New Rule' })
    end

    it 'sets the updated rules correctly' do
      expect(from_json.updated.first).to be_a(Security::SecurityOrchestrationPolicies::PolicyDiff::RuleDiff)
      expect(from_json.updated.first.id).to eq(2)
      expect(from_json.updated.first.from).to eq({ name: 'Old Rule' })
      expect(from_json.updated.first.to).to eq({ name: 'Updated Rule' })
    end

    it 'sets the deleted rules correctly' do
      expect(from_json.deleted.first).to be_a(Security::SecurityOrchestrationPolicies::PolicyDiff::RuleDiff)
      expect(from_json.deleted.first.id).to eq(3)
      expect(from_json.deleted.first.from).to eq({ name: 'Deleted Rule' })
      expect(from_json.deleted.first.to).to be_nil
    end

    context 'when json input is empty' do
      let(:json_input) { {} }

      it 'returns a RulesDiff instance with empty arrays' do
        expect(from_json.created).to be_empty
        expect(from_json.updated).to be_empty
        expect(from_json.deleted).to be_empty
      end
    end

    context 'when json input has nil values' do
      let(:json_input) { { 'created' => nil, 'updated' => nil, 'deleted' => nil } }

      it 'returns a RulesDiff instance with empty arrays' do
        expect(from_json.created).to be_empty
        expect(from_json.updated).to be_empty
        expect(from_json.deleted).to be_empty
      end
    end
  end

  describe '#to_h' do
    let(:rules_diff) { described_class.new }
    let(:created_rule) { { id: 1, name: 'New Rule' } }
    let(:updated_rule) do
      Security::SecurityOrchestrationPolicies::PolicyDiff::RuleDiff.new(id: 2, from: { name: 'Old Name' },
        to: { name: 'New Name' })
    end

    let(:deleted_rule) do
      Security::SecurityOrchestrationPolicies::PolicyDiff::RuleDiff.new(id: 3, from: { name: 'Deleted Rule' }, to: nil)
    end

    before do
      rules_diff.created << created_rule
      rules_diff.updated << updated_rule
      rules_diff.deleted << deleted_rule
    end

    it 'returns a hash with created, updated, and deleted rules' do
      expected_hash = {
        created: [{ id: 1, name: 'New Rule' }],
        updated: [{ id: 2, from: { name: 'Old Name' }, to: { name: 'New Name' } }],
        deleted: [{ id: 3, from: { name: 'Deleted Rule' }, to: nil }]
      }

      expect(rules_diff.to_h).to eq(expected_hash)
    end

    it 'returns empty arrays with no rules' do
      empty_rules_diff = described_class.new

      expected_hash = {
        created: [],
        updated: [],
        deleted: []
      }

      expect(empty_rules_diff.to_h).to eq(expected_hash)
    end
  end

  describe '#any_changes?' do
    let(:rules_diff) { described_class.new }

    context 'when there are no changes' do
      it 'returns false' do
        expect(rules_diff.any_changes?).to be false
      end
    end

    context 'when there are created rules' do
      before do
        rules_diff.add_created_rule({ id: 1, from: nil, to: { name: 'New Rule' } })
      end

      it 'returns true' do
        expect(rules_diff.any_changes?).to be true
      end
    end

    context 'when there are updated rules' do
      before do
        rules_diff.add_updated_rule(instance_double('Security::ApprovalPolicyRule', id: 1), { name: 'Old Name ' },
          { name: 'New Name' })
      end

      it 'returns true' do
        expect(rules_diff.any_changes?).to be true
      end
    end

    context 'when there are deleted rules' do
      before do
        rules_diff.add_deleted_rule(instance_double('Security::ApprovalPolicyRule', id: 1))
      end

      it 'returns true' do
        expect(rules_diff.any_changes?).to be true
      end
    end
  end
end
