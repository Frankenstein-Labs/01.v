# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Geo::PackagesNugetSymbolRegistriesResolver, feature_category: :geo_replication do
  it_behaves_like 'a Geo registries resolver', :geo_packages_nuget_symbol_registry
end
