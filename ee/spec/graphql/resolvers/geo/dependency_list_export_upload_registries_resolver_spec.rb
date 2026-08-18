# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Geo::DependencyListExportUploadRegistriesResolver, feature_category: :geo_replication do
  it_behaves_like 'a Geo registries resolver', :geo_dependency_list_export_upload_registry
end
