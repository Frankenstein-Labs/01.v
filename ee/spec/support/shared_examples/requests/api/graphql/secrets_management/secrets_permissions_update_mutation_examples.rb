# frozen_string_literal: true

RSpec.shared_examples 'a GraphQL mutation for updating secrets permissions' do |resource_type|
  # Note: The including spec must define:
  # - resource (the project or group)
  # - current_user (the user making the request)
  # - mutation_name (the GraphQL mutation name)
  # - secrets_manager (the secrets manager instance)
  # - provision_secrets_manager (method to provision the secrets manager)
  # - params (the mutation parameters)
  # - service_class (the service class for deleting permissions)
  # - feature_flag_name (the feature flag name to check)
  # - update_permission (method to setup and create the permission to delete)

  let_it_be(:other_user, freeze: false) { create(:user) }

  let(:mutation) { graphql_mutation(mutation_name, params) }
  let(:mutation_response) { graphql_mutation_response(mutation_name) }
  let(:actions) { %w[READ WRITE] }
  let(:expired_at) { 1.week.from_now.to_date.iso8601 }
  let(:principal) { other_user }
  let(:principal_type) { 'USER' }
  let(:principal_params) { { id: principal.id, type: principal_type } }

  subject(:post_mutation) { post_graphql_mutation(mutation, current_user: current_user) }

  context 'when secrets manager is enabled' do
    before do
      provision_secrets_manager(secrets_manager, current_user)
    end

    context "and current user is not part of the #{resource_type}" do
      let_it_be(:user, freeze: false) { create(:user) }

      it_behaves_like 'a mutation on an unauthorized resource'
    end

    context "and current user is not the #{resource_type} owner" do
      before do
        resource.add_maintainer(current_user)
      end

      it_behaves_like 'a mutation on an unauthorized resource'
    end

    shared_examples_for 'a successful update' do
      it 'updates the secrets permission' do
        post_mutation
        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to be_empty

        principal_matcher = a_graphql_entity_for(
          id: principal.id.to_s,
          type: principal_type
        )
        principal_matcher = principal_matcher.and(include('userRoleId' => be_present)) if principal_type == 'USER'

        expect(graphql_data_at(mutation_name, :secrets_permission))
          .to match(a_graphql_entity_for(
            principal: principal_matcher,
            actions: actions,
            expired_at: expired_at
          ))
      end

      it_behaves_like "an API request requiring an exclusive #{resource_type} secret operation lease"
    end

    context "and current user is the #{resource_type} owner" do
      before do
        resource.add_owner(current_user)
      end

      it_behaves_like 'a secrets manager mutation blocked on an inactive namespace' do
        let(:inactive_namespace) { resource }
      end

      it_behaves_like 'a secrets manager mutation blocked on entitlement' do
        let(:payload_key) { 'secretsPermission' }
      end

      context 'and principal is a User' do
        before do
          resource.add_developer(other_user)
        end

        it_behaves_like 'a successful update'

        it 'triggers an internal event' do
          expected_attributes =
            if resource_type == 'project'
              {
                category: 'Mutations::SecretsManagement::ProjectSecretsPermissions::Update',
                project: resource,
                namespace: resource.namespace
              }
            else
              {
                category: 'Mutations::SecretsManagement::GroupSecretsPermissions::Update',
                namespace: resource
              }
            end

          expect { post_mutation }
            .to trigger_internal_events("update_#{resource_type}_secrets_permission")
            .with(user: current_user, **expected_attributes)
        end

        context 'when read_value is granted alongside other actions' do
          let(:actions) { %w[READ WRITE READ_VALUE] }

          it_behaves_like 'a successful update'
        end

        context 'when read_value is the only action granted' do
          let(:actions) { %w[READ_VALUE] }

          it_behaves_like 'a successful update'
        end

        context 'when read_value is granted then revoked' do
          # Note: the including spec must also define `secrets_manager_namespace_path`.
          let(:api_policy_name) do
            secrets_manager.api_policy_name_for_principal(
              principal_type: 'User', principal_id: other_user.id
            )
          end

          it 'removes the read-only API policy', :aggregate_failures do
            post_graphql_mutation(
              graphql_mutation(mutation_name, params.merge(actions: %w[READ READ_VALUE])),
              current_user: current_user
            )
            expect_policy_to_exist(secrets_manager_namespace_path, api_policy_name)

            post_graphql_mutation(
              graphql_mutation(mutation_name, params.merge(actions: %w[READ])),
              current_user: current_user
            )
            expect_policy_not_to_exist(secrets_manager_namespace_path, api_policy_name)
          end
        end
      end

      context 'and principal is a Group' do
        let(:principal_group) { shared_group }
        let(:principal) { principal_group }
        let(:principal_type) { 'GROUP' }

        let(:principal_params) do
          { group_path: principal_group.full_path, type: principal_type }
        end

        it_behaves_like 'a successful update'

        context 'when principal is a Group using id (backward compatibility)' do
          let(:principal_params) do
            { id: principal_group.id, type: principal_type }
          end

          it_behaves_like 'a successful update'
        end

        context 'when group_path does not exist' do
          let(:principal_params) do
            { group_path: 'non/existent/group', type: principal_type }
          end

          it 'returns an error' do
            post_mutation
            expect_graphql_errors_to_include("Group 'non/existent/group' not found")
          end
        end

        context 'when neither id nor group_path is provided' do
          let(:principal_params) do
            { type: principal_type }
          end

          it 'returns an error' do
            post_mutation
            expect_graphql_errors_to_include('Either id or group_path must be provided to identify the principal group')
          end
        end

        context 'when group_path is used with non-Group type without id' do
          let(:principal_type) { 'USER' }

          it 'returns an error' do
            post_mutation
            expect_graphql_errors_to_include('id must be provided to identify the principal')
          end
        end
      end

      context 'and service results to a failure' do
        before do
          allow_next_instance_of(service_class) do |service|
            result = ServiceResponse.error(message: 'some error')
            allow(service).to receive(:execute).and_return(result)
          end
        end

        it 'returns the service error' do
          post_mutation

          expect(mutation_response['errors']).to include('some error')
        end

        it 'does not trigger an internal event' do
          expect { post_mutation }.not_to trigger_internal_events("update_#{resource_type}_secrets_permission")
        end
      end
    end
  end

  context "and feature flag is disabled" do
    before do
      stub_feature_flags(feature_flag_name => false)
      resource.add_owner(current_user)
    end

    it_behaves_like 'a mutation on an unauthorized resource'
  end
end
