# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ContainerRegistry'], feature_category: :virtual_registry do
  include GraphqlHelpers

  subject { described_class }

  let_it_be(:fields) { %i[id name description updated_at] }

  it 'uses CountableConnectionType' do
    expect(described_class.connection_type_class).to eq(::Types::CountableConnectionType)
  end

  it { is_expected.to require_graphql_authorizations(:read_virtual_registry) }
  it { is_expected.to have_graphql_fields(fields) }
  it { is_expected.to have_attributes(interfaces: include(Types::VirtualRegistries::RegistryInterface)) }
end
