# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::VirtualRegistries::Container::Upstream::Create, feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:registry) { create(:virtual_registries_container_registry, group: group) }

  let(:expected_attributes) do
    {
      group_id: group.id,
      name: 'Docker Central',
      cache_validity_hours: 24,
      url: 'https://docker.io'
    }
  end

  let(:mutation_params) do
    {
      id: ::Gitlab::GlobalId.as_global_id(registry.id,
        model_name: 'VirtualRegistries::Container::Registry'),
      name: 'Docker Central',
      url: 'https://docker.io',
      cache_validity_hours: 24
    }
  end

  let(:query) { GraphQL::Query.new(empty_schema, document: nil, context: {}, variables: {}) }
  let(:context) { GraphQL::Query::Context.new(query: query, values: { current_user: current_user }) }
  let(:mutation) { described_class.new(object: nil, context: context, field: nil) }
  let(:mutated_upstream) { subject[:upstream] }

  specify { expect(described_class).to require_graphql_authorizations(:create_virtual_registry) }

  describe '#resolve' do
    before do
      stub_config(dependency_proxy: { enabled: true })
      stub_licensed_features(container_virtual_registry: true)
      allow(VirtualRegistries::Setting).to receive(:find_for_group).with(group).and_return(build_stubbed(
        :virtual_registries_setting, group: group))
    end

    def resolve
      mutation.resolve(**mutation_params)
    end

    subject(:resolver) { resolve }

    context 'when the registry does not exist' do
      let(:mutation_params) do
        {
          id: ::Gitlab::GlobalId.as_global_id('999999',
            model_name: 'VirtualRegistries::Container::Registry'),
          name: 'Docker Central',
          url: 'https://docker.io',
          cache_validity_hours: 24
        }
      end

      it 'raises an error' do
        expect { resolver }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when the user does not have permission to create an upstream for a virtual registry' do
      it 'raises an error' do
        expect { resolver }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when the user has permissions to create an upstream for a virtual registry' do
      before_all do
        group.add_owner(current_user)
      end

      it 'creates an upstream' do
        expect(mutated_upstream).to have_attributes(expected_attributes)
      end

      context 'when CreateUpstreamService returns an error' do
        before do
          allow_next_instance_of(::VirtualRegistries::CreateUpstreamService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'Invalid URL')
            )
          end
        end

        it 'returns errors' do
          expect(resolver[:errors]).to include('Invalid URL')
          expect(resolver[:upstream]).to be_nil
        end
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
    end

    context 'with container_virtual_registries feature flag turned off' do
      before do
        stub_feature_flags(container_virtual_registries: false)
      end

      it 'raises an exception' do
        expect { resolver }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end
  end
end
