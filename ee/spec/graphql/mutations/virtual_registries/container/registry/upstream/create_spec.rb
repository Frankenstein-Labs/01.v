# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::VirtualRegistries::Container::Registry::Upstream::Create, feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:registry) { create(:virtual_registries_container_registry, group: group) }
  let_it_be(:upstream) { create(:virtual_registries_container_upstream, group: group) }

  let(:expected_attributes) do
    {
      registry_id: registry.id,
      position: 1
    }
  end

  let(:mutation_params) do
    {
      registry_id: registry.to_global_id,
      upstream_id: upstream.to_global_id
    }
  end

  let(:query) { GraphQL::Query.new(empty_schema, document: nil, context: {}, variables: {}) }
  let(:context) { GraphQL::Query::Context.new(query: query, values: { current_user: current_user }) }
  let(:mutation) { described_class.new(object: nil, context: context, field: nil) }
  let(:registry_upstream) { subject[:registry_upstream] }

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

    shared_examples 'raises resource not available error' do
      it 'raises an error' do
        expect { resolver }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when the user does not have permission to create a registry upstream' do
      it_behaves_like 'raises resource not available error'
    end

    context 'when the user has permissions to create a registry upstream' do
      before_all do
        group.add_owner(current_user)
      end

      it 'creates an registry upstream' do
        expect(registry_upstream).to have_attributes(expected_attributes)
      end

      context 'when record is not valid' do
        let(:mutation_params) do
          {
            registry_id: ::Gitlab::GlobalId.as_global_id(non_existing_record_id,
              model_name: 'VirtualRegistries::Container::Registry'),
            upstream_id: ::Gitlab::GlobalId.as_global_id(non_existing_record_id,
              model_name: 'VirtualRegistries::Container::Upstream')
          }
        end

        it_behaves_like 'raises resource not available error'
      end

      context 'when max upstreams per registry is reached' do
        before_all do
          create_list(:virtual_registries_container_registry_upstream,
            VirtualRegistries::Container::RegistryUpstream::MAX_UPSTREAMS_COUNT,
            registry: registry)
        end

        it 'returns errors' do
          expect(resolver[:errors]).to include("Position must be less than or equal to 5")
          expect(registry_upstream).to be_nil
        end
      end

      context 'when upstream does not exist in group' do
        let_it_be(:upstream) { create(:virtual_registries_container_upstream, group: create(:group)) }

        it_behaves_like 'raises resource not available error'
      end

      context 'when the virtual registries setting enabled is false' do
        before do
          allow(VirtualRegistries::Setting).to receive(:find_for_group).with(group).and_return(build_stubbed(
            :virtual_registries_setting, :disabled, group: group))
        end

        it_behaves_like 'raises resource not available error'
      end
    end

    context 'with container_virtual_registries feature flag turned off' do
      before do
        stub_feature_flags(container_virtual_registries: false)
      end

      before_all do
        group.add_owner(current_user)
      end

      it_behaves_like 'raises resource not available error'
    end
  end
end
