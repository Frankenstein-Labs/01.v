# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::UserPermissionExportUploadUploadRegistryFinder, feature_category: :geo_replication do
  it_behaves_like 'a framework registry finder', :geo_user_permission_export_upload_upload_registry
end
