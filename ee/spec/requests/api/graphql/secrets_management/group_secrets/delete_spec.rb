# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Delete group secret', :gitlab_secrets_manager, :freeze_time, feature_category: :secrets_management do
  include GraphqlHelpers

  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:owner_user) { create(:user) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:mutation_name) { :group_secret_delete }

  let(:secrets_manager) { create(:group_secrets_manager, group: group) }

  let(:group_secret_attributes) do
    {
      name: 'TEST_SECRET',
      description: 'test description',
      environment: 'production',
      protected: true,
      value: 'test value'
    }
  end

  let(:params) do
    {
      group_path: group.full_path,
      name: group_secret_attributes[:name]
    }
  end

  let(:mutation) { graphql_mutation(mutation_name, params) }
  let(:mutation_response) { graphql_mutation_response(mutation_name) }

  subject(:post_mutation) { post_graphql_mutation(mutation, current_user: current_user) }

  before_all do
    group.add_owner(owner_user)
  end

  before do
    stub_last_activity_update
    provision_group_secrets_manager(secrets_manager, owner_user)

    # Create initial secret
    SecretsManagement::GroupSecrets::CreateService.new(group, owner_user).execute(
      **group_secret_attributes
    )
  end

  after do
    cancel_exclusive_group_secret_operation_lease(group)
  end

  context 'when current user is not part of the group' do
    it_behaves_like 'a mutation on an unauthorized resource'
  end

  context 'when current user does not have delete permissions in openbao' do
    before_all do
      group.add_maintainer(current_user)
    end

    it_behaves_like 'a mutation on an unauthorized resource'
  end

  shared_examples_for 'a successful delete request' do
    it 'deletes the group secret', :aggregate_failures do
      post_mutation

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to be_empty

      expect(graphql_data_at(mutation_name, :group_secret))
        .to match(a_graphql_entity_for(
          group: a_graphql_entity_for(group),
          name: group_secret_attributes[:name],
          description: group_secret_attributes[:description],
          environment: group_secret_attributes[:environment],
          protected: group_secret_attributes[:protected]
        ))

      # Verify secret is actually deleted from OpenBao
      expect_kv_secret_not_to_exist(
        group.secrets_manager.full_group_namespace_path,
        group.secrets_manager.ci_secrets_mount_path,
        secrets_manager.ci_data_path(group_secret_attributes[:name])
      )
    end

    it_behaves_like 'an API request requiring an exclusive group secret operation lease'

    it_behaves_like 'internal event tracking' do
      let(:event) { 'delete_group_ci_secret' }
      let(:user) { current_user }
      let(:namespace) { group }
      let(:category) { 'Mutations::SecretsManagement::GroupSecrets::Delete' }
    end
  end

  context 'when current user was granted delete permissions in openbao' do
    before_all do
      group.add_maintainer(current_user)
    end

    before do
      update_group_secrets_permission(
        user: current_user, group: group, actions: %w[write read delete], principal: {
          id: Gitlab::Access.sym_options[:maintainer], type: 'Role'
        }
      )
    end

    it_behaves_like 'a successful delete request'

    context 'when the secret does not exist' do
      let(:params) do
        {
          group_path: group.full_path,
          name: 'NON_EXISTENT_SECRET'
        }
      end

      it 'returns a top-level error with message' do
        post_mutation

        expect(mutation_response).to be_nil
        expect(graphql_errors.count).to eq(1)
        expect(graphql_errors.first['message']).to eq('Group secret does not exist.')
      end

      it_behaves_like 'internal event not tracked'
    end

    context 'and service results to a failure' do
      before do
        allow_next_instance_of(SecretsManagement::GroupSecrets::DeleteService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'some error'))
        end
      end

      it 'returns the service error' do
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

  context 'when current user is group owner' do
    before_all do
      group.add_owner(current_user)
    end

    it_behaves_like 'a successful delete request'

    it_behaves_like 'a secrets manager mutation blocked on an inactive namespace' do
      let(:inactive_namespace) { group }
    end

    it_behaves_like 'a secrets manager mutation blocked on entitlement' do
      let(:payload_key) { 'groupSecret' }
      let(:service_class) { SecretsManagement::GroupSecrets::DeleteService }
    end
  end
end
