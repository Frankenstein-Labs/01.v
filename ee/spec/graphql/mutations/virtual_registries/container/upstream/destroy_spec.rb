# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::VirtualRegistries::Container::Upstream::Destroy, feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:registry) { create(:virtual_registries_container_registry, group: group) }
  let_it_be(:upstream) { create(:virtual_registries_container_upstream, registries: [registry]) }

  let(:mutation_params) do
    {
      id: upstream.to_global_id
    }
  end

  let(:query) { GraphQL::Query.new(empty_schema, document: nil, context: {}, variables: {}) }
  let(:context) { GraphQL::Query::Context.new(query: query, values: { current_user: current_user }) }
  let(:mutation) { described_class.new(object: nil, context: context, field: nil) }

  specify { expect(described_class).to require_graphql_authorizations(:destroy_virtual_registry) }

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

    context 'when the upstream does not exist' do
      let(:mutation_params) do
        {
          id: ::Gitlab::GlobalId.as_global_id(non_existing_record_id,
            model_name: 'VirtualRegistries::Container::Upstream')
        }
      end

      it_behaves_like 'raises resource not available error'
    end

    context 'when the user does not have permission to destroy a upstream' do
      it_behaves_like 'raises resource not available error'
    end

    context 'when the user has permission to destroy a upstream' do
      before_all do
        group.add_maintainer(current_user)
      end

      it 'destroys the given upstream' do
        expect(resolver[:upstream]).to be_destroyed
      end

      context 'when DestroyUpstreamService returns an error' do
        before do
          allow_next_instance_of(::VirtualRegistries::Container::DestroyUpstreamService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'Error')
            )
          end
        end

        it 'returns errors' do
          expect(resolver[:errors]).to include('Error')
          expect(resolver[:upstream]).to be_nil
        end
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

      it_behaves_like 'raises resource not available error'
    end
  end
end
