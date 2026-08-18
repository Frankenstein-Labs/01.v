# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Creating a work item type', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:user) { create(:user, maintainer_of: group) }
  let_it_be(:organization_owner) { create(:user, owner_of: current_organization) }

  let(:name) { 'Custom Work Item Type' }
  let(:icon_name) { 'bug' }
  let(:params) do
    {
      full_path: group.full_path,
      name: name,
      icon_name: icon_name
    }
  end

  let(:current_user) { user }

  let(:mutation) { graphql_mutation(:work_item_type_create, params) }
  let(:mutation_response) { graphql_mutation_response(:work_item_type_create) }
  let(:unauthorized_error_message) do
    "The resource that you are attempting to access does not exist or you don't have permission to perform this action"
  end

  before do
    stub_licensed_features(configurable_work_item_types: true)
    stub_saas_features(namespace_scoped_work_item_types: true)
  end

  RSpec.shared_examples 'creates work item type successfully' do
    it 'creates work item type' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_be_empty

      expect(mutation_response['workItemType']).to include(
        'name' => name,
        'iconName' => 'bug'
      )
      expect(mutation_response['errors']).to be_empty
    end
  end

  RSpec.shared_examples 'returns error response' do
    it 'returns error response' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_be_empty
      expect(mutation_response['workItemType']).to be_nil
      expect(mutation_response['errors']).to include(expected_error_message)
    end
  end

  context 'when name is not provided' do
    let(:params) { super().except(:name) }

    it 'returns a validation error' do
      post_graphql_mutation(mutation, current_user: user)

      expect(response).to have_gitlab_http_status(:success)
      expect(graphql_errors).to include(
        a_hash_including(
          'message' => a_string_matching(/Expected value to not be null/)
        )
      )
    end
  end

  context 'when icon_name is invalid' do
    let(:icon_name) { 'invalid_icon' }

    it 'returns a validation error with valid icon names' do
      post_graphql_mutation(mutation, current_user: user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_be_empty
      expect(mutation_response['workItemType']).to be_nil
      expect(mutation_response['errors']).to include(a_string_matching(/Icon name is not valid./))
    end
  end

  context 'when full_path is a subgroup' do
    let(:params) { super().merge(full_path: subgroup.full_path) }

    it 'returns authorization error' do
      post_graphql_mutation(mutation, current_user: user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_include(unauthorized_error_message)
    end
  end

  context 'when full_path is not provided' do
    let(:expected_error_message) { 'Work item types can only be modified at the root group level' }
    let(:current_user) { organization_owner }
    let(:params) { super().except(:full_path) }

    it_behaves_like 'returns error response'
  end

  context 'when licensed feature is not available' do
    before do
      stub_licensed_features(configurable_work_item_types: false)
    end

    it 'returns authorization error' do
      post_graphql_mutation(mutation, current_user: user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_include(unauthorized_error_message)
    end
  end

  context 'when user does not have permission' do
    let_it_be(:developer) { create(:user, developer_of: group) }

    it 'returns authorization error' do
      post_graphql_mutation(mutation, current_user: developer)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_include(unauthorized_error_message)
    end
  end

  context 'when enabledByDefaultForNewNamespaces is provided' do
    let(:params) do
      {
        full_path: group.full_path,
        name: name,
        icon_name: icon_name,
        enabled_by_default_for_new_namespaces: true
      }
    end

    it 'creates work item type with visibility default' do
      expect do
        post_graphql_mutation(mutation, current_user: user)
      end.to change { WorkItems::TypesFramework::VisibilityDefault.count }.by(1)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_be_empty
      expect(mutation_response['errors']).to be_empty

      expect(WorkItems::TypesFramework::VisibilityDefault.last).to have_attributes(
        enabled: true,
        namespace_id: group.id
      )
    end
  end

  context 'when enabledByDefaultForNewNamespaces is not provided' do
    it 'does not create a visibility default record' do
      expect do
        post_graphql_mutation(mutation, current_user: user)
      end.not_to change { WorkItems::TypesFramework::VisibilityDefault.count }

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_be_empty
      expect(mutation_response['errors']).to be_empty
    end
  end

  context 'when user is maintainer of the group' do
    let(:current_user) { user }

    it_behaves_like 'creates work item type successfully'
  end

  context 'when user is owner of the group' do
    let_it_be(:owner) { create(:user, owner_of: group) }
    let(:current_user) { owner }

    it_behaves_like 'creates work item type successfully'
  end

  describe 'returned GID type' do
    it 'returns a WorkItems::Type GID for the created custom type' do
      post_graphql_mutation(mutation, current_user: user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_be_empty

      gid = mutation_response['workItemType']['id']
      parsed_gid = GlobalID.parse(gid)

      expect(parsed_gid.model_name).to eq('WorkItems::Type')
    end
  end

  context 'on self-managed' do
    let(:current_user) { organization_owner }

    before do
      stub_saas_features(namespace_scoped_work_item_types: false)
    end

    context 'with root group' do
      let(:expected_error_message) { 'Work item types can only be modified at the organization level' }

      it_behaves_like 'returns error response'
    end

    context 'with organization' do
      let(:params) { super().except(:full_path) }

      it_behaves_like 'creates work item type successfully'

      context 'when enabledByDefaultForNewNamespaces is provided' do
        let(:params) do
          {
            name: name,
            icon_name: icon_name,
            enabled_by_default_for_new_namespaces: true
          }
        end

        it 'creates work item type with visibility default scoped to organization' do
          expect do
            post_graphql_mutation(mutation, current_user: current_user)
          end.to change { WorkItems::TypesFramework::VisibilityDefault.count }.by(1)

          expect(response).to have_gitlab_http_status(:success)
          expect_graphql_errors_to_be_empty

          expect(WorkItems::TypesFramework::VisibilityDefault.last).to have_attributes(
            enabled: true,
            organization_id: current_organization.id,
            namespace_id: nil
          )
        end
      end
    end
  end
end
