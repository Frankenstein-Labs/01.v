# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::OrganizationDetailUploadRegistryFinder, feature_category: :geo_replication do
  it_behaves_like 'a framework registry finder', :geo_organization_detail_upload_registry
end
