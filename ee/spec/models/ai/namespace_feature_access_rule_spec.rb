# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::NamespaceFeatureAccessRule, feature_category: :ai_abstraction_layer do
  let_it_be(:root_namespace) { create(:group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:through_namespace) { create(:group, parent: root_namespace).tap { |ns| ns.add_guest(user) } }
  let_it_be(:other_root_namespace) { create(:group) }

  it_behaves_like 'accessible entity ruleable'

  describe 'associations' do
    it { is_expected.to belong_to(:through_namespace).inverse_of(:ai_feature_rules_through_namespace) }

    it 'belongs to root namespace' do
      is_expected.to belong_to(:root_namespace)
                       .class_name('Namespace')
                       .inverse_of(:ai_feature_rules)
    end
  end

  describe 'validations' do
    subject { described_class.new(through_namespace: through_namespace, root_namespace: root_namespace) }

    it { is_expected.to validate_presence_of(:root_namespace_id) }

    describe '#through_namespace_root_is_root_namespace validation' do
      context 'when through_namespace root is the same as root_namespace' do
        it 'is valid' do
          rule = build(:ai_namespace_feature_access_rules,
            through_namespace: through_namespace,
            root_namespace: root_namespace)

          expect(rule).to be_valid
        end
      end

      context 'when through_namespace root is different from root_namespace' do
        it 'is invalid' do
          rule = build(:ai_namespace_feature_access_rules,
            through_namespace: through_namespace,
            root_namespace: other_root_namespace
          )

          expect(rule).not_to be_valid
          expect(rule.errors[:through_namespace]).to include(
            'must belong to the same root namespace as the root_namespace'
          )
        end
      end
    end

    context 'when through_namespace is nil (default rule)' do
      it 'is valid' do
        rule = build(:ai_namespace_feature_access_rules,
          :duo_classic,
          through_namespace: nil,
          root_namespace: root_namespace)

        expect(rule).to be_valid
      end

      it 'validates uniqueness scoped to root_namespace' do
        create(:ai_namespace_feature_access_rules,
          :duo_classic,
          through_namespace: nil,
          root_namespace: root_namespace)

        duplicate = build(:ai_namespace_feature_access_rules,
          :duo_classic,
          through_namespace: nil,
          root_namespace: root_namespace)

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:accessible_entity]).to be_present
      end

      it 'allows same entity as default rule for different root_namespaces' do
        create(:ai_namespace_feature_access_rules,
          :duo_classic,
          through_namespace: nil,
          root_namespace: root_namespace)

        other_default = build(:ai_namespace_feature_access_rules,
          :duo_classic,
          through_namespace: nil,
          root_namespace: other_root_namespace)

        expect(other_default).to be_valid
      end

      it 'allows different entities as default rules for the same root_namespace' do
        create(:ai_namespace_feature_access_rules,
          :duo_classic,
          through_namespace: nil,
          root_namespace: root_namespace)

        other_entity = build(:ai_namespace_feature_access_rules,
          :duo_agent_platform,
          through_namespace: nil,
          root_namespace: root_namespace)

        expect(other_entity).to be_valid
      end
    end
  end

  describe 'bulk insert' do
    let(:through_namespace1) { create(:group, parent: root_namespace) }
    let(:through_namespace2) { create(:group, parent: root_namespace) }

    it 'bulk inserts multiple records' do
      records = [
        build(:ai_namespace_feature_access_rules,
          :duo_classic,
          through_namespace: through_namespace1,
          root_namespace: root_namespace
        ),
        build(:ai_namespace_feature_access_rules,
          :duo_agent_platform,
          through_namespace: through_namespace2,
          root_namespace: root_namespace
        )
      ]

      expect { described_class.bulk_insert!(records) }.to change { described_class.count }.by(2)
    end
  end

  describe '.by_root_namespace_group_by_through_namespace' do
    let_it_be(:root_namespace1) { create(:group) }
    let_it_be(:root_namespace2) { create(:group) }
    let_it_be(:subgroup1) { create(:group, parent: root_namespace1) }
    let_it_be(:subgroup2) { create(:group, parent: root_namespace1) }
    let_it_be(:subgroup3) { create(:group, parent: root_namespace2) }

    before do
      create(:ai_namespace_feature_access_rules,
        :duo_classic,
        through_namespace: subgroup1,
        root_namespace: root_namespace1
      )
      create(:ai_namespace_feature_access_rules,
        :duo_classic,
        through_namespace: subgroup2,
        root_namespace: root_namespace1
      )
      create(:ai_namespace_feature_access_rules,
        :duo_agent_platform,
        through_namespace: subgroup2,
        root_namespace: root_namespace1
      )
      create(:ai_namespace_feature_access_rules,
        :duo_agent_platform,
        through_namespace: subgroup3,
        root_namespace: root_namespace2
      )
    end

    subject(:result) { described_class.by_root_namespace_group_by_through_namespace(root_namespace1) }

    it 'filters groups by root namespace and groups by through_namespace_id' do
      expect(result.keys).to contain_exactly(subgroup1.id, subgroup2.id)

      expect(result[subgroup1.id]).to contain_exactly(
        have_attributes(
          accessible_entity: 'duo_classic',
          through_namespace_id: subgroup1.id,
          root_namespace_id: root_namespace1.id
        )
      )

      expect(result[subgroup2.id]).to contain_exactly(
        have_attributes(
          accessible_entity: 'duo_classic',
          through_namespace_id: subgroup2.id,
          root_namespace_id: root_namespace1.id
        ),
        have_attributes(
          accessible_entity: 'duo_agent_platform',
          through_namespace_id: subgroup2.id,
          root_namespace_id: root_namespace1.id
        )
      )
    end

    context 'when a default rule exists for the root namespace' do
      before do
        create(:ai_namespace_feature_access_rules,
          :duo_classic,
          through_namespace: nil,
          root_namespace: root_namespace1)
      end

      it 'includes the default rule (nil key) alongside group rules' do
        expect(result.keys).to contain_exactly(nil, subgroup1.id, subgroup2.id)
        expect(result[nil].map(&:accessible_entity)).to contain_exactly('duo_classic')
      end

      it 'does not include default rules from other root namespaces' do
        create(:ai_namespace_feature_access_rules,
          :duo_agent_platform,
          through_namespace: nil,
          root_namespace: root_namespace2)

        expect(result.keys).not_to include(root_namespace2.id)
        expect(result[nil].map(&:accessible_entity)).to contain_exactly('duo_classic')
      end
    end
  end

  describe '.group_by_through_namespace' do
    let_it_be(:other_through_namespace) { create(:group, parent: root_namespace) }

    before do
      create(:ai_namespace_feature_access_rules,
        :duo_classic,
        through_namespace: through_namespace,
        root_namespace: root_namespace
      )
      create(:ai_namespace_feature_access_rules,
        :duo_agent_platform,
        through_namespace: other_through_namespace,
        root_namespace: root_namespace
      )
    end

    it 'groups rules by through_namespace_id' do
      result = described_class.group_by_through_namespace

      expect(result.keys).to contain_exactly(through_namespace.id, other_through_namespace.id)
      expect(result[through_namespace.id].map(&:accessible_entity)).to contain_exactly('duo_classic')
      expect(result[other_through_namespace.id].map(&:accessible_entity)).to contain_exactly('duo_agent_platform')
    end
  end

  describe '.accessible_for_user' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:other_user) { create(:user) }
    let_it_be(:ns_with_access) { through_namespace }
    let_it_be(:ns_no_access) { create(:group, parent: root_namespace) }

    let_it_be(:rule_classic) do
      create(
        :ai_namespace_feature_access_rules,
        :duo_classic,
        through_namespace: ns_with_access,
        root_namespace: root_namespace
      )
    end

    let_it_be(:rule_agents) do
      create(
        :ai_namespace_feature_access_rules,
        :duo_agent_platform,
        through_namespace: ns_no_access,
        root_namespace: root_namespace
      )
    end

    where(:test_user, :entity, :target_namespace, :expected_rules) do
      ref(:user) | 'duo_classic' | ref(:root_namespace) | [ref(:rule_classic)]
      ref(:user) | 'duo_agent_platform' | ref(:root_namespace) | []
      ref(:other_user) | 'duo_classic' | ref(:root_namespace) | []
    end

    with_them do
      it 'filters by user access, entity, and namespace' do
        expect(described_class.accessible_for_user(test_user, entity, target_namespace)).to match_array(expected_rules)
      end
    end

    context 'with a default rule (through_namespace_id is nil)' do
      let_it_be(:default_rule_classic) do
        create(
          :ai_namespace_feature_access_rules,
          :duo_classic,
          through_namespace: nil,
          root_namespace: root_namespace
        )
      end

      it 'returns the default rule for any user in the root namespace' do
        expect(described_class.accessible_for_user(user, 'duo_classic', root_namespace))
          .to include(default_rule_classic)
        expect(described_class.accessible_for_user(other_user, 'duo_classic', root_namespace))
          .to include(default_rule_classic)
      end

      it 'returns both group-based and default rules for a member' do
        expect(described_class.accessible_for_user(user, 'duo_classic', root_namespace))
          .to contain_exactly(rule_classic, default_rule_classic)
      end

      it 'does not return default rule for a different root namespace' do
        expect(described_class.accessible_for_user(other_user, 'duo_classic', other_root_namespace))
          .not_to include(default_rule_classic)
      end

      it 'does not return default rule for a different entity' do
        expect(described_class.accessible_for_user(other_user, 'duo_agent_platform', root_namespace))
          .to be_empty
      end
    end
  end

  describe '.for_namespace' do
    let_it_be(:rule_for_root) do
      create(:ai_namespace_feature_access_rules,
        :duo_classic,
        through_namespace: through_namespace,
        root_namespace: root_namespace
      )
    end

    let_it_be(:rule_for_other) do
      create(
        :ai_namespace_feature_access_rules,
        :duo_agent_platform,
        through_namespace: create(:group, parent: other_root_namespace),
        root_namespace: other_root_namespace
      )
    end

    it 'returns rules for the specified namespace' do
      expect(described_class.for_namespace(root_namespace)).to match_array([rule_for_root])
    end

    context 'when a default rule exists' do
      let_it_be(:default_rule) do
        create(:ai_namespace_feature_access_rules,
          :duo_agent_platform,
          through_namespace: nil,
          root_namespace: root_namespace)
      end

      it 'includes the default rule' do
        expect(described_class.for_namespace(root_namespace)).to match_array([rule_for_root, default_rule])
      end
    end
  end
end
