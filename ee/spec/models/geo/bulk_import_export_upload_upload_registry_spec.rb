# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::BulkImportExportUploadUploadRegistry, :geo, feature_category: :geo_replication do
  let_it_be(:registry, freeze: true) { build(:geo_bulk_import_export_upload_upload_registry) }

  specify 'factory is valid' do
    expect(registry).to be_valid
  end

  include_examples 'a Geo framework registry'
  include_examples 'a Geo framework partition upload registry'
end
