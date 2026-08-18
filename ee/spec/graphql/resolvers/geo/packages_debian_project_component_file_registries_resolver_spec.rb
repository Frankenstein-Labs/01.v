# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Geo::PackagesDebianProjectComponentFileRegistriesResolver, feature_category: :geo_replication do
  it_behaves_like 'a Geo registries resolver', :geo_packages_debian_project_component_file_registry
end
