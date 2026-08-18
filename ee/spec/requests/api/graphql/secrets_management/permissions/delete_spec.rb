# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Delete Secret Permission (legacy)', :gitlab_secrets_manager, feature_category: :secrets_management do
  include GraphqlHelpers

  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:other_user) { create(:user) }
  let_it_be(:mutation_name) { :secret_permission_delete }

  let(:secrets_manager) { create(:project_secrets_manager, project: project) }

  let(:params) do
    {
      project_path: project.full_path,
      principal: { id: other_user.id, type: 'USER' }
    }
  end

  let(:mutation) { graphql_mutation(mutation_name, params) }
  let(:mutation_response) { graphql_mutation_response(mutation_name) }

  subject(:post_mutation) { post_graphql_mutation(mutation, current_user: current_user) }

  before_all do
    project.add_reporter(other_user)
  end

  before do
    provision_project_secrets_manager(secrets_manager, current_user)

    update_project_secrets_permission(
      user: current_user, project: project, actions: %w[read],
      principal: { id: other_user.id, type: 'User' }
    )
  end

  context 'when current user is not part of the project' do
    it_behaves_like 'a mutation on an unauthorized resource'
  end

  context 'when current user is not the project owner' do
    before_all do
      project.add_maintainer(current_user)
    end

    it_behaves_like 'a mutation on an unauthorized resource'
  end

  context 'when current user is the project owner' do
    before_all do
      project.add_owner(current_user)
    end

    it 'deletes the secret permission', :aggregate_failures do
      post_mutation

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to be_empty
    end

    it 'triggers an internal event' do
      expect { post_mutation }
        .to trigger_internal_events('delete_project_secrets_permission')
        .with(
          category: 'Mutations::SecretsManagement::Permissions::Delete',
          user: current_user,
          project: project,
          namespace: project.namespace
        )
    end

    it_behaves_like 'a secrets manager mutation blocked on an inactive namespace' do
      let(:inactive_namespace) { project }
    end

    it_behaves_like 'a secrets manager mutation blocked on entitlement' do
      let(:payload_key) { 'secretPermission' }
      let(:service_class) { SecretsManagement::ProjectSecretsPermissions::DeleteService }
    end

    context 'and service results to a failure' do
      it 'returns the service error' do
        expect_next_instance_of(SecretsManagement::ProjectSecretsPermissions::DeleteService) do |service|
          result = ServiceResponse.error(message: 'some error')
          expect(service).to receive(:execute).and_return(result)
        end

        post_mutation

        expect(mutation_response['errors']).to include('some error')
      end
    end
  end
end
