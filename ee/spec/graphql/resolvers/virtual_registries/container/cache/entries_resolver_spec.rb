# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::VirtualRegistries::Container::Cache::EntriesResolver, feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:registry) { create(:virtual_registries_container_registry, group: group) }
  let_it_be_with_reload(:upstream) { create(:virtual_registries_container_upstream, registries: [registry]) }
  let_it_be_with_reload(:entry1) do
    create(:virtual_registries_container_cache_remote_entry, upstream: upstream,
      relative_path: 'library/alpine/manifests/v1')
  end

  let_it_be(:entry2) do
    create(:virtual_registries_container_cache_remote_entry, upstream: upstream,
      relative_path: 'myorg/myapp/manifests/v2')
  end

  let(:virtual_registry_available) { true }

  let(:args) { {} }

  subject(:resolve_entries) do
    resolve(described_class, obj: upstream, args: args, ctx: { current_user: current_user })
  end

  before do
    allow(::VirtualRegistries::Container).to receive(:virtual_registry_available?)
      .and_return(virtual_registry_available)
  end

  specify do
    expect(described_class).to have_nullable_graphql_type(
      ::Types::VirtualRegistries::Container::Cache::EntryType.connection_type
    )
  end

  context 'when unauthorized' do
    it { is_expected.to be_nil }
  end

  context 'when authorized' do
    before_all do
      group.add_guest(current_user)
    end

    context 'when resolving cache entries' do
      it { is_expected.to have_attributes(items: contain_exactly(entry1, entry2), has_next_page: false) }
    end

    context 'when filtering by search' do
      let(:args) { { search: 'library/alpine' } }

      it { is_expected.to have_attributes(items: contain_exactly(entry1), has_next_page: false) }
    end

    context 'when container virtual registry is unavailable' do
      let(:virtual_registry_available) { false }

      it { is_expected.to be_nil }
    end
  end
end
