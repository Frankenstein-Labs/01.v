# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Delete project secret', :gitlab_secrets_manager, feature_category: :secrets_management do
  include GraphqlHelpers

  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:owner_user) { create(:user) }
  let_it_be(:mutation_name) { :project_secret_delete }

  let(:secrets_manager) { create(:project_secrets_manager, project: project) }

  let(:project_secret_attributes) do
    {
      name: 'TEST_SECRET',
      description: 'test description',
      branch: 'dev-branch-*',
      environment: 'review/*',
      value: 'test value'
    }
  end

  let(:params) do
    {
      project_path: project.full_path,
      name: project_secret_attributes[:name]
    }
  end

  let(:mutation) { graphql_mutation(mutation_name, params) }
  let(:mutation_response) { graphql_mutation_response(mutation_name) }

  subject(:post_mutation) { post_graphql_mutation(mutation, current_user: current_user) }

  before_all do
    project.add_owner(owner_user)
  end

  before do
    provision_project_secrets_manager(secrets_manager, owner_user)

    create_project_secret(
      **project_secret_attributes.merge(user: owner_user, project: project)
    )
  end

  context 'when current user is not part of the project' do
    it_behaves_like 'a mutation on an unauthorized resource'
  end

  context 'when current user is maintainer, but has no openbao policies' do
    before_all do
      project.add_maintainer(current_user)
    end

    it_behaves_like 'a mutation on an unauthorized resource'
  end

  context 'when current user is the project owner and has proper openbao policies' do
    before_all do
      project.add_owner(current_user)
    end

    it 'deletes the project secret', :aggregate_failures do
      post_mutation

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to be_empty

      expect(graphql_data_at(mutation_name, :project_secret))
        .to match(
          a_graphql_entity_for(
            **project_secret_attributes
              .except(:value)
              .merge(project: a_graphql_entity_for(project))
          )
        )
    end

    it 'triggers an internal event' do
      expect { post_mutation }
        .to trigger_internal_events('delete_project_ci_secret')
        .with(
          category: 'Mutations::SecretsManagement::ProjectSecrets::Delete',
          user: current_user,
          project: project,
          namespace: project.namespace
        )
    end

    context 'and secret does not exist' do
      before do
        params[:name] = 'SOMETHING_ELSE'
      end

      it 'returns a top-level error with message' do
        post_mutation

        expect(mutation_response).to be_nil
        expect(graphql_errors.count).to eq(1)
        expect(graphql_errors.first['message']).to eq('Project secret does not exist.')
      end
    end

    context 'and service results to a failure' do
      before do
        allow_next_instance_of(SecretsManagement::ProjectSecrets::DeleteService) do |service|
          project_secret = SecretsManagement::ProjectSecret.new
          project_secret.errors.add(:base, 'some error')

          result = ServiceResponse.error(message: 'some error', payload: { project_secret: project_secret })
          allow(service).to receive(:execute).and_return(result)
        end
      end

      it 'returns the service error' do
        post_mutation

        expect(mutation_response['errors']).to include('some error')
      end

      it 'does not trigger an internal event' do
        expect { post_mutation }.not_to trigger_internal_events('delete_project_ci_secret')
      end
    end

    context 'and name does not conform' do
      let(:params) do
        {
          project_path: project.full_path,
          name: '../../OTHER_SECRET'
        }
      end

      it 'fails', :aggregate_failures do
        post_mutation

        expect(mutation_response['errors']).to include("Name can contain only letters, digits and '_'.")
      end
    end

    context 'and secrets_manager feature flag is disabled' do
      before do
        stub_feature_flags(secrets_manager: false)
      end

      it_behaves_like 'a mutation on an unauthorized resource'
    end

    it_behaves_like 'an API request requiring an exclusive project secret operation lease'

    it_behaves_like 'a secrets manager mutation blocked on an inactive namespace' do
      let(:inactive_namespace) { project }
    end

    it_behaves_like 'a secrets manager mutation blocked on entitlement' do
      let(:payload_key) { 'projectSecret' }
      let(:service_class) { SecretsManagement::ProjectSecrets::DeleteService }
    end
  end
end
