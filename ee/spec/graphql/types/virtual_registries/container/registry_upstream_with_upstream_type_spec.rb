# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ContainerRegistryUpstreamWithUpstream'], feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:fields) { %i[id position upstream] }
  let_it_be(:registry) { create(:virtual_registries_container_registry) }
  let_it_be(:upstream) { create(:virtual_registries_container_upstream) }
  let_it_be(:registry_upstream) { create(:virtual_registries_container_registry_upstream, registry:, upstream:) }

  let(:batch_loader) { instance_double(Gitlab::Graphql::Loaders::BatchModelLoader) }

  subject { described_class }

  it { is_expected.to have_graphql_fields(fields) }
  it { is_expected.to require_graphql_authorizations(:read_virtual_registry) }
  it { is_expected.to have_attributes(interfaces: include(Types::VirtualRegistries::RegistryUpstreamInterface)) }

  describe '#upstream' do
    before do
      registry_upstream.group.add_developer(user)
    end

    subject(:resolved_upstream) { resolve_field(:upstream, registry_upstream, current_user: user) }

    it 'fetches the upstream' do
      expect(Gitlab::Graphql::Loaders::BatchModelLoader)
        .to receive(:new)
        .with(::VirtualRegistries::Container::Upstream, upstream.id)
        .and_return(batch_loader)
      expect(batch_loader).to receive(:find)

      resolved_upstream
    end
  end
end
