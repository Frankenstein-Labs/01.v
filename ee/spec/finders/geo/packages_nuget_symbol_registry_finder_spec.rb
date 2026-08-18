# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::PackagesNugetSymbolRegistryFinder, feature_category: :geo_replication do
  it_behaves_like 'a framework registry finder', :geo_packages_nuget_symbol_registry
end
