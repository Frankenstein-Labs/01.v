# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::VirtualRegistries::Packages::Maven::Upstream::Create, feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group: group) }

  let(:expected_attributes) do
    {
      group_id: group.id,
      name: 'Maven Central',
      cache_validity_hours: 24,
      metadata_cache_validity_hours: 48,
      url: 'https://repo.maven.apache.org/maven2'
    }
  end

  let(:mutation_params) do
    {
      id: ::Gitlab::GlobalId.as_global_id(registry.id, model_name: 'VirtualRegistries::Packages::Maven::Registry'),
      name: 'Maven Central',
      url: 'https://repo.maven.apache.org/maven2',
      cache_validity_hours: 24,
      metadata_cache_validity_hours: 48
    }
  end

  let(:query) { GraphQL::Query.new(empty_schema, document: nil, context: {}, variables: {}) }
  let(:context) { GraphQL::Query::Context.new(query: query, values: { current_user: current_user }) }
  let(:mutation) { described_class.new(object: nil, context: context, field: nil) }
  let(:mutated_upstream) { subject[:upstream] }

  specify { expect(described_class).to require_graphql_authorizations(:create_virtual_registry) }

  describe '#resolve' do
    let(:registry_id) do
      ::Gitlab::GlobalId.as_global_id(registry.id,
        model_name: 'VirtualRegistries::Packages::Maven::Registry')
    end

    before do
      stub_config(dependency_proxy: { enabled: true })
      stub_licensed_features(packages_virtual_registry: true)
      allow(VirtualRegistries::Setting).to receive(:find_for_group).with(group).and_return(build_stubbed(
        :virtual_registries_setting, group: group))
    end

    def resolve
      mutation.resolve(id: registry_id, **mutation_params)
    end

    subject(:resolver) { resolve }

    context 'when the user does not have permission to create an upstream for a maven registry' do
      it 'raises an error' do
        expect { resolver }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when the user has permissions to create an upstream for a maven registry' do
      before_all do
        group.add_owner(current_user)
      end

      it 'creates an upstream' do
        expect(mutated_upstream).to have_attributes(expected_attributes)
      end

      context 'when the virtual registries setting enabled is false' do
        before do
          allow(VirtualRegistries::Setting).to receive(:find_for_group).with(group).and_return(build_stubbed(
            :virtual_registries_setting, :disabled, group: group))
        end

        it 'raises an exception' do
          expect { resolver }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when the registry does not exist' do
        let(:mutation_params) do
          super().merge(
            id: ::Gitlab::GlobalId.as_global_id('999999', model_name: 'VirtualRegistries::Packages::Maven::Registry')
          )
        end

        it 'raises an exception' do
          expect { resolver }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end
    end

    context 'with maven_virtual_registry feature flag turned off' do
      before do
        stub_feature_flags(maven_virtual_registry: false)
      end

      it 'raises an exception' do
        expect { resolver }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when the service call fails', :aggregate_failures do
      let(:mutation_params) { super().merge(cache_validity_hours: nil) }

      before_all do
        group.add_owner(current_user)
      end

      it 'returns nil upstream and errors' do
        expect(mutated_upstream).to be_nil
        expect(resolver[:errors]).to eq(['Cache validity hours is not a number'])
      end
    end
  end
end
