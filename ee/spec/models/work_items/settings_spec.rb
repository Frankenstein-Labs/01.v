# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Settings, feature_category: :team_planning do
  subject(:settings) { build(:work_item_settings) }

  describe 'associations' do
    it { is_expected.to belong_to(:organization).class_name('Organizations::Organization').optional }
    it { is_expected.to belong_to(:namespace).optional }
  end

  describe 'validations' do
    it { is_expected.to allow_values(true, false).for(:customizable_type_visibility) }

    describe 'sharding key validation' do
      shared_examples 'an invalid settings record' do
        it 'is invalid with the expected error' do
          expect(settings).to be_invalid
          expect(settings.errors[:base]).to include(
            'Exactly one of namespace_id, organization_id must be present'
          )
        end
      end

      context 'when neither organization nor namespace is set' do
        subject(:settings) { build(:work_item_settings, organization: nil, namespace: nil) }

        it_behaves_like 'an invalid settings record'
      end

      context 'when both organization and namespace are set' do
        subject(:settings) do
          build(:work_item_settings, organization: create(:organization), namespace: create(:group))
        end

        it_behaves_like 'an invalid settings record'
      end

      context 'when only organization is set' do
        subject(:settings) { build(:work_item_settings, organization: create(:organization), namespace: nil) }

        it { is_expected.to be_valid }
      end

      context 'when only namespace is set' do
        subject(:settings) { build(:work_item_settings, namespace: create(:group), organization: nil) }

        it { is_expected.to be_valid }
      end
    end

    describe 'uniqueness validations' do
      shared_examples 'validates uniqueness' do |attribute|
        it { is_expected.to be_invalid }

        it 'adds the correct error' do
          settings.valid?
          expect(settings.errors[attribute]).to include('has already been taken')
        end
      end

      context 'for organization_id' do
        let_it_be(:organization) { create(:organization) }
        let_it_be(:existing_settings) { create(:work_item_settings, organization: organization, namespace: nil) }

        subject(:settings) { build(:work_item_settings, organization: organization, namespace: nil) }

        it_behaves_like 'validates uniqueness', :organization_id
      end

      context 'for namespace_id' do
        let_it_be(:namespace) { create(:group) }
        let_it_be(:existing_settings) { create(:work_item_settings, namespace: namespace) }

        subject(:settings) { build(:work_item_settings, namespace: namespace) }

        it_behaves_like 'validates uniqueness', :namespace_id
      end
    end
  end

  describe '.for_namespace' do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:group) { create(:group, organization: organization) }
    let_it_be(:subgroup) { create(:group, parent: group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:project_namespace) { project.project_namespace }

    context 'when namespace is nil' do
      it 'returns nil' do
        expect(described_class.for_namespace(nil)).to be_nil
      end
    end

    context 'when namespace is an Organization' do
      it 'finds or initializes by organization_id' do
        result = described_class.for_namespace(organization)

        expect(result).to be_a(described_class)
        expect(result.organization_id).to eq(organization.id)
        expect(result.namespace_id).to be_nil
      end

      context 'when a record already exists' do
        let!(:existing) { create(:work_item_settings, organization: organization, namespace: nil) }

        it 'returns the existing record' do
          result = described_class.for_namespace(organization)

          expect(result).to eq(existing)
          expect(result).to be_persisted
        end
      end
    end

    context 'when on SaaS' do
      before do
        stub_saas_features(namespace_scoped_work_item_types: true)
      end

      it 'finds or initializes by root namespace id' do
        result = described_class.for_namespace(group)

        expect(result).to be_a(described_class)
        expect(result.namespace_id).to eq(group.id)
        expect(result.organization_id).to be_nil
      end

      context 'when given a subgroup' do
        it 'resolves to the root ancestor' do
          result = described_class.for_namespace(subgroup)

          expect(result.namespace_id).to eq(group.id)
        end
      end

      context 'when given a project namespace' do
        it 'resolves to the root ancestor' do
          result = described_class.for_namespace(project_namespace)

          expect(result.namespace_id).to eq(group.id)
        end
      end

      context 'when given a project' do
        it 'resolves to the root ancestor' do
          result = described_class.for_namespace(project)

          expect(result.namespace_id).to eq(group.id)
        end
      end

      context 'when a record already exists for the root namespace' do
        let!(:existing) { create(:work_item_settings, namespace: group) }

        it 'returns the existing record' do
          expect(described_class.for_namespace(group)).to eq(existing)
        end

        it 'returns the existing record when called with a subgroup' do
          expect(described_class.for_namespace(subgroup)).to eq(existing)
        end

        it 'returns the existing record when called with a project namespace' do
          expect(described_class.for_namespace(project_namespace)).to eq(existing)
        end

        it 'returns the existing record when called with a project' do
          expect(described_class.for_namespace(project)).to eq(existing)
        end
      end
    end

    context 'when on self-managed' do
      it 'finds or initializes by organization_id from the namespace' do
        result = described_class.for_namespace(group)

        expect(result).to be_a(described_class)
        expect(result.organization_id).to eq(group.organization_id)
        expect(result.namespace_id).to be_nil
      end

      context 'when given a subgroup' do
        it 'uses the organization_id from the subgroup' do
          result = described_class.for_namespace(subgroup)

          expect(result.organization_id).to eq(subgroup.organization_id)
        end
      end

      context 'when given a project namespace' do
        it 'uses the organization_id from the project namespace' do
          result = described_class.for_namespace(project_namespace)

          expect(result.organization_id).to eq(project_namespace.organization_id)
        end
      end

      context 'when given a project' do
        it 'uses the organization_id from the project' do
          result = described_class.for_namespace(project)

          expect(result.organization_id).to eq(project.organization_id)
        end
      end

      context 'when a record already exists for the organization' do
        let!(:existing) { create(:work_item_settings, organization: organization, namespace: nil) }

        it 'returns the existing record' do
          expect(described_class.for_namespace(group)).to eq(existing)
        end

        it 'returns the existing record when called with a project namespace' do
          expect(described_class.for_namespace(project_namespace)).to eq(existing)
        end

        it 'returns the existing record when called with a project' do
          expect(described_class.for_namespace(project)).to eq(existing)
        end
      end
    end
  end
end
