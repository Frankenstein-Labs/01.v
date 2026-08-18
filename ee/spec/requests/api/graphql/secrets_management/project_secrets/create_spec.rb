# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create project secret', :gitlab_secrets_manager, :freeze_time, feature_category: :secrets_management do
  include GraphqlHelpers

  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:mutation_name) { :project_secret_create }

  let(:secrets_manager) { create(:project_secrets_manager, project: project) }

  let(:params) do
    {
      project_path: project.full_path,
      name: 'TEST_SECRET',
      description: 'test description',
      secret: 'the-secret-value',
      branch: 'main',
      environment: 'prod',
      rotation_interval_days: 30
    }
  end

  let(:mutation) { graphql_mutation(mutation_name, params) }
  let(:mutation_response) { graphql_mutation_response(mutation_name) }

  subject(:post_mutation) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    stub_last_activity_update
    provision_project_secrets_manager(secrets_manager, current_user)
  end

  after do
    cancel_exclusive_project_secret_operation_lease(project)
  end

  context 'when current user is not part of the project' do
    it_behaves_like 'a mutation on an unauthorized resource'
  end

  context 'when current user does not have write permissions in openbao' do
    before_all do
      project.add_maintainer(current_user)
    end

    it_behaves_like 'a mutation on an unauthorized resource'
  end

  shared_examples_for 'a successful create request' do
    it 'creates the project secret', :aggregate_failures do
      post_mutation

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to be_empty

      rotation_info = secret_rotation_info_for_project_secret(project, params[:name])

      expect(graphql_data_at(mutation_name, :project_secret))
        .to match(a_graphql_entity_for(
          project: a_graphql_entity_for(project),
          name: params[:name],
          description: params[:description],
          branch: params[:branch],
          environment: params[:environment],
          metadata_version: 2,
          rotation_info: a_graphql_entity_for(
            rotation_interval_days: rotation_info.rotation_interval_days,
            status: SecretsManagement::BaseSecretRotationInfo::STATUSES[:ok],
            updated_at: rotation_info.updated_at.iso8601,
            created_at: rotation_info.created_at.iso8601,
            next_reminder_at: rotation_info.next_reminder_at.iso8601,
            last_reminder_at: nil
          )
        ))
    end

    it_behaves_like 'an API request requiring an exclusive project secret operation lease'

    it_behaves_like 'internal event tracking' do
      let(:event) { 'create_ci_secret' }
      let(:user) { current_user }
      let(:namespace) { project.namespace }
      let(:category) { 'Mutations::SecretsManagement::ProjectSecrets::Create' }
    end
  end

  context 'when current user was granted write permissions in openbao' do
    before_all do
      project.add_maintainer(current_user)
    end

    before do
      update_project_secrets_permission(
        user: current_user, project: project, actions: %w[write read], principal: {
          id: Gitlab::Access.sym_options[:maintainer], type: 'Role'
        }
      )
    end

    it_behaves_like 'a successful create request'

    context 'and service results to a failure' do
      before do
        allow_next_instance_of(SecretsManagement::ProjectSecrets::CreateService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'some error'))
        end
      end

      it 'returns the service error' do
        expect_next_instance_of(SecretsManagement::ProjectSecrets::CreateService) do |service|
          project_secret = SecretsManagement::ProjectSecret.new
          project_secret.errors.add(:base, 'some error')

          result = ServiceResponse.error(message: 'some error', payload: { secret: project_secret })
          expect(service).to receive(:execute).and_return(result)
        end

        post_mutation

        expect(mutation_response['errors']).to include('some error')
      end

      it_behaves_like 'internal event not tracked'
    end

    context 'and secrets_manager feature flag is disabled' do
      before do
        stub_feature_flags(secrets_manager: false)
      end

      it_behaves_like 'a mutation on an unauthorized resource'
    end
  end

  context 'when current user is project owner' do
    before_all do
      project.add_owner(current_user)
    end

    it_behaves_like 'a successful create request'

    it_behaves_like 'a secrets manager mutation blocked on an inactive namespace' do
      let(:inactive_namespace) { project }
    end

    it_behaves_like 'a secrets manager mutation blocked on entitlement' do
      let(:payload_key) { 'projectSecret' }
      let(:service_class) { SecretsManagement::ProjectSecrets::CreateService }
    end
  end
end
