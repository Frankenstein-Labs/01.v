# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::PackageFileReplicator, feature_category: :geo_replication do
  let(:model_record) { build(:package_file, :npm) }

  include_examples 'a blob replicator'

  describe '#calculate_checksum' do
    before do
      model_record.save!
    end

    context 'when verification state is default and verification_checksum is present' do
      it 'returns the legacy verification_checksum attribute' do
        legacy_checksum = 'abc123'
        model_record.update_column(:verification_checksum, legacy_checksum)

        # Reset the verification state to default by updating all fields to nil
        state = model_record.verification_state_object
        state.update_columns(
          verification_started_at: nil,
          verification_retry_at: nil,
          verified_at: nil,
          verification_retry_count: nil,
          verification_checksum: nil,
          verification_failure: nil,
          verification_state: 0
        )

        # Reload to ensure we get the updated state
        model_record.reload

        expect(model_record.verification_state_object.verification_fields_default?).to be(true)
        expect(model_record.replicator.calculate_checksum).to eq(legacy_checksum)
      end
    end

    context 'when verification state has been modified' do
      it 'behaves as usual for separate verification state table and doesnt use the legacy verification_checksum ' \
        'attribute' do
        # Modify the verification state so verification_fields_default? returns false
        model_record.verification_state_object.update!(verification_started_at: Time.current)

        expected_checksum = described_class.model.sha256_hexdigest(model_record.replicator.blob_path)

        expect(model_record.replicator.calculate_checksum).to eq(expected_checksum)
      end
    end

    context 'when verification state is default and verification_checksum is nil' do
      it 'behaves as usual for separate verification state table' do
        model_record.update_column(:verification_checksum, nil)

        # Reset the verification state to default
        state = model_record.verification_state_object
        state.update_columns(
          verification_started_at: nil,
          verification_retry_at: nil,
          verified_at: nil,
          verification_retry_count: nil,
          verification_checksum: nil,
          verification_failure: nil,
          verification_state: 0
        )

        # Reload to ensure we get the updated state
        model_record.reload

        expect(model_record.verification_state_object.verification_fields_default?).to be(true)

        expected_checksum = described_class.model.sha256_hexdigest(model_record.replicator.blob_path)

        expect(model_record.replicator.calculate_checksum).to eq(expected_checksum)
      end
    end
  end
end
