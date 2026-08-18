# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Geo::DependencyListExportPartUploadRegistriesResolver, feature_category: :geo_replication do
  it_behaves_like 'a Geo registries resolver', :geo_dependency_list_export_part_upload_registry
end
