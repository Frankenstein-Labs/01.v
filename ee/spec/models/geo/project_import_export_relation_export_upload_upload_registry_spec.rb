# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::ProjectImportExportRelationExportUploadUploadRegistry, :geo, feature_category: :geo_replication do
  let_it_be(:registry) { build(:geo_project_import_export_relation_export_upload_upload_registry) }

  specify 'factory is valid' do
    expect(registry).to be_valid
  end

  include_examples 'a Geo framework registry'
  include_examples 'a Geo framework partition upload registry'
end
