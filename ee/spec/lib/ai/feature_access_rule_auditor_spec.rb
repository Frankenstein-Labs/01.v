# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FeatureAccessRuleAuditor, feature_category: :duo_agent_platform do
  let_it_be(:user) { create(:user) }
  let(:scope) { ::Gitlab::Audit::InstanceScope.new }
  let(:event_name) { 'feature_access_rules_updated' }
  let(:expected_target) { instance_of(::Gitlab::Audit::NullTarget) }
  let(:rules) { [{ through_namespace: { id: 123 }, features: ['feature'] }] }
  let(:expected_message) { 'Updated feature access rules Group id: 123, features: ["feature"]' }

  describe '#execute' do
    subject(:execute) { described_class.new(current_user: user, rules: rules, scope: scope).execute }

    shared_examples 'audits feature access rules' do
      it 'calls auditor with correct parameters' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: event_name,
            author: user,
            scope: scope,
            target: expected_target,
            message: expected_message
          )
        )

        execute
      end
    end

    context 'with instance scope' do
      it_behaves_like 'audits feature access rules'
    end

    context 'with namespace scope' do
      let(:scope) { create(:group) }
      let(:event_name) { 'namespace_feature_access_rules_updated' }
      let(:expected_target) { scope }

      it_behaves_like 'audits feature access rules'
    end

    context 'when rules are empty' do
      let(:rules) { [] }
      let(:expected_message) { 'Cleared feature access rules' }

      it_behaves_like 'audits feature access rules'
    end

    context 'with multiple rules' do
      let(:rules) do
        [
          { through_namespace: { id: 123 }, features: ['feature'] },
          { through_namespace: { id: 456 }, features: ['other feature'] }
        ]
      end

      let(:expected_message) do
        'Updated feature access rules Group id: 123, features: ["feature"]; Group id: 456, features: ["other feature"]'
      end

      it_behaves_like 'audits feature access rules'
    end

    context 'with a default rule (no through_namespace)' do
      let(:rules) { [{ through_namespace: nil, features: ['duo_classic'] }] }
      let(:expected_message) { 'Updated feature access rules Group id: default, features: ["duo_classic"]' }

      it_behaves_like 'audits feature access rules'
    end

    context 'with mixed group-based and default rules' do
      let(:rules) do
        [
          { through_namespace: nil, features: ['duo_classic'] },
          { through_namespace: { id: 123 }, features: ['duo_agent_platform'] }
        ]
      end

      let(:expected_message) do
        'Updated feature access rules Group id: default, features: ["duo_classic"]; ' \
          'Group id: 123, features: ["duo_agent_platform"]'
      end

      it_behaves_like 'audits feature access rules'
    end
  end
end
