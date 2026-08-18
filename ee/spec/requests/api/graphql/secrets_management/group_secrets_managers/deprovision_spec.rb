# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Deprovision secrets manager on a group', :gitlab_secrets_manager, feature_category: :secrets_management do
  include GraphqlHelpers

  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:mutation_name) { :group_secrets_manager_deprovision }

  let(:secrets_manager) { create(:group_secrets_manager, group: group) }

  let(:mutation) { graphql_mutation(mutation_name, group_path: group.full_path) }
  let(:mutation_response) { graphql_mutation_response(mutation_name) }

  subject(:post_mutation) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    provision_group_secrets_manager(secrets_manager, current_user)
  end

  context 'when current user is not part of the group' do
    it_behaves_like 'a mutation on an unauthorized resource'
  end

  context 'when current user is not the group owner' do
    before_all do
      group.add_maintainer(current_user)
    end

    it_behaves_like 'a mutation on an unauthorized resource'
  end

  context 'when current user is the group owner' do
    before_all do
      group.add_owner(current_user)
    end

    it 'initiates deprovisioning the secrets manager on the group', :aggregate_failures do
      post_mutation

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to be_empty

      expect(graphql_data_at(mutation_name, :group_secrets_manager))
        .to match(a_graphql_entity_for(
          group: a_graphql_entity_for(group),
          status: 'DEPROVISIONING'
        ))
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { 'disable_ci_secrets_manager_for_group' }
      let(:project) { nil }
      let(:namespace) { group }
      let(:user) { current_user }
      let(:category) { 'Mutations::SecretsManagement::GroupSecretsManagers::Deprovision' }
    end

    it_behaves_like 'a secrets manager mutation blocked on entitlement' do
      let(:payload_key) { 'groupSecretsManager' }
      let(:service_class) { SecretsManagement::GroupSecretsManagers::InitiateDeprovisionService }
    end

    context 'and service results to a failure' do
      before do
        allow_next_instance_of(SecretsManagement::GroupSecretsManagers::InitiateDeprovisionService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'some error'))
        end
      end

      it 'returns the service error' do
        expect_next_instance_of(SecretsManagement::GroupSecretsManagers::InitiateDeprovisionService) do |service|
          result = ServiceResponse.error(message: 'some error')
          expect(service).to receive(:execute).and_return(result)
        end

        post_mutation

        expect(mutation_response['errors']).to include('some error')
      end

      it_behaves_like 'internal event not tracked'
    end

    context 'and group_secrets_manager feature flag is disabled' do
      before do
        stub_feature_flags(group_secrets_manager: false)
      end

      it_behaves_like 'a mutation on an unauthorized resource'
    end
  end
end
