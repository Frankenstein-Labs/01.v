# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::BlobUploadService, feature_category: :geo_replication do
  include EE::GeoHelpers

  let_it_be(:primary, freeze: true) { create(:geo_node, :primary) }

  let(:package_file) do
    file = create(:package_file, :npm)
    checksum = file.class.sha256_hexdigest(file.file.path)
    file.update_column(:verification_checksum, checksum)
    file
  end

  subject { described_class.new(replicable_name: 'package_file', replicable_id: package_file.id, decoded_params: {}) }

  before do
    stub_current_geo_node(primary)
  end

  describe '#initialize' do
    it 'initializes with valid attributes' do
      expect { subject }.not_to raise_error
    end
  end

  describe '#execute' do
    it 'works with valid attributes' do
      expect { subject.execute }.not_to raise_error
    end

    it 'errors with an invalid attributes' do
      service = described_class.new(
        replicable_name: 'package_file',
        replicable_id: non_existing_record_id,
        decoded_params: {}
      )

      response = service.execute

      expect(response).to include(code: :not_found)
    end

    it 'returns a file with valid attributes' do
      service = described_class.new(
        replicable_name: 'package_file',
        replicable_id: package_file.id,
        decoded_params: { checksum: package_file.verification_checksum }
      )

      response = service.execute

      expect(response).to include(code: :ok)
      expect(response[:file].path).to eq(package_file.file.path)
    end
  end
end
