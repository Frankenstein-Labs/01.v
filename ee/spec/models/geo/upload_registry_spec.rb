# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::UploadRegistry, :geo, type: :model, feature_category: :geo_replication do
  let_it_be(:registry, freeze: true) { build(:geo_upload_registry) }

  specify 'factory is valid' do
    expect(registry).to be_valid
  end

  include_examples 'a Geo framework registry'
  include_examples 'a Geo searchable registry'

  describe '#file' do
    context 'when upload exists' do
      it 'returns the upload path' do
        registry = create(:geo_upload_registry)
        expect(registry.file).to eq(registry.upload.path)
      end
    end

    context 'when upload does not exist' do
      it 'returns a formatted message with the file_id' do
        registry = create(:geo_upload_registry)
        file_id = registry.file_id
        registry.upload.delete
        registry.reload
        registry.association(:upload).reset

        expect(registry.file).to eq("Removed upload with id #{file_id}")
      end
    end
  end
end
