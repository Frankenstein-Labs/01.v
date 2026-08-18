# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Dashboard::SecurityAttributesProjectFilterService, feature_category: :security_asset_inventories do
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project1) { create(:project, namespace: group) }
  let_it_be(:project2) { create(:project, namespace: group) }
  let_it_be(:project3) { create(:project, namespace: subgroup) }
  let_it_be(:other_group) { create(:group) }
  let_it_be(:other_project) { create(:project, namespace: other_group) }

  let_it_be(:category) { create(:security_category, namespace: group, name: 'Environment') }

  let_it_be(:attr_production) do
    create(:security_attribute, security_category: category, namespace: group, name: 'Production')
  end

  let_it_be(:attr_critical) do
    create(:security_attribute, security_category: category, namespace: group, name: 'Critical')
  end

  let_it_be(:project1_production) do
    create(:project_to_security_attribute, project: project1, security_attribute: attr_production,
      traversal_ids: project1.namespace.traversal_ids)
  end

  let_it_be(:project1_critical) do
    create(:project_to_security_attribute, project: project1, security_attribute: attr_critical,
      traversal_ids: project1.namespace.traversal_ids)
  end

  let_it_be(:project2_critical) do
    create(:project_to_security_attribute, project: project2, security_attribute: attr_critical,
      traversal_ids: project2.namespace.traversal_ids)
  end

  let_it_be(:project3_production) do
    create(:project_to_security_attribute, project: project3, security_attribute: attr_production,
      traversal_ids: project3.namespace.traversal_ids)
  end

  let_it_be(:other_category) { create(:security_category, namespace: other_group, name: 'Environment') }
  let_it_be(:other_attr) do
    create(:security_attribute, security_category: other_category, namespace: other_group, name: 'Production')
  end

  let_it_be(:other_project_attr) do
    create(:project_to_security_attribute, project: other_project, security_attribute: other_attr,
      traversal_ids: other_project.namespace.traversal_ids)
  end

  let(:namespace) { group }
  let(:attribute_filters) { [] }

  subject(:result) { described_class.new(namespace: namespace, attribute_filters: attribute_filters).execute }

  shared_examples 'returns empty project_ids' do
    it { expect(result).to eq({ status: :success, project_ids: [] }) }
  end

  describe '#execute' do
    context 'when namespace is nil' do
      let(:namespace) { nil }
      let(:attribute_filters) { [{ operator: 'is_one_of', attributes: [attr_production.id] }] }

      it_behaves_like 'returns empty project_ids'
    end

    context 'with no actionable filters' do
      where(:attribute_filters) { [nil, [], [{ operator: 'is_one_of', attributes: [] }]] }

      with_them do
        it_behaves_like 'returns empty project_ids'
      end
    end

    context 'with an unrecognized operator' do
      let(:attribute_filters) { [{ operator: 'invalid_operator', attributes: [attr_production.id] }] }

      it_behaves_like 'returns empty project_ids'
    end

    context 'with is_one_of operator' do
      context 'when filtering by a single attribute' do
        let(:attribute_filters) { [{ operator: 'is_one_of', attributes: [attr_production.id] }] }

        it 'returns matching projects and excludes other namespaces' do
          expect(result[:project_ids]).to contain_exactly(project1.id, project3.id)
        end
      end

      context 'when filtering by multiple attributes (OR within group)' do
        let(:attribute_filters) do
          [{ operator: 'is_one_of', attributes: [attr_production.id, attr_critical.id] }]
        end

        it { expect(result[:project_ids]).to contain_exactly(project1.id, project2.id, project3.id) }
      end

      context 'when combining multiple filters (AND between groups)' do
        let(:attribute_filters) do
          [
            { operator: 'is_one_of', attributes: [attr_production.id] },
            { operator: 'is_one_of', attributes: [attr_critical.id] }
          ]
        end

        it { expect(result[:project_ids]).to contain_exactly(project1.id) }
      end

      context 'with non-existent attribute IDs' do
        let(:attribute_filters) { [{ operator: 'is_one_of', attributes: [non_existing_record_id] }] }

        it_behaves_like 'returns empty project_ids'
      end
    end

    context 'with is_not_one_of operator' do
      context 'when excluding a single attribute' do
        let(:attribute_filters) { [{ operator: 'is_not_one_of', attributes: [attr_production.id] }] }

        it { expect(result[:project_ids]).to contain_exactly(project2.id) }
      end

      context 'when excluding multiple attributes' do
        let(:attribute_filters) do
          [{ operator: 'is_not_one_of', attributes: [attr_critical.id, attr_production.id] }]
        end

        it_behaves_like 'returns empty project_ids'
      end
    end

    context 'with combined is_one_of and is_not_one_of' do
      let(:attribute_filters) do
        [
          { operator: 'is_one_of', attributes: [attr_production.id] },
          { operator: 'is_not_one_of', attributes: [attr_critical.id] }
        ]
      end

      it { expect(result[:project_ids]).to contain_exactly(project3.id) }
    end

    context 'when scoped to a subgroup' do
      let(:namespace) { subgroup }
      let(:attribute_filters) { [{ operator: 'is_one_of', attributes: [attr_production.id] }] }

      it { expect(result[:project_ids]).to contain_exactly(project3.id) }
    end
  end
end
