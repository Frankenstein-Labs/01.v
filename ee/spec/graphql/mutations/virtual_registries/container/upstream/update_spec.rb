# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::VirtualRegistries::Container::Upstream::Update, feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:registry) { create(:virtual_registries_container_registry, group: group) }
  let_it_be_with_reload(:upstream) { create(:virtual_registries_container_upstream, registries: [registry]) }

  let(:upstream_global_id) do
    ::Gitlab::GlobalId.as_global_id(upstream.id, model_name: 'VirtualRegistries::Container::Upstream')
  end

  let(:params) do
    {
      id: upstream_global_id,
      name: 'Docker Central 2',
      cache_validity_hours: 8
    }
  end

  specify { expect(described_class).to require_graphql_authorizations(:update_virtual_registry) }

  describe '#resolve' do
    subject(:resolve) { described_class.new(object: group, context: query_context, field: nil).resolve(**params) }

    shared_examples 'denying access to container virtual registries upstream' do
      it 'raises Gitlab::Graphql::Errors::ResourceNotAvailable' do
        expect { resolve }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when user has permission' do
      before_all do
        group.add_owner(current_user)
      end

      before do
        allow(VirtualRegistries::Container).to receive(:virtual_registry_available?)
          .and_return(virtual_registry_available)
      end

      context 'when container virtual registry is available' do
        let(:virtual_registry_available) { true }

        it 'returns upstream' do
          expect(resolve).to eq(
            upstream: upstream,
            errors: []
          )
        end

        it 'updates container virtual registry upstream' do
          resolve

          expect(upstream.reload).to have_attributes(
            name: 'Docker Central 2',
            cache_validity_hours: 8
          )
        end

        context 'when service execution failed' do
          let(:params) { { id: upstream_global_id } }

          it 'returns payload as nil' do
            expect(resolve).to eq(
              upstream: nil,
              errors: ['Invalid parameters provided']
            )
          end
        end
      end

      context 'when container virtual registry is not available' do
        let(:virtual_registry_available) { false }

        before do
          allow(VirtualRegistries::Container).to receive(:virtual_registry_available?)
            .and_return(virtual_registry_available)
        end

        it_behaves_like 'denying access to container virtual registries upstream'
      end
    end

    context 'when user has no permission' do
      before_all do
        group.add_guest(current_user)
      end

      it_behaves_like 'denying access to container virtual registries upstream'
    end

    context 'when upstream is not present' do
      let(:upstream_global_id) do
        ::Gitlab::GlobalId.as_global_id('999999', model_name: 'VirtualRegistries::Container::Upstream')
      end

      it_behaves_like 'denying access to container virtual registries upstream'
    end
  end
end
