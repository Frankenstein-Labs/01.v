# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ContainerUpstreamDetails'], feature_category: :virtual_registry do
  include GraphqlHelpers

  subject { described_class }

  let_it_be(:fields) do
    %i[id name description url cacheValidityHours username registryUpstreams registriesCount cacheEntries]
  end

  it { is_expected.to require_graphql_authorizations(:read_virtual_registry) }
  it { is_expected.to have_graphql_fields(fields) }
end
