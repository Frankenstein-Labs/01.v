# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::VirtualRegistries::Packages::Maven::RegistryUpstream::Update, feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group:) }
  let_it_be(:registry_upstream) { create(:virtual_registries_packages_maven_registry_upstream, registry:) }
  let_it_be(:registry_upstream2) { create(:virtual_registries_packages_maven_registry_upstream, registry:) }

  let(:mutation_params) do
    {
      id: registry_upstream.to_global_id,
      position: 2
    }
  end

  let(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

  specify { expect(described_class).to require_graphql_authorizations(:update_virtual_registry) }

  describe '#resolve' do
    before do
      stub_config(dependency_proxy: { enabled: true })
      stub_licensed_features(packages_virtual_registry: true)
      allow(VirtualRegistries::Setting).to receive(:find_for_group).with(group).and_return(build_stubbed(
        :virtual_registries_setting, group: group))
    end

    subject(:resolver) { mutation.resolve(**mutation_params) }

    shared_examples 'raises resource not available error' do
      it 'raises an error' do
        expect { resolver }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when the user does not have permission to update a registry upstream' do
      it_behaves_like 'raises resource not available error'
    end

    context 'when the user has permissions to update a registry upstream' do
      before_all do
        group.add_maintainer(current_user)
      end

      it 'updates a registry upstream position' do
        expect do
          resolver
        end.to change { registry_upstream.reload.position }.from(1).to(2)
      end

      it 'updates all registry upstream positions' do
        expect do
          resolver
        end.to change { registry_upstream2.reload.position }.from(2).to(1)
      end

      context 'when record is not valid' do
        let(:mutation_params) do
          {
            id: global_id_of(id: non_existing_record_id,
              model_name: 'VirtualRegistries::Packages::Maven::RegistryUpstream'),
            position: 1
          }
        end

        it_behaves_like 'raises resource not available error'
      end

      context 'when position is not valid' do
        let(:mutation_params) do
          {
            id: registry_upstream.to_global_id,
            position: 100
          }
        end

        it 'returns errors' do
          expect(resolver).to include(
            errors: ["Position must be less than or equal to 20"]
          )
        end
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
