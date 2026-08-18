# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Analytics::KnowledgeGraph::EnabledNamespace, feature_category: :knowledge_graph do
  let_it_be(:namespace) { create(:group) }

  subject { create(:knowledge_graph_enabled_namespace, namespace: namespace) }

  describe 'relations' do
    it { is_expected.to belong_to(:namespace).inverse_of(:knowledge_graph_enabled_namespace) }
  end

  describe 'validations' do
    it 'only allows root namespaces to be indexed' do
      subgroup = create(:group, parent: namespace)
      enabled_namespace = described_class.new(namespace: subgroup)

      expect(enabled_namespace).to be_invalid
      expect(enabled_namespace.errors[:root_namespace_id]).to include('Only top-level groups can be indexed')
    end

    it 'allows root namespaces to be indexed' do
      root_namespace = create(:group)

      expect(described_class.new(namespace: root_namespace)).to be_valid
    end
  end

  describe 'scopes' do
    let_it_be(:enabled_namespace) { create(:knowledge_graph_enabled_namespace, namespace: namespace) }

    describe '.for_root_namespace_id' do
      let_it_be(:another_enabled_namespace) { create(:knowledge_graph_enabled_namespace) }

      it 'returns records for the specified namespace' do
        expect(described_class.for_root_namespace_id(namespace.id)).to contain_exactly(enabled_namespace)
      end
    end

    describe '.recent' do
      it 'returns ordered by id desc' do
        enabled_namespace_2 = create(:knowledge_graph_enabled_namespace)

        expect(described_class.recent).to match([enabled_namespace_2, enabled_namespace])
      end
    end

    describe '.with_limit' do
      it 'returns only the amount of records requested' do
        create(:knowledge_graph_enabled_namespace)

        expect(described_class.with_limit(1).count).to eq(1)
      end
    end
  end
end
