# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ProjectToSecurityAttribute, feature_category: :security_asset_inventories do
  let_it_be(:root_group) { create(:group) }
  let_it_be(:other_root_group) { create(:group) }
  let_it_be(:category) { create(:security_category, namespace: root_group, name: 'Test Category') }
  let_it_be(:attribute) { create(:security_attribute, security_category: category, namespace: root_group) }
  let_it_be(:other_category) { create(:security_category, namespace: root_group, name: 'Other Category') }
  let_it_be(:other_attribute) { create(:security_attribute, security_category: other_category, namespace: root_group) }
  let_it_be(:project) { create(:project, namespace: root_group) }
  let_it_be(:other_project) { create(:project, namespace: root_group) }
  let_it_be(:other_attribute_2) do
    create(:security_attribute, security_category: other_category, namespace: root_group)
  end

  describe 'associations' do
    it { is_expected.to belong_to(:project).required }
    it { is_expected.to belong_to(:security_attribute).class_name("Security::Attribute").required }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:traversal_ids) }

    context 'when validating uniqueness of security attribute scoped to project' do
      subject { build(:project_to_security_attribute, project: project, security_attribute: attribute) }

      it { is_expected.to validate_uniqueness_of(:security_attribute_id).scoped_to(:project_id) }
    end

    describe 'same_root_ancestor validation' do
      context 'when project and attribute belong to the same root namespace' do
        let(:association) { build(:project_to_security_attribute, project: project, security_attribute: attribute) }

        it 'is valid' do
          expect(association).to be_valid
        end
      end

      context 'when project and attribute belong to different root namespaces' do
        let(:other_category) { create(:security_category, namespace: other_root_group, name: 'Other Category') }
        let(:association) do
          build(:project_to_security_attribute, project: project, security_attribute: other_attribute)
        end

        let(:other_attribute) do
          create(:security_attribute, security_category: other_category, namespace: other_root_group,
            name: 'Other Attribute')
        end

        it 'is invalid' do
          expect(association).not_to be_valid
          expect(association.errors[:base]).to include('Project and attribute must belong to the same namespace')
        end
      end
    end
  end

  describe 'class methods' do
    describe '.pluck_id' do
      let_it_be(:association1) do
        create(:project_to_security_attribute, project: project, security_attribute: attribute)
      end

      let_it_be(:association2) do
        create(:project_to_security_attribute, project: project, security_attribute: other_attribute)
      end

      it 'returns an array of ids' do
        result = described_class.where(project_id: project.id).pluck_id

        expect(result).to match_array([association1.id, association2.id])
      end

      it 'respects the limit parameter' do
        result = described_class.where(project_id: project.id).pluck_id(1)

        expect(result.size).to eq(1)
      end
    end
  end

  describe 'scopes' do
    describe '.by_attribute_id' do
      let_it_be(:association) do
        create(:project_to_security_attribute, project: project, security_attribute: attribute)
      end

      let_it_be(:excluded) do
        create(:project_to_security_attribute, project: project, security_attribute: other_attribute)
      end

      it 'returns only associations with the specified attribute_id' do
        result = described_class.by_attribute_id(attribute.id)

        expect(result).to include(association)
        expect(result).not_to include(excluded)
        expect(result.count).to eq(1)
      end
    end

    describe '.by_project_id' do
      let_it_be(:other_project) { create(:project, namespace: root_group) }
      let_it_be(:association) do
        create(:project_to_security_attribute, project: project, security_attribute: attribute)
      end

      let_it_be(:excluded) do
        create(:project_to_security_attribute, project: other_project, security_attribute: attribute)
      end

      it 'returns only associations with the specified project_id' do
        result = described_class.by_project_id(project.id)

        expect(result).to contain_exactly(association)
      end
    end

    describe '.by_security_attributes' do
      before_all do
        create(:project_to_security_attribute, project: project, security_attribute: attribute)
        create(:project_to_security_attribute, project: project, security_attribute: other_attribute)
        create(:project_to_security_attribute, project: other_project, security_attribute: other_attribute_2)
      end

      it 'returns none when both filter arrays are empty' do
        result = described_class.by_security_attributes([], [])

        expect(result).to be_none
      end

      it 'does not cause N+1 queries when adding filters' do
        base_filters = [[attribute.id]]
        extra_filters = [[attribute.id], [other_attribute.id]]
        excluded = [[other_attribute_2.id]]

        control = ActiveRecord::QueryRecorder.new do
          described_class.by_security_attributes(base_filters, []).to_a
        end

        expect do
          described_class.by_security_attributes(extra_filters, excluded).to_a
        end.not_to exceed_query_limit(control)
      end
    end

    describe '.excluding_root_namespace' do
      let_it_be(:other_root_namespace) { create(:group) }
      let_it_be(:other_project) { create(:project, namespace: other_root_namespace) }

      let(:other_category) { create(:security_category, namespace: other_root_namespace, name: 'Other Category') }
      let(:other_attribute) do
        create(:security_attribute, security_category: other_category, namespace: other_root_namespace)
      end

      let!(:association) do
        create(:project_to_security_attribute, project: project, security_attribute: attribute,
          traversal_ids: [root_group.id])
      end

      let!(:excluded) do
        create(:project_to_security_attribute, project: other_project, security_attribute: other_attribute,
          traversal_ids: [other_root_namespace.id])
      end

      it 'excludes records with matching namespace id' do
        result = described_class.excluding_root_namespace(other_root_namespace.id)

        expect(result).to contain_exactly(association)
      end
    end
  end

  context 'with loose foreign key on project_to_security_attributes.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project, namespace: root_group) }
      let_it_be(:model) { create(:project_to_security_attribute, project: parent, security_attribute: attribute) }
    end
  end
end
