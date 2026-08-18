# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::VersionSetEntry, feature_category: :continuous_delivery do
  let_it_be(:application) { create(:cd_application) }
  let_it_be(:service) { create(:cd_service, application: application) }
  let_it_be(:artifact_source) { create(:cd_artifact_source, service: service) }
  let_it_be(:version_set) { create(:cd_version_set, application: application) }
  let_it_be(:version) { create(:cd_version, artifact_source: artifact_source) }

  describe 'associations' do
    it { is_expected.to belong_to(:version_set).required }
    it { is_expected.to belong_to(:version).required }
    it { is_expected.to belong_to(:artifact_source).required }
    it { is_expected.to belong_to(:service).required }
  end

  describe 'validations' do
    subject { build(:cd_version_set_entry, version_set: version_set, version: version) }

    it { is_expected.to be_valid }

    it 'enforces uniqueness of version_id scoped to version_set_id' do
      create(:cd_version_set_entry, version_set: version_set, version: version)

      expect { create(:cd_version_set_entry, version_set: version_set, version: version) }
        .to raise_error(ActiveRecord::RecordInvalid, /Version has already been taken/)
    end

    context 'when another version from the same artifact source already exists in the version set' do
      let_it_be(:version_a) { create(:cd_version, artifact_source: artifact_source, name: 'v1_0_0') }
      let_it_be(:version_b) { create(:cd_version, artifact_source: artifact_source, name: 'v2_0_0') }

      it 'rejects a second version for the same artifact source' do
        create(:cd_version_set_entry, version_set: version_set, version: version_a)

        record = build(:cd_version_set_entry, version_set: version_set, version: version_b)

        expect(record).not_to be_valid
        expect(record.errors[:artifact_source_id]).to include('already has an entry in this version set')
      end
    end
  end

  describe '#populate_artifact_source_id' do
    it 'derives artifact_source_id from version on validation' do
      record = build(:cd_version_set_entry, version_set: version_set, version: version, artifact_source_id: nil)

      record.valid?

      expect(record.artifact_source_id).to eq(artifact_source.id)
    end
  end

  describe '#populate_service_id' do
    it 'derives service_id from version.artifact_source on validation' do
      record = build(:cd_version_set_entry, version_set: version_set, version: version, service_id: nil)

      record.valid?

      expect(record.service_id).to eq(service.id)
    end
  end

  describe 'sharding key' do
    subject { build(:cd_version_set_entry, version_set: version_set, version: version) }

    it { is_expected.to populate_sharding_key(:organization_id).with(version_set.organization_id) }
  end
end
