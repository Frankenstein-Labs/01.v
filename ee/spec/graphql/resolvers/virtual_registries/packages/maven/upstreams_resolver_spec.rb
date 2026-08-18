# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::VirtualRegistries::Packages::Maven::UpstreamsResolver, feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group: group) }
  let_it_be(:upstream1) do
    create(:virtual_registries_packages_maven_upstream, registries: [registry], name: 'upstream1')
  end

  let_it_be(:upstream2) do
    create(:virtual_registries_packages_maven_upstream, registries: [registry], name: 'upstream2')
  end

  let(:feature_enabled) { true }
  let(:user_has_access) { true }

  let(:args) { {} }

  subject(:resolve_upstreams) do
    resolve(described_class, obj: group, args: args, ctx: { current_user: current_user })
  end

  before do
    allow(::VirtualRegistries::Packages::Maven).to receive_messages(
      feature_enabled?: feature_enabled
    )
    allow(::VirtualRegistries).to receive_messages(
      user_has_access?: user_has_access
    )
  end

  specify do
    expect(described_class).to have_nullable_graphql_type(
      ::Types::VirtualRegistries::Packages::Maven::UpstreamType.connection_type
    )
  end

  context 'when resolving upstream registries' do
    it 'fetches upstreams for the given registry' do
      result = resolve_upstreams

      expect(result.items).to contain_exactly(upstream1, upstream2)
      expect(result.has_next_page).to be false
    end
  end

  context 'when filtering by upstream name' do
    let(:args) { { upstream_name: 'upstream1' } }

    it 'filters by upstream name' do
      result = resolve_upstreams

      expect(result.items).to contain_exactly(upstream1)
    end
  end

  context 'when maven virtual registry is unavailable' do
    let(:feature_enabled) { false }

    it { is_expected.to be_nil }
  end

  context 'when user has no permission to maven virtual registry' do
    let(:user_has_access) { false }

    it { is_expected.to be_nil }
  end
end
