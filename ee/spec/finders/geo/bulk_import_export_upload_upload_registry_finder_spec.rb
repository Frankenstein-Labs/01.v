# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::BulkImportExportUploadUploadRegistryFinder, feature_category: :geo_replication do
  it_behaves_like 'a framework registry finder', :geo_bulk_import_export_upload_upload_registry
end
