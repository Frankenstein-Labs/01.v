# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::PackagesDebianProjectComponentFileRegistryFinder, feature_category: :geo_replication do
  it_behaves_like 'a framework registry finder', :geo_packages_debian_project_component_file_registry
end
