# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::VirtualRegistries::Container::UpstreamsResolver, feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:registry) { create(:virtual_registries_container_registry, group: group) }
  let_it_be(:upstream1) do
    create(:virtual_registries_container_upstream, registries: [registry], name: 'upstream1')
  end

  let_it_be(:upstream2) do
    create(:virtual_registries_container_upstream, registries: [registry], name: 'upstream2')
  end

  let(:feature_enabled) { true }
  let(:user_with_permission) { true }

  let(:args) { {} }

  subject(:resolve_upstreams) do
    resolve(described_class, obj: group, args: args, ctx: { current_user: current_user })
  end

  before do
    allow(::VirtualRegistries::Container).to receive_messages(
      feature_enabled?: feature_enabled
    )
    allow(::VirtualRegistries).to receive_messages(
      user_has_access?: user_with_permission
    )
  end

  specify do
    expect(described_class).to have_nullable_graphql_type(
      ::Types::VirtualRegistries::Container::UpstreamType.connection_type
    )
  end

  context 'when unauthorized' do
    let(:user_with_permission) { false }

    it { is_expected.to be_nil }
  end

  context 'when authorized' do
    context 'when container virtual registry is unavailable' do
      let(:feature_enabled) { false }

      it { is_expected.to be_nil }
    end

    context 'when container virtual registry is available' do
      it { expect(resolve_upstreams.items).to contain_exactly(upstream1, upstream2) }

      context 'when filtering by upstream name' do
        let(:args) { { upstream_name: 'upstream1' } }

        it 'filters by upstream name' do
          expect(resolve_upstreams.items).to contain_exactly(upstream1)
        end
      end
    end
  end
end
