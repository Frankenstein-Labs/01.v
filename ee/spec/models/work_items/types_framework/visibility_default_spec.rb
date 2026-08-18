# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::TypesFramework::VisibilityDefault, feature_category: :team_planning do
  let_it_be(:namespace) { create(:group) }

  subject(:visibility_default) { build(:work_item_type_visibility_default, namespace: namespace) }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace).optional }
    it { is_expected.to belong_to(:organization).class_name('Organizations::Organization').optional }
  end

  describe 'validations' do
    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:work_item_type_id) }
    it { is_expected.to allow_values(true, false).for(:enabled) }

    it_behaves_like 'validates work item type ID'

    describe 'sharding key validation' do
      shared_examples 'an invalid record' do
        it 'is invalid with the expected error' do
          expect(visibility_default).to be_invalid
          expect(visibility_default.errors[:base]).to include(
            'Exactly one of namespace_id, organization_id must be present'
          )
        end
      end

      context 'when neither namespace nor organization is set' do
        subject(:visibility_default) do
          build(:work_item_type_visibility_default, namespace: nil, organization: nil)
        end

        it_behaves_like 'an invalid record'
      end

      context 'when both namespace and organization are set' do
        subject(:visibility_default) do
          build(:work_item_type_visibility_default,
            namespace: create(:group),
            organization: create(:organization))
        end

        it_behaves_like 'an invalid record'
      end

      context 'when only namespace is set' do
        it { is_expected.to be_valid }
      end

      context 'when only organization is set' do
        subject(:visibility_default) do
          build(:work_item_type_visibility_default, namespace: nil, organization: create(:organization))
        end

        it { is_expected.to be_valid }
      end
    end

    describe 'uniqueness' do
      context 'when namespace-scoped' do
        it 'validates uniqueness of work_item_type_id scoped to namespace_id' do
          existing = create(:work_item_type_visibility_default)
          duplicate = build(:work_item_type_visibility_default,
            namespace: existing.namespace,
            work_item_type_id: existing.work_item_type_id)

          expect(duplicate).to be_invalid
          expect(duplicate.errors[:work_item_type_id]).to be_present
        end
      end

      context 'when organization-scoped' do
        it 'validates uniqueness of work_item_type_id scoped to organization_id' do
          existing = create(:work_item_type_visibility_default, :for_organization)
          duplicate = build(:work_item_type_visibility_default, :for_organization,
            organization: existing.organization,
            work_item_type_id: existing.work_item_type_id)

          expect(duplicate).to be_invalid
          expect(duplicate.errors[:work_item_type_id]).to be_present
        end
      end
    end
  end

  describe '.upsert_for_settings' do
    let_it_be(:group) { create(:group) }
    let_it_be(:settings) { create(:work_item_settings, namespace: group) }
    let_it_be(:issue_type) { build(:work_item_system_defined_type, :issue) }

    it 'creates a visibility default record' do
      expect do
        described_class.upsert_for_settings(settings, work_item_type_id: issue_type.id, enabled: true)
      end.to change { described_class.count }.by(1)

      expect(described_class.last).to have_attributes(
        namespace_id: group.id,
        work_item_type_id: issue_type.id,
        enabled: true
      )
    end

    it 'updates an existing record' do
      create(:work_item_type_visibility_default, namespace: group,
        work_item_type_id: issue_type.id, enabled: false)

      expect do
        described_class.upsert_for_settings(settings, work_item_type_id: issue_type.id, enabled: true)
      end.not_to change { described_class.count }

      expect(described_class.last.enabled).to be true
    end

    context 'when a concurrent request causes a unique constraint violation' do
      before do
        allow_next_instance_of(described_class) do |record|
          allow(record).to receive(:update!).and_wrap_original do |_method, **args|
            create(:work_item_type_visibility_default, namespace: group,
              work_item_type_id: issue_type.id, enabled: args[:enabled])
            raise ActiveRecord::RecordNotUnique, 'duplicate key'
          end
        end
      end

      it 'retries and updates the existing record' do
        expect do
          described_class.upsert_for_settings(settings, work_item_type_id: issue_type.id, enabled: true)
        end.to change { described_class.count }.by(1)

        expect(described_class.last).to have_attributes(
          namespace_id: group.id,
          work_item_type_id: issue_type.id,
          enabled: true
        )
      end
    end
  end

  describe '.defaults_for_settings' do
    let_it_be(:issue_type) { build(:work_item_system_defined_type, :issue) }
    let_it_be(:task_type) { build(:work_item_system_defined_type, :task) }

    context 'when settings is namespace-scoped' do
      let_it_be(:group) { create(:group) }
      let_it_be(:settings) { create(:work_item_settings, namespace: group) }

      it 'returns a hash of type_id => enabled' do
        create(:work_item_type_visibility_default, namespace: group,
          work_item_type_id: issue_type.id, enabled: false)
        create(:work_item_type_visibility_default, namespace: group,
          work_item_type_id: task_type.id, enabled: true)

        result = described_class.defaults_for_settings(settings)

        expect(result).to eq(issue_type.id => false, task_type.id => true)
      end

      it 'returns empty hash when no defaults exist' do
        expect(described_class.defaults_for_settings(settings)).to eq({})
      end
    end
  end

  describe '.for_settings' do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:issue_type) { build(:work_item_system_defined_type, :issue) }

    context 'when settings is namespace-scoped' do
      let_it_be(:settings) { create(:work_item_settings, namespace: namespace) }
      let_it_be(:visibility_default) do
        create(:work_item_type_visibility_default, namespace: namespace, work_item_type_id: issue_type.id)
      end

      let_it_be(:other_visibility_default) do
        create(:work_item_type_visibility_default, :for_organization, organization: organization,
          work_item_type_id: issue_type.id)
      end

      it 'returns visibility defaults scoped to the namespace' do
        result = described_class.for_settings(settings)

        expect(result).to include(visibility_default)
        expect(result).not_to include(other_visibility_default)
      end
    end

    context 'when settings is organization-scoped' do
      let_it_be(:settings) { create(:work_item_settings, :for_organization, organization: organization) }
      let_it_be(:visibility_default) do
        create(:work_item_type_visibility_default, :for_organization, organization: organization,
          work_item_type_id: issue_type.id)
      end

      let_it_be(:other_visibility_default) do
        create(:work_item_type_visibility_default, namespace: namespace, work_item_type_id: issue_type.id)
      end

      it 'returns visibility defaults scoped to the organization' do
        result = described_class.for_settings(settings)

        expect(result).to include(visibility_default)
        expect(result).not_to include(other_visibility_default)
      end
    end
  end
end
