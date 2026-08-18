# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Geo::ContainerRepositoryRegistriesResolver, feature_category: :geo_replication do
  before do
    stub_container_registry_config(enabled: true)
  end

  it_behaves_like 'a Geo registries resolver', :geo_container_repository_registry
end
