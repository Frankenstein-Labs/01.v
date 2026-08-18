# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Geo::OrganizationDetailUploadRegistriesResolver, feature_category: :geo_replication do
  it_behaves_like 'a Geo registries resolver', :geo_organization_detail_upload_registry
end
