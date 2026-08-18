# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Geo::BulkImportExportUploadUploadRegistriesResolver, feature_category: :geo_replication do
  it_behaves_like 'a Geo registries resolver', :geo_bulk_import_export_upload_upload_registry
end
