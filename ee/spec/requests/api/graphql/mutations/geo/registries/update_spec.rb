# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Geo::Registries::Update, feature_category: :geo_replication do
  include GraphqlHelpers
  include EE::GeoHelpers

  let(:mutation_name) { :geo_registries_update }

  let_it_be(:current_user) { create(:user, :admin) }
  let_it_be(:primary) { create(:geo_node, :primary) }
  let_it_be(:secondary) { create(:geo_node) }

  include_context 'with geo registries shared context'

  with_them do
    let(:registry) { create(registry_factory) } # rubocop:disable Rails/SaveBang
    let(:registry_class_argument) { registry_class.graphql_enum_key }
    let(:registry_model_primary_key) { registry_class.model_foreign_key.to_s.camelize(:lower) }
    let(:registry_fragment_name) { registry_class_argument.downcase.camelize }
    let(:registry_global_id) { registry.to_global_id.to_s }
    let(:expected_keys) do
      %W[
        id
        state
        retryCount
        lastSyncFailure
        retryAt
        lastSyncedAt
        verifiedAt
        verificationRetryAt
        createdAt
        #{registry_model_primary_key}
      ]
    end

    specify { expect(described_class).to require_graphql_authorizations(:read_geo_registry) }

    def mutation_response
      graphql_mutation_response(mutation_name)
    end

    context 'when geo licensed feature is not available' do
      let_it_be(:current_user) { create(:user) }

      let(:arguments) do
        {
          registry_id: registry_global_id,
          action: 'RESYNC'
        }
      end

      let(:mutation) { graphql_mutation(mutation_name, arguments) }

      it_behaves_like 'a mutation that returns a top-level access error'
    end

    shared_examples 'a registry update action' do |action|
      context 'when it is valid' do
        before do
          stub_current_geo_node(secondary)
        end

        let(:arguments) { { registry_id: registry_global_id, action: action } }

        let(:fields) do
          <<-FIELDS
          registry {
            #{query_graphql_fragment(registry_fragment_name)}
          }
          errors
          FIELDS
        end

        let(:mutation) { graphql_mutation(mutation_name, arguments, fields) }

        it do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(mutation_response["errors"]).to eq([])
          expect(mutation_response["registry"]).to include(*expected_keys)
        end
      end

      context 'when it is invalid' do
        before do
          allow_next_instance_of(Geo::RegistryUpdateService) do |instance|
            allow(instance).to receive(action.downcase.to_sym).and_raise(error)
          end
        end

        let(:arguments) { { registry_id: registry_global_id, action: action } }
        let(:mutation) { graphql_mutation(mutation_name, arguments) }
        let(:error) { StandardError.new }

        it do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(mutation_response["errors"]).to eq(
            ["An error occurred while trying to update the registry: '#{error.message}'."]
          )

          expect(mutation_response["registry"]).to be_nil
        end
      end
    end

    context 'when maintenance mode is enabled' do
      before do
        stub_maintenance_mode_setting(true)
      end

      it_behaves_like 'a registry update action', 'RESYNC'
    end

    context 'with resync action' do
      it_behaves_like 'a registry update action', 'RESYNC'
    end

    context 'with reverify action' do
      it_behaves_like 'a registry update action', 'REVERIFY'
    end

    context 'with granular token authorization' do
      before do
        stub_current_geo_node(secondary)
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL', :update_geo_registry do
        let(:user) { current_user }
        let(:boundary_object) { :instance }
        let(:mutation) do
          graphql_mutation(mutation_name, { registry_id: registry_global_id, action: 'RESYNC' }, 'errors')
        end

        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end
    end
  end
end
