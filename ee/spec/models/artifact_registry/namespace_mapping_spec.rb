# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ArtifactRegistry::NamespaceMapping, feature_category: :artifact_registry do
  let_it_be(:organization) { create(:organization) }

  subject(:mapping) { build(:artifact_registry_namespace_mapping, organization: organization) }

  describe 'associations' do
    it { is_expected.to belong_to(:organization).class_name('Organizations::Organization').required }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:ar_namespace_id) }

    it 'allows at most one mapping per organization' do
      create(:artifact_registry_namespace_mapping, organization: organization)

      expect(mapping).to be_invalid
      expect(mapping.errors[:organization]).to include('has already been taken')
    end

    it 'enforces one mapping per organization at the database level' do
      create(:artifact_registry_namespace_mapping, organization: organization)
      duplicate = build(:artifact_registry_namespace_mapping, organization: organization)

      expect { duplicate.save!(validate: false) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe 'schema' do
    it 'holds only the organization, the AR namespace UUID, and timestamps' do
      expect(described_class.column_names)
        .to contain_exactly('id', 'organization_id', 'ar_namespace_id', 'created_at', 'updated_at')
    end
  end

  describe 'organization deletion' do
    it 'cascades: destroying the organization removes the mapping' do
      persisted = create(:artifact_registry_namespace_mapping, organization: organization)

      organization.delete

      expect(described_class.exists?(persisted.id)).to be(false)
    end
  end
end
