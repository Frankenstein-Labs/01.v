# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::Tools::Resolutions::DeleteOrphanedUploads, :geo, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  let(:error_type) { Geo::Errors::ErrorType.find_by(name: 'orphaned_uploads') }
  let(:orphaned) do
    create(:upload, :verification_failed, verification_failure: 'The model which owns this upload is missing')
  end

  let(:other_failure) do
    create(:upload, :verification_failed, verification_failure: 'Could not calculate the checksum')
  end

  subject(:resolution) { described_class.new(error_type) }

  before do
    # Verification details are only persisted to the separate state table on a primary, so
    # stub the primary node before the uploads are created.
    stub_current_geo_node(create(:geo_node, :primary))
    orphaned
    other_failure
  end

  describe '#affected_count' do
    it 'counts only uploads matching the pattern' do
      expect(resolution.affected_count).to eq(1)
    end

    it 'counts matches spread across batches' do
      stub_const("#{described_class.superclass}::BATCH_SIZE", 1)
      create(:upload, :verification_failed, verification_failure: 'The model which owns this upload is missing')

      expect(resolution.affected_count).to eq(2)
    end
  end

  describe '#apply' do
    it 'deletes the matching uploads and leaves the others' do
      expect { resolution.apply }.to change { Upload.exists?(orphaned.id) }.from(true).to(false)
      expect(Upload.exists?(other_failure.id)).to be(true)
    end

    it 'respects the limit' do
      create(:upload, :verification_failed, verification_failure: 'The model which owns this upload is missing')

      expect { resolution.apply(limit: 1) }.to change { Upload.count }.by(-1)
    end

    it 'deletes matches spread across batches and leaves the others', :aggregate_failures do
      stub_const("#{described_class.superclass}::BATCH_SIZE", 1)
      another = create(:upload, :verification_failed,
        verification_failure: 'The model which owns this upload is missing')

      expect { resolution.apply }.to change { Upload.count }.by(-2)
      expect(Upload.exists?(orphaned.id)).to be(false)
      expect(Upload.exists?(another.id)).to be(false)
      expect(Upload.exists?(other_failure.id)).to be(true)
    end
  end

  describe 'across multiple upload partitions' do
    # uploads is PARTITION BY LIST (model_type); the default :upload factory writes to the
    # project_uploads partition. Seed a second partition (namespace_uploads, via a group
    # upload) to prove per-partition iteration counts and deletes matches in every partition.
    let!(:namespace_orphaned) do
      create(:upload, :namespace_upload, :verification_failed,
        verification_failure: 'The model which owns this upload is missing')
    end

    it 'counts and deletes matches in every partition', :aggregate_failures do
      expect(resolution.affected_count).to eq(2)

      expect { resolution.apply }.to change { Upload.count }.by(-2)
      expect(Upload.exists?(orphaned.id)).to be(false)           # project_uploads
      expect(Upload.exists?(namespace_orphaned.id)).to be(false) # namespace_uploads
      expect(Upload.exists?(other_failure.id)).to be(true)
    end
  end

  context 'when the error type has no match pattern' do
    let(:error_type) { instance_double(Geo::Errors::ErrorType, match_pattern: nil) }

    it 'acts on nothing', :aggregate_failures do
      expect(resolution.affected_count).to eq(0)
      expect { resolution.apply }.not_to change { Upload.count }
    end
  end
end
