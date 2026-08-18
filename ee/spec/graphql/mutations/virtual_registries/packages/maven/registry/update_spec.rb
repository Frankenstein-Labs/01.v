# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::VirtualRegistries::Packages::Maven::Registry::Update, feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:virtual_registry) { create(:virtual_registries_packages_maven_registry, group: group) }

  let(:params) do
    {
      name: 'New name',
      description: 'New description'
    }
  end

  let(:expected_attributes) { params }
  let(:mutation_params) { params.merge(id:) }

  let(:id) { global_id_of(virtual_registry) }

  let(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }
  let(:registry) { subject[:registry] }

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

    context 'when the user does not have permission to update a virtual registry' do
      it_behaves_like 'raises resource not available error'
    end

    context 'when the user has permissions to update a virtual registry' do
      before_all do
        group.add_owner(current_user)
      end

      it 'updates a registry' do
        expect(registry).to have_attributes(expected_attributes)
      end

      context 'when record is not valid' do
        let(:mutation_params) { super().merge(name: nil) }

        it 'returns errors' do
          expect(resolver[:errors]).to include("Name can't be blank")
          expect(registry).to be_nil
        end
      end

      context 'when no params are provided' do
        let(:mutation_params) { { id: } }

        it 'returns errors' do
          expect(resolver[:errors]).to include('Invalid parameters provided')
          expect(registry).to be_nil
        end
      end

      context 'with an invalid registry id' do
        let(:id) do
          global_id_of(id: non_existing_record_id, model_name: 'VirtualRegistries::Packages::Maven::Registry')
        end

        it_behaves_like 'raises resource not available error'
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
