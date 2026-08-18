# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FeatureAccessRuleTransformer, feature_category: :duo_agent_platform do
  describe '.transform' do
    let(:through_namespace_1) { build_stubbed(:group) }
    let(:through_namespace_2) { build_stubbed(:group) }
    let(:rule_1) do
      instance_double(Ai::FeatureAccessRule,
        through_namespace: through_namespace_1,
        accessible_entity: 'duo_classic'
      )
    end

    let(:rule_2) do
      instance_double(Ai::FeatureAccessRule,
        through_namespace: through_namespace_1,
        accessible_entity: 'duo_agent_platform'
      )
    end

    let(:rule_3) do
      instance_double(Ai::FeatureAccessRule,
        through_namespace: through_namespace_2,
        accessible_entity: 'duo_classic'
      )
    end

    let(:rules) { { through_namespace_1.id => [rule_1, rule_2], through_namespace_2.id => [rule_3] } }

    subject(:transform) { described_class.transform(rules) }

    it 'transforms rules into a presentation format' do
      expect(transform).to match([
        a_hash_including(
          through_namespace: {
            id: through_namespace_1.id,
            name: through_namespace_1.name,
            full_path: through_namespace_1.full_path
          },
          features: contain_exactly('duo_classic', 'duo_agent_platform')
        ),
        a_hash_including(
          through_namespace: {
            id: through_namespace_2.id,
            name: through_namespace_2.name,
            full_path: through_namespace_2.full_path
          },
          features: %w[duo_classic]
        )
      ])
    end

    context 'with a default rule (no through_namespace)' do
      let(:default_rule) do
        instance_double(Ai::FeatureAccessRule, through_namespace: nil, accessible_entity: 'duo_classic')
      end

      let(:rules) { { nil => [default_rule] } }

      it 'transforms default rule with nil through_namespace' do
        expect(transform).to match([
          a_hash_including(
            through_namespace: nil,
            features: %w[duo_classic]
          )
        ])
      end
    end

    context 'with no rules' do
      let(:rules) { {} }

      it 'is empty' do
        expect(transform).to eq([])
      end
    end
  end
end
