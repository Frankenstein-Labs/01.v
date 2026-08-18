# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'List project secrets needing rotation', :gitlab_secrets_manager, :freeze_time, feature_category: :secrets_management do
  include GraphqlHelpers

  before do
    provision_project_secrets_manager(secrets_manager, current_user)
  end

  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:current_user) { create(:user) }
  let(:inactive_error_message) { "Secrets manager is not active" }
  let(:access_error_message) { Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR }

  let(:list_needing_rotation_query) do
    graphql_query_for(
      'projectSecretsNeedingRotation',
      { project_path: project.full_path },
      "nodes { #{all_graphql_fields_for('ProjectSecret', max_depth: 2)} }"
    )
  end

  let(:secrets_manager) { create(:project_secrets_manager, project: project) }

  context 'when current user is not part of the project' do
    before do
      post_graphql(list_needing_rotation_query, current_user: current_user)
    end

    it_behaves_like 'a query that returns a top-level access error'
  end

  context 'when current user is maintainer but has no policies in OpenBao' do
    let(:current_user) { create(:user, maintainer_of: project) }

    before do
      post_graphql(list_needing_rotation_query, current_user: current_user)
    end

    it 'returns permission error from Openbao' do
      expect(graphql_errors).to be_present
      expect(graphql_errors.first['message']).to include(access_error_message)
    end
  end

  context 'when current user is the project owner' do
    before_all do
      project.add_owner(current_user)
    end

    context 'and the project secrets manager is not active' do
      before do
        secrets_manager.destroy!
        post_graphql(list_needing_rotation_query, current_user: current_user)
      end

      it 'returns a top-level error' do
        expect(graphql_errors).to be_present
        error_messages = graphql_errors.pluck('message')
        expect(error_messages).to match_array([inactive_error_message])
      end
    end

    context 'and the project secrets manager is active' do
      context 'when there are no secrets needing rotation' do
        let!(:ok_secret) do
          create_project_secret(
            user: current_user,
            project: project,
            name: 'OK_SECRET',
            description: 'Secret with OK rotation status',
            branch: 'main',
            environment: 'production',
            value: 'ok-secret-value',
            rotation_interval_days: 365
          )
        end

        it 'returns an empty list' do
          post_graphql(list_needing_rotation_query, current_user: current_user)

          expect(graphql_data_at(:project_secrets_needing_rotation, :nodes)).to eq([])
        end
      end

      context 'when there are secrets needing rotation' do
        let!(:overdue_secret) do
          create_project_secret(
            user: current_user,
            project: project,
            name: 'OVERDUE_SECRET',
            description: 'Overdue secret',
            branch: 'main',
            environment: 'production',
            value: 'overdue-old-value',
            rotation_interval_days: 30
          )
        end

        let!(:approaching_secret) do
          create_project_secret(
            user: current_user,
            project: project,
            name: 'APPROACHING_SECRET',
            description: 'Approaching secret due soon',
            branch: 'staging',
            environment: 'staging',
            value: 'approaching-soon-value',
            rotation_interval_days: 30
          )
        end

        let!(:ok_secret) do
          create_project_secret(
            user: current_user,
            project: project,
            name: 'OK_SECRET',
            description: 'Secret with OK status',
            branch: 'main',
            environment: 'production',
            value: 'ok-secret-value',
            rotation_interval_days: 60
          )
        end

        before do
          overdue_secret.rotation_info.update_columns(
            created_at: 3.months.ago,
            last_reminder_at: 1.day.ago
          )

          approaching_secret.rotation_info.update_columns(
            next_reminder_at: 2.days.from_now
          )
        end

        it 'returns secrets needing rotation in correct priority order' do
          post_graphql(list_needing_rotation_query, current_user: current_user)

          overdue_rotation_info = secret_rotation_info_for_project_secret(project, overdue_secret.name)
          approaching_rotation_info = secret_rotation_info_for_project_secret(project, approaching_secret.name)

          expect(graphql_data_at(:project_secrets_needing_rotation, :nodes))
            .to contain_exactly(
              a_graphql_entity_for(
                project: a_graphql_entity_for(project),
                name: overdue_secret.name,
                description: overdue_secret.description,
                branch: overdue_secret.branch,
                environment: overdue_secret.environment,
                metadata_version: 2,
                rotation_info: a_graphql_entity_for(
                  rotation_interval_days: overdue_rotation_info.rotation_interval_days,
                  status: SecretsManagement::BaseSecretRotationInfo::STATUSES[:overdue],
                  next_reminder_at: overdue_rotation_info.next_reminder_at.iso8601,
                  last_reminder_at: overdue_rotation_info.last_reminder_at.iso8601,
                  updated_at: overdue_rotation_info.updated_at.iso8601,
                  created_at: overdue_rotation_info.created_at.iso8601
                )
              ),
              a_graphql_entity_for(
                project: a_graphql_entity_for(project),
                name: approaching_secret.name,
                description: approaching_secret.description,
                branch: approaching_secret.branch,
                environment: approaching_secret.environment,
                metadata_version: 2,
                rotation_info: a_graphql_entity_for(
                  rotation_interval_days: approaching_rotation_info.rotation_interval_days,
                  status: SecretsManagement::BaseSecretRotationInfo::STATUSES[:approaching],
                  next_reminder_at: approaching_rotation_info.next_reminder_at.iso8601,
                  last_reminder_at: nil,
                  updated_at: approaching_rotation_info.updated_at.iso8601,
                  created_at: approaching_rotation_info.created_at.iso8601
                )
              )
            )
        end

        it 'avoids N+1 queries' do
          control_count = ActiveRecord::QueryRecorder.new do
            post_graphql(list_needing_rotation_query, current_user: current_user)
          end

          # Add another overdue secret
          another_overdue = create_project_secret(
            user: current_user,
            project: project,
            name: 'ANOTHER_OVERDUE',
            description: 'Another overdue secret',
            branch: 'main',
            environment: 'production',
            value: 'another-overdue-value',
            rotation_interval_days: 30
          )

          # Make it overdue
          another_overdue.rotation_info.update_columns(
            created_at: 2.months.ago,
            last_reminder_at: 1.day.ago
          )

          expect do
            post_graphql(list_needing_rotation_query, current_user: current_user)
          end.not_to exceed_query_limit(control_count)
        end

        context 'and service results to a failure' do
          before do
            allow_next_instance_of(SecretsManagement::ProjectSecrets::ListNeedingRotationService) do |service|
              allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'some error'))
            end
          end

          it 'returns the service error' do
            post_graphql(list_needing_rotation_query, current_user: current_user)

            expect(graphql_errors).to include(a_hash_including('message' => 'some error'))
          end
        end
      end
    end
  end

  context 'when user is a developer with proper permissions' do
    let(:current_user) { create(:user, developer_of: project) }

    before do
      provision_project_secrets_manager(secrets_manager, current_user)
      update_project_secrets_permission(
        user: current_user, project: project, actions: %w[read], principal: {
          id: Gitlab::Access.sym_options[:developer], type: 'Role'
        }
      )
    end

    it 'returns success for authorized user' do
      post_graphql(list_needing_rotation_query, current_user: current_user)

      expect(graphql_data_at(:project_secrets_needing_rotation, :nodes)).to eq([])
    end
  end

  context 'when user is a developer with no permissions' do
    let(:current_user) { create(:user, developer_of: project) }

    before do
      provision_project_secrets_manager(secrets_manager, current_user)
      post_graphql(list_needing_rotation_query, current_user: current_user)
    end

    it 'returns permission error from Openbao' do
      expect(graphql_errors).to be_present
      expect(graphql_errors.first['message']).to include(access_error_message)
    end
  end
end
