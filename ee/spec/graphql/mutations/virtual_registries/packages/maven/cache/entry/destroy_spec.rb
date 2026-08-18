# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::VirtualRegistries::Packages::Maven::Cache::Entry::Destroy, :sidekiq_inline, feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group, :private) }
  let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group: group) }
  let_it_be_with_reload(:upstream) { create(:virtual_registries_packages_maven_upstream, registries: [registry]) }
  let_it_be_with_reload(:cache_entry) do
    create(:virtual_registries_packages_maven_cache_remote_entry, upstream: upstream, group: group)
  end

  let(:mutation_params) do
    {
      id: cache_entry.generate_id
    }
  end

  let(:query) { GraphQL::Query.new(empty_schema, document: nil, context: {}, variables: {}) }
  let(:context) { GraphQL::Query::Context.new(query: query, values: { current_user: current_user }) }
  let(:mutation) { described_class.new(object: nil, context: context, field: nil) }

  specify { expect(described_class).to require_graphql_authorizations(:destroy_virtual_registry) }

  describe '#resolve' do
    before do
      stub_config(dependency_proxy: { enabled: true })
      stub_licensed_features(packages_virtual_registry: true)
      allow(VirtualRegistries::Setting).to receive(:find_for_group).with(group).and_return(build_stubbed(
        :virtual_registries_setting, group: group))
    end

    def resolve
      mutation.resolve(**mutation_params)
    end

    subject(:resolver) { resolve }

    shared_examples 'raises resource not available error' do
      it 'raises an error' do
        expect { resolver }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when the id is not valid base64' do
      let(:mutation_params) do
        {
          id: '!!invalid-base64!!'
        }
      end

      it_behaves_like 'raises resource not available error'
    end

    context 'when the cache entry does not exist' do
      let(:mutation_params) do
        {
          id: Base64.urlsafe_encode64("#{non_existing_record_id} #{non_existing_record_id}")
        }
      end

      it_behaves_like 'raises resource not available error'
    end

    context 'when the user does not have permission to delete the cache entry' do
      it_behaves_like 'raises resource not available error'
    end

    context 'when the user has permission to delete a cache entry' do
      before_all do
        group.add_maintainer(current_user)
      end

      it 'marks the cache entry as pending destruction' do
        expect { resolver }.to change { cache_entry.reload.status }.from('default').to('pending_destruction')
      end

      it 'returns the cache entry' do
        expect(resolver[:cache_entry]).to eq(cache_entry)
      end

      context 'when the virtual registries setting enabled is false' do
        before do
          allow(VirtualRegistries::Setting).to receive(:find_for_group).with(group).and_return(build_stubbed(
            :virtual_registries_setting, :disabled, group: group))
        end

        it_behaves_like 'raises resource not available error'
      end

      context 'when packages_virtual_registry licensed feature is unavailable' do
        before do
          stub_licensed_features(packages_virtual_registry: false)
        end

        it_behaves_like 'raises resource not available error'
      end

      context 'with maven_virtual_registry feature flag turned off' do
        before do
          stub_feature_flags(maven_virtual_registry: false)
        end

        it_behaves_like 'raises resource not available error'
      end
    end
  end
end
