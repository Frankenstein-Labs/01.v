# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::EnabledFoundationalFlow, feature_category: :workflow_catalog do
  describe 'associations' do
    it { is_expected.to belong_to(:namespace).optional }
    it { is_expected.to belong_to(:project).optional }
    it { is_expected.to belong_to(:catalog_item).class_name('Ai::Catalog::Item') }

    it { is_expected.to have_many(:check_results).class_name('Ai::Catalog::EnabledFoundationalFlowCheckResult') }
  end

  describe 'validations' do
    describe 'catalog_item_id presence' do
      it { is_expected.to validate_presence_of(:catalog_item_id) }
    end

    describe 'catalog_item_id uniqueness scoped to namespace_id' do
      subject { create(:ai_catalog_enabled_foundational_flow, :for_namespace) }

      it { is_expected.to validate_uniqueness_of(:catalog_item_id).scoped_to(:namespace_id) }
    end

    describe 'catalog_item_id uniqueness scoped to project_id' do
      subject { create(:ai_catalog_enabled_foundational_flow, :for_project) }

      it { is_expected.to validate_uniqueness_of(:catalog_item_id).scoped_to(:project_id) }
    end

    describe '#belongs_to_namespace_or_project' do
      context 'when namespace_id is present and project_id is nil' do
        subject { create(:ai_catalog_enabled_foundational_flow, :for_namespace) }

        it { is_expected.to be_valid }
      end

      context 'when project_id is present and namespace_id is nil' do
        subject { create(:ai_catalog_enabled_foundational_flow, :for_project) }

        it { is_expected.to be_valid }
      end

      context 'when both namespace_id and project_id are present' do
        subject(:enabled_flow) do
          build(:ai_catalog_enabled_foundational_flow,
            namespace: create(:group),
            project: create(:project))
        end

        it 'is invalid' do
          expect(enabled_flow).not_to be_valid
          expect(enabled_flow.errors[:base]).to include('must belong to either namespace or project')
        end
      end

      context 'when both namespace_id and project_id are nil' do
        subject(:enabled_flow) do
          build(:ai_catalog_enabled_foundational_flow,
            namespace: nil,
            project: nil)
        end

        it 'is invalid' do
          expect(enabled_flow).not_to be_valid
          expect(enabled_flow.errors[:base]).to include('must belong to either namespace or project')
        end
      end
    end

    describe '#catalog_item_is_foundational_flow' do
      context 'when catalog_item is a foundational flow' do
        subject do
          create(:ai_catalog_enabled_foundational_flow, :for_namespace,
            catalog_item: create(:ai_catalog_item, :with_foundational_flow_reference))
        end

        it { is_expected.to be_valid }
      end

      context 'when catalog_item is not a foundational flow' do
        subject(:enabled_flow) do
          build(:ai_catalog_enabled_foundational_flow,
            catalog_item: create(:ai_catalog_item))
        end

        it 'is invalid' do
          expect(enabled_flow).not_to be_valid
          expect(enabled_flow.errors[:catalog_item_id]).to include('must be a foundational flow')
        end
      end

      context 'when catalog_item_id is nil' do
        subject(:enabled_flow) { build(:ai_catalog_enabled_foundational_flow, catalog_item: nil) }

        it 'does not add foundational flow error' do
          enabled_flow.valid?
          expect(enabled_flow.errors[:catalog_item_id]).not_to include('must be a foundational flow')
        end
      end
    end
  end

  describe 'scopes' do
    describe '.for_namespace' do
      let_it_be(:namespace) { create(:group) }
      let_it_be(:other_namespace) { create(:group) }
      let_it_be(:project) { create(:project) }

      let_it_be(:namespace_flow) do
        create(:ai_catalog_enabled_foundational_flow, :for_namespace, namespace: namespace)
      end

      let_it_be(:other_namespace_flow) do
        create(:ai_catalog_enabled_foundational_flow, :for_namespace, namespace: other_namespace)
      end

      let_it_be(:project_flow) do
        create(:ai_catalog_enabled_foundational_flow, :for_project, project: project)
      end

      it 'returns only records with matching namespace_id and nil project_id' do
        expect(described_class.for_namespace(namespace.id)).to contain_exactly(namespace_flow)
      end

      it 'does not return records for other namespaces' do
        expect(described_class.for_namespace(namespace.id)).not_to include(other_namespace_flow)
      end

      it 'does not return records for projects' do
        expect(described_class.for_namespace(namespace.id)).not_to include(project_flow)
      end
    end

    describe '.for_project' do
      let_it_be(:project) { create(:project) }
      let_it_be(:other_project) { create(:project) }
      let_it_be(:namespace) { create(:group) }

      let_it_be(:project_flow) do
        create(:ai_catalog_enabled_foundational_flow, :for_project, project: project)
      end

      let_it_be(:other_project_flow) do
        create(:ai_catalog_enabled_foundational_flow, :for_project, project: other_project)
      end

      let_it_be(:namespace_flow) do
        create(:ai_catalog_enabled_foundational_flow, :for_namespace, namespace: namespace)
      end

      it 'returns only records with matching project_id and nil namespace_id' do
        expect(described_class.for_project(project.id)).to contain_exactly(project_flow)
      end

      it 'does not return records for other projects' do
        expect(described_class.for_project(project.id)).not_to include(other_project_flow)
      end

      it 'does not return records for namespaces' do
        expect(described_class.for_project(project.id)).not_to include(namespace_flow)
      end
    end

    describe '.excluding_catalog_items' do
      let_it_be(:namespace) { create(:group) }
      let_it_be(:item1) { create(:ai_catalog_item, :with_foundational_flow_reference) }
      let_it_be(:item2) { create(:ai_catalog_item, :with_foundational_flow_reference) }
      let_it_be(:item3) { create(:ai_catalog_item, :with_foundational_flow_reference) }

      let_it_be(:flow1) do
        create(:ai_catalog_enabled_foundational_flow, :for_namespace, namespace: namespace, catalog_item: item1)
      end

      let_it_be(:flow2) do
        create(:ai_catalog_enabled_foundational_flow, :for_namespace, namespace: namespace, catalog_item: item2)
      end

      let_it_be(:flow3) do
        create(:ai_catalog_enabled_foundational_flow, :for_namespace, namespace: namespace, catalog_item: item3)
      end

      it 'excludes records with matching catalog_item_ids' do
        result = described_class.for_namespace(namespace.id).excluding_catalog_items([item1.id, item2.id])

        expect(result).to contain_exactly(flow3)
      end

      it 'returns all records when excluding empty array' do
        result = described_class.for_namespace(namespace.id).excluding_catalog_items([])

        expect(result).to contain_exactly(flow1, flow2, flow3)
      end
    end

    describe '.limited_catalog_item_ids' do
      let_it_be(:namespace) { create(:group) }
      let_it_be(:item1) { create(:ai_catalog_item, :with_foundational_flow_reference) }
      let_it_be(:item2) { create(:ai_catalog_item, :with_foundational_flow_reference) }
      let_it_be(:item3) { create(:ai_catalog_item, :with_foundational_flow_reference) }

      before_all do
        create(:ai_catalog_enabled_foundational_flow, :for_namespace, namespace: namespace, catalog_item: item1)
        create(:ai_catalog_enabled_foundational_flow, :for_namespace, namespace: namespace, catalog_item: item2)
        create(:ai_catalog_enabled_foundational_flow, :for_namespace, namespace: namespace, catalog_item: item3)
      end

      it 'returns catalog_item_ids with default limit' do
        result = described_class.for_namespace(namespace.id).limited_catalog_item_ids

        expect(result).to match_array([item1.id, item2.id, item3.id])
      end

      it 'respects custom limit' do
        result = described_class.for_namespace(namespace.id).limited_catalog_item_ids(2)

        expect(result.size).to eq(2)
        expect(result).to all(be_in([item1.id, item2.id, item3.id]))
      end

      it 'uses FOUNDATIONAL_FLOWS_LIMIT constant by default' do
        stub_const("Ai::Catalog::Item::FOUNDATIONAL_FLOWS_LIMIT", 1)

        result = described_class.for_namespace(namespace.id).limited_catalog_item_ids

        expect(result.size).to eq(1)
      end
    end
  end
end
