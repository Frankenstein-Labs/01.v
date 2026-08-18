# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['MavenRegistryDetails'], feature_category: :virtual_registry do
  include GraphqlHelpers

  subject { described_class }

  let_it_be(:fields) { %i[id name description updated_at registry_upstreams] }

  it { is_expected.to require_graphql_authorizations(:read_virtual_registry) }
  it { is_expected.to have_graphql_fields(fields) }
  it { is_expected.to have_attributes(interfaces: include(Types::VirtualRegistries::RegistryInterface)) }
end
