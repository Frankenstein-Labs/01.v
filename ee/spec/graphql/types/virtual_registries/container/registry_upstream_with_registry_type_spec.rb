# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ContainerRegistryUpstreamWithRegistry'], feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:fields) { %i[id position registry] }
  let_it_be(:registry) { create(:virtual_registries_container_registry) }
  let_it_be(:registry_upstream) { create(:virtual_registries_container_registry_upstream, registry:) }

  let(:batch_loader) { instance_double(Gitlab::Graphql::Loaders::BatchModelLoader) }

  subject { described_class }

  it { is_expected.to have_graphql_fields(fields) }
  it { is_expected.to require_graphql_authorizations(:read_virtual_registry) }
  it { is_expected.to have_attributes(interfaces: include(Types::VirtualRegistries::RegistryUpstreamInterface)) }

  describe '#registry' do
    subject(:resolved_registry) { resolve_field(:registry, registry_upstream, current_user: user) }

    before do
      registry_upstream.group.add_guest(user)
    end

    it 'fetches the registry' do
      expect(Gitlab::Graphql::Loaders::BatchModelLoader)
        .to receive(:new)
        .with(::VirtualRegistries::Container::Registry, registry.id)
        .and_return(batch_loader)
      expect(batch_loader).to receive(:find)

      resolved_registry
    end
  end
end
