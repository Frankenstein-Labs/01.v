# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update project secret', :gitlab_secrets_manager, :freeze_time, feature_category: :secrets_management do
  include GraphqlHelpers

  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:owner_user) { create(:user) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:mutation_name) { :project_secret_update }

  let(:secrets_manager) { create(:project_secrets_manager, project: project) }

  let(:project_secret_attributes) do
    {
      name: 'TEST_SECRET',
      description: 'test description',
      branch: 'main',
      environment: 'prod',
      value: 'test value',
      rotation_interval_days: 10
    }
  end

  let(:params) do
    {
      project_path: project.full_path,
      name: project_secret_attributes[:name],
      description: 'updated description',
      branch: 'feature',
      environment: 'staging',
      metadata_cas: 2,
      rotation_interval_days: 30
    }
  end

  let(:mutation) { graphql_mutation(mutation_name, params) }
  let(:mutation_response) { graphql_mutation_response(mutation_name) }

  subject(:post_mutation) { post_graphql_mutation(mutation, current_user: current_user) }

  before_all do
    project.add_owner(owner_user)
  end

  before do
    stub_last_activity_update
    provision_project_secrets_manager(secrets_manager, owner_user)

    create_project_secret(
      **project_secret_attributes.merge(user: owner_user, project: project)
    )
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

  shared_examples_for 'a successful update request' do
    it 'updates the project secret', :aggregate_failures do
      post_mutation

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to be_empty

      new_version = 3
      rotation_info = secret_rotation_info_for_project_secret(project, params[:name], new_version)

      expect(graphql_data_at(mutation_name, :project_secret))
        .to match(a_graphql_entity_for(
          project: a_graphql_entity_for(project),
          name: project_secret_attributes[:name],
          description: 'updated description',
          branch: 'feature',
          environment: 'staging',
          metadata_version: new_version,
          status: 'COMPLETED',
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
      let(:event) { 'update_ci_secret' }
      let(:user) { current_user }
      let(:namespace) { project.namespace }
      let(:category) { 'Mutations::SecretsManagement::ProjectSecrets::Update' }
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

    it_behaves_like 'a successful update request'

    it_behaves_like 'a secrets manager mutation blocked on an inactive namespace' do
      let(:inactive_namespace) { project }
    end

    it_behaves_like 'a secrets manager mutation blocked on entitlement' do
      let(:payload_key) { 'projectSecret' }
      let(:service_class) { SecretsManagement::ProjectSecrets::UpdateService }
    end

    context 'when secret is stale' do
      let(:client) { secrets_manager_client.with_namespace(namespace) }
      let(:mount) { project.secrets_manager.ci_secrets_mount_path }
      let(:namespace) { project.secrets_manager.full_project_namespace_path }

      shared_examples 'stale secret validation' do |expected_error|
        before do
          secret_path = secrets_manager.ci_data_path(project_secret_attributes[:name])

          metadata = {
            description: 'test description',
            environment: project_secret_attributes[:environment],
            branch: project_secret_attributes[:branch]
          }

          metadata[:create_completed_at] = stale_create_completed_at if stale_create_completed_at
          metadata[:update_started_at] = stale_update_started_at if stale_update_started_at
          metadata[:update_completed_at] = stale_update_completed_at if stale_update_completed_at

          client.update_kv_secret_metadata(
            mount,
            secret_path,
            metadata,
            metadata_cas: stale_metadata_cas
          )
        end

        it 'returns a validation error', :aggregate_failures do
          post_mutation

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['errors']).to include(expected_error)
        end

        it_behaves_like 'internal event not tracked'
      end

      context 'when secret is stale after creation' do
        let(:stale_create_completed_at) { nil }
        let(:stale_update_started_at) { nil }
        let(:stale_update_completed_at) { nil }
        let(:stale_metadata_cas) { 2 }

        let(:params) do
          {
            project_path: project.full_path,
            name: project_secret_attributes[:name],
            description: 'updated description',
            metadata_cas: 2
          }
        end

        it_behaves_like 'stale secret validation', 'Secret create in progress.'
      end

      context 'when secret is stale after update' do
        let(:stale_create_completed_at) { 2.days.ago.iso8601 }
        let(:stale_update_started_at) do
          (Time.current - SecretsManagement::ProjectSecret::STALE_THRESHOLD - 1.hour).iso8601
        end

        let(:stale_update_completed_at) { nil }
        let(:stale_metadata_cas) { 2 }

        let(:params) do
          {
            project_path: project.full_path,
            name: project_secret_attributes[:name],
            description: 'updated description',
            metadata_cas: 3
          }
        end

        it_behaves_like 'stale secret validation', 'Secret update did not complete and is now stale.'
      end
    end

    context 'with partial updates' do
      let(:params) do
        {
          project_path: project.full_path,
          name: project_secret_attributes[:name],
          description: 'updated description',
          metadata_cas: 2
        }
      end

      it 'updates only the specified fields but clears the rotation info', :aggregate_failures do
        post_mutation

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to be_empty

        expect(graphql_data_at(mutation_name, :project_secret))
          .to match(a_graphql_entity_for(
            name: project_secret_attributes[:name],
            description: 'updated description',
            branch: project_secret_attributes[:branch],
            environment: project_secret_attributes[:environment],
            metadata_version: 3,
            rotation_info: nil
          ))

        # Can't check the value directly in GraphQL response, but we can verify it was updated
        secret_path = secrets_manager.ci_data_path(project_secret_attributes[:name])
        expect_kv_secret_to_have_value(
          project.secrets_manager.full_project_namespace_path,
          project.secrets_manager.ci_secrets_mount_path,
          secret_path,
          'test value'
        )
      end
    end

    context 'with value update' do
      let(:params) do
        {
          project_path: project.full_path,
          name: project_secret_attributes[:name],
          secret: 'new-secret-value',
          metadata_cas: 2
        }
      end

      it 'updates the value', :aggregate_failures do
        post_mutation

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to be_empty

        expect(graphql_data_at(mutation_name, :project_secret))
          .to match(a_graphql_entity_for(
            metadata_version: 3
          ))

        # Can't check the value directly in GraphQL response, but we can verify it was updated
        secret_path = secrets_manager.ci_data_path(project_secret_attributes[:name])
        expect_kv_secret_to_have_value(
          project.secrets_manager.full_project_namespace_path,
          project.secrets_manager.ci_secrets_mount_path,
          secret_path,
          'new-secret-value'
        )
      end
    end

    context 'when metadata_cas is not provided' do
      let(:params) do
        {
          project_path: project.full_path,
          name: project_secret_attributes[:name],
          description: 'updated description',
          branch: 'feature',
          environment: 'staging'
        }
      end

      it 'returns an error', :aggregate_failures do
        post_mutation

        expect_graphql_errors_to_include(
          "ProjectSecretUpdateInput! was provided invalid value for metadataCas"
        )
      end
    end

    context 'when secret does not exist' do
      let(:params) do
        {
          project_path: project.full_path,
          name: 'NON_EXISTENT_SECRET',
          description: 'updated description',
          metadata_cas: 2
        }
      end

      it 'returns a top-level error with message' do
        post_mutation

        expect(mutation_response).to be_nil
        expect(graphql_errors.count).to eq(1)
        expect(graphql_errors.first['message']).to eq('Project secret does not exist.')
      end

      it_behaves_like 'internal event not tracked'
    end

    context 'and service results to a failure' do
      let(:params) do
        {
          project_path: project.full_path,
          name: project_secret_attributes[:name],
          description: 'updated description',
          metadata_cas: 999
        }
      end

      it 'returns the service error' do
        post_mutation

        error_message = 'This secret has been modified recently. Please refresh the page and try again.'
        expect(mutation_response['errors']).to contain_exactly(error_message, error_message)
      end
    end

    context 'and secrets_manager feature flag is disabled' do
      before do
        stub_feature_flags(secrets_manager: false)
      end

      it_behaves_like 'a mutation on an unauthorized resource'
    end
  end
end
