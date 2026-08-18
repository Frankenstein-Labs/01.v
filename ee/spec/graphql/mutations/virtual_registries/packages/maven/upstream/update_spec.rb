# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::VirtualRegistries::Packages::Maven::Upstream::Update, feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group: group) }
  let_it_be_with_reload(:upstream) { create(:virtual_registries_packages_maven_upstream, registries: [registry]) }

  let(:upstream_global_id) { global_id_of(upstream) }

  let(:params) do
    {
      id: upstream_global_id,
      name: 'Maven Central 2',
      cache_validity_hours: 8,
      metadata_cache_validity_hours: 16
    }
  end

  specify { expect(described_class).to require_graphql_authorizations(:update_virtual_registry) }

  describe '#resolve' do
    subject(:resolve) { described_class.new(object: group, context: query_context, field: nil).resolve(**params) }

    shared_examples 'denying access to maven virtual registries upstream' do
      it 'raises Gitlab::Graphql::Errors::ResourceNotAvailable' do
        expect { resolve }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when user has permission' do
      before_all do
        group.add_owner(current_user)
      end

      before do
        allow(VirtualRegistries::Packages::Maven).to receive(:feature_enabled?)
          .and_return(feature_enabled)
      end

      context 'when maven virtual registry is available' do
        let(:feature_enabled) { true }

        it 'returns upstream' do
          expect(resolve).to eq(
            upstream: upstream,
            errors: []
          )
        end

        it 'updates maven virtual registry upstream' do
          resolve

          expect(upstream.reload).to have_attributes(
            name: 'Maven Central 2',
            cache_validity_hours: 8,
            metadata_cache_validity_hours: 16
          )
        end

        context 'when providing invalid params' do
          let(:params) { super().slice(:id) }

          it 'returns payload as nil' do
            expect(resolve).to eq(
              upstream: nil,
              errors: ['Invalid parameters provided']
            )
          end
        end
      end

      context 'when maven virtual registry is not available' do
        let(:feature_enabled) { false }

        it_behaves_like 'denying access to maven virtual registries upstream'
      end
    end

    context 'when user has no permission' do
      before_all do
        group.add_guest(current_user)
      end

      it_behaves_like 'denying access to maven virtual registries upstream'
    end

    context 'when upstream is not present' do
      let(:upstream_global_id) do
        global_id_of(id: non_existing_record_id, model_name: 'VirtualRegistries::Packages::Maven::Upstream')
      end

      it_behaves_like 'denying access to maven virtual registries upstream'
    end
  end
end
