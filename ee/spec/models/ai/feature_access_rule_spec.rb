# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::FeatureAccessRule, feature_category: :ai_abstraction_layer do
  let_it_be(:through_namespace) { create(:group) }

  include_examples 'accessible entity ruleable'

  describe 'associations' do
    it { is_expected.to belong_to(:through_namespace).inverse_of(:accessible_ai_features_on_instance) }
  end

  describe 'validations' do
    context 'when through_namespace_id is nil (default rule)' do
      subject { described_class.new(accessible_entity: 'duo_classic', through_namespace_id: nil) }

      it { is_expected.to be_valid }

      it 'validates uniqueness of accessible_entity for default rules' do
        create(:ai_instance_accessible_entity_rules, :duo_classic, through_namespace: nil)
        duplicate = build(:ai_instance_accessible_entity_rules, :duo_classic, through_namespace: nil)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:accessible_entity]).to be_present
      end

      it 'allows different entities as default rules' do
        create(:ai_instance_accessible_entity_rules, :duo_classic, through_namespace: nil)
        other_entity = build(:ai_instance_accessible_entity_rules, :duo_agent_platform, through_namespace: nil)
        expect(other_entity).to be_valid
      end
    end
  end

  describe 'bulk insert' do
    let_it_be(:namespace1) { create(:group) }
    let_it_be(:namespace2) { create(:group) }

    it 'bulk inserts multiple records' do
      records = [
        build(:ai_instance_accessible_entity_rules,
          :duo_classic,
          through_namespace: namespace1
        ),
        build(:ai_instance_accessible_entity_rules,
          :duo_agent_platform,
          through_namespace: namespace2
        )
      ]

      expect { described_class.bulk_insert!(records) }.to change { described_class.count }.by(2)
    end
  end

  describe '.accessible_for_user' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:user) { create(:user) }
    let_it_be(:other_user) { create(:user) }
    let_it_be(:ns_no_access) { create(:group) }

    let_it_be(:rule_classic) do
      create(:ai_instance_accessible_entity_rules, :duo_classic, through_namespace: through_namespace)
    end

    let_it_be(:rule_agents) do
      create(:ai_instance_accessible_entity_rules, :duo_agent_platform, through_namespace: ns_no_access)
    end

    before_all do
      through_namespace.add_guest(user)
    end

    where(:test_user, :entity, :expected_rules) do
      ref(:user) | 'duo_classic' | [ref(:rule_classic)]
      ref(:user) | 'duo_agent_platform' | []
      ref(:other_user) | 'duo_classic' | []
    end

    with_them do
      it 'filters by user access and entity' do
        expect(described_class.accessible_for_user(test_user, entity)).to match_array(expected_rules)
      end
    end

    context 'with a default rule (through_namespace_id is nil)' do
      let_it_be(:default_rule_classic) do
        create(:ai_instance_accessible_entity_rules, :duo_classic, through_namespace: nil)
      end

      it 'returns the default rule for any user' do
        expect(described_class.accessible_for_user(user, 'duo_classic')).to include(default_rule_classic)
        expect(described_class.accessible_for_user(other_user, 'duo_classic')).to include(default_rule_classic)
      end

      it 'returns both group-based and default rules for a member' do
        expect(described_class.accessible_for_user(user, 'duo_classic'))
          .to contain_exactly(rule_classic, default_rule_classic)
      end

      it 'does not return default rule for a different entity' do
        expect(described_class.accessible_for_user(other_user, 'duo_agent_platform')).to be_empty
      end
    end
  end

  describe '.duo_namespace_access_rules' do
    let_it_be(:namespace_a) { create(:group) }
    let_it_be(:namespace_b) { create(:group) }

    subject(:result) { described_class.duo_namespace_access_rules }

    context 'when rules exist' do
      before do
        create(:ai_instance_accessible_entity_rules, :duo_classic, through_namespace_id: namespace_a.id)
        create(:ai_instance_accessible_entity_rules, :duo_agent_platform, through_namespace_id: namespace_a.id)
        create(:ai_instance_accessible_entity_rules, :duo_classic, through_namespace_id: namespace_b.id)
      end

      it 'returns rules' do
        expect(result.keys).to contain_exactly(namespace_a.id, namespace_b.id)
        expect(result[namespace_a.id].map(&:accessible_entity)).to contain_exactly('duo_classic', 'duo_agent_platform')
        expect(result[namespace_b.id].map(&:accessible_entity)).to contain_exactly('duo_classic')
      end
    end

    context 'when a default rule exists' do
      before do
        create(:ai_instance_accessible_entity_rules, :duo_classic, through_namespace_id: nil)
      end

      it 'includes the default rule keyed by nil' do
        expect(result.keys).to include(nil)
        expect(result[nil].map(&:accessible_entity)).to contain_exactly('duo_classic')
      end
    end

    context 'when no rules exist' do
      it { expect(result).to be_empty }
    end
  end

  describe '.duo_root_namespace_access_rules' do
    let_it_be(:root_namespace_a) { create(:group) }
    let_it_be(:root_namespace_b) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: root_namespace_a) }

    subject(:result) { described_class.duo_root_namespace_access_rules }

    context 'when rules exist for root namespaces' do
      before do
        create(:ai_instance_accessible_entity_rules, :duo_classic, through_namespace: root_namespace_a)
        create(:ai_instance_accessible_entity_rules, :duo_agent_platform, through_namespace: root_namespace_a)
        create(:ai_instance_accessible_entity_rules, :duo_classic, through_namespace: root_namespace_b)
      end

      it 'returns only root namespace rules' do
        expect(result.keys).to contain_exactly(root_namespace_a.id, root_namespace_b.id)
        expect(result[root_namespace_a.id].map(&:accessible_entity)).to contain_exactly(
          'duo_classic', 'duo_agent_platform'
        )
        expect(result[root_namespace_b.id].map(&:accessible_entity)).to contain_exactly('duo_classic')
      end
    end

    context 'when rules exist for both root and nested namespaces' do
      before do
        create(:ai_instance_accessible_entity_rules, :duo_classic, through_namespace: root_namespace_a)
        create(:ai_instance_accessible_entity_rules, :duo_agent_platform, through_namespace: subgroup)
      end

      it 'returns only root namespace rules' do
        expect(result.keys).to contain_exactly(root_namespace_a.id)
        expect(result[root_namespace_a.id].map(&:accessible_entity)).to contain_exactly('duo_classic')
      end
    end

    context 'when a default rule exists' do
      before do
        create(:ai_instance_accessible_entity_rules, :duo_classic, through_namespace_id: nil)
        create(:ai_instance_accessible_entity_rules, :duo_classic, through_namespace: root_namespace_a)
      end

      it 'includes default rules (nil key) alongside root namespace rules' do
        expect(result.keys).to contain_exactly(nil, root_namespace_a.id)
        expect(result[nil].map(&:accessible_entity)).to contain_exactly('duo_classic')
      end
    end

    context 'when no rules exist' do
      it { expect(result).to be_empty }
    end
  end

  context 'with loose foreign key on ai_instance_accessible_entity_rules.through_namespace_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:group) }
      let_it_be(:model) { create(:ai_instance_accessible_entity_rules, through_namespace: parent) }
    end
  end

  describe '.duo_namespace_access_rules=' do
    let_it_be(:namespace_a) { create(:group) }
    let_it_be(:namespace_b) { create(:group) }

    it 'creates instance accessible entity rules' do
      described_class.duo_namespace_access_rules = [
        { through_namespace: { id: namespace_a.id }, features: %w[duo_classic duo_agent_platform] },
        { through_namespace: { id: namespace_b.id }, features: %w[duo_agent_platform] }
      ]

      expect(namespace_a.accessible_ai_features_on_instance.pluck(:accessible_entity))
        .to match_array(%w[duo_classic duo_agent_platform])
      expect(namespace_b.accessible_ai_features_on_instance.pluck(:accessible_entity))
        .to match_array(%w[duo_agent_platform])
    end

    context 'when a rule has no through_namespace (default rule)' do
      it 'creates a default rule with through_namespace_id nil' do
        described_class.duo_namespace_access_rules = [
          { through_namespace: nil, features: %w[duo_classic] },
          { through_namespace: { id: namespace_a.id }, features: %w[duo_agent_platform] }
        ]

        default_rules = described_class.where(through_namespace_id: nil)
        expect(default_rules.pluck(:accessible_entity)).to contain_exactly('duo_classic')

        expect(namespace_a.accessible_ai_features_on_instance.pluck(:accessible_entity))
          .to contain_exactly('duo_agent_platform')
      end

      it 'creates a default rule when through_namespace key is absent' do
        described_class.duo_namespace_access_rules = [
          { features: %w[duo_classic] }
        ]

        expect(described_class.where(through_namespace_id: nil).pluck(:accessible_entity))
          .to contain_exactly('duo_classic')
      end
    end

    context 'when hash has stringified keys' do
      it 'creates instance accessible entity rules' do
        described_class.duo_namespace_access_rules = [
          { "through_namespace" => { "id" => namespace_a.id }, "features" => ["duo_agent_platform"] }
        ]

        expect(namespace_a.accessible_ai_features_on_instance.pluck(:accessible_entity))
          .to match_array(%w[duo_agent_platform])
      end

      it 'creates a default rule with stringified keys' do
        described_class.duo_namespace_access_rules = [
          { "through_namespace" => nil, "features" => ["duo_classic"] }
        ]

        expect(described_class.where(through_namespace_id: nil).pluck(:accessible_entity))
          .to contain_exactly('duo_classic')
      end
    end

    context 'with empty array' do
      before do
        create(:ai_instance_accessible_entity_rules, through_namespace_id: namespace_a.id)
      end

      it 'deletes existing rules and does not create new ones' do
        described_class.duo_namespace_access_rules = []

        expect(Ai::FeatureAccessRule.count).to eq(0)
      end
    end
  end
end
