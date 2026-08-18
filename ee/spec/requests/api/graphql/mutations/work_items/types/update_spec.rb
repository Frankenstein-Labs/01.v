# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Updating a work item type', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:user) { create(:user, maintainer_of: group) }
  let_it_be(:organization_owner) { create(:user, owner_of: current_organization) }
  let_it_be(:system_defined_work_item_type) { create(:work_item_system_defined_type, :issue) }
  let_it_be(:organization_custom_work_item_type) do
    create(:work_item_custom_type, :with_organization, organization: current_organization)
  end

  let_it_be(:namespace_custom_work_item_type) { create(:work_item_custom_type, namespace: group) }

  let(:work_item_type) { system_defined_work_item_type }

  let(:updated_name) { 'Bug' }
  let(:updated_icon_name) { 'bug' }
  let(:params) do
    {
      id: work_item_type.to_global_id.to_s,
      full_path: group.full_path,
      name: updated_name,
      icon_name: updated_icon_name
    }
  end

  let(:current_user) { user }

  let(:mutation) { graphql_mutation(:work_item_type_update, params) }
  let(:mutation_response) { graphql_mutation_response(:work_item_type_update) }
  let(:unauthorized_error_message) do
    "The resource that you are attempting to access does not exist or you don't have permission to perform this action"
  end

  before do
    stub_licensed_features(configurable_work_item_types: true)
    stub_saas_features(namespace_scoped_work_item_types: true)
  end

  RSpec.shared_examples 'creates custom work item type with updated attributes' do
    it 'creates custom work item type with updated attributes' do
      expect do
        post_graphql_mutation(mutation, current_user: current_user)
      end.to change { WorkItems::TypesFramework::Custom::Type.count }.by(1)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_be_empty

      expect(mutation_response['workItemType']).to match(
        a_hash_including(
          'id' => system_defined_work_item_type.to_global_id.to_s,
          'name' => updated_name,
          'iconName' => updated_icon_name
        )
      )
    end
  end

  RSpec.shared_examples 'updates existing custom work item type' do
    it 'updates existing custom work item type' do
      expect do
        post_graphql_mutation(mutation, current_user: current_user)
      end.not_to change { WorkItems::TypesFramework::Custom::Type.count }

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_be_empty

      expect(mutation_response['workItemType']).to match(
        a_hash_including(
          'id' => work_item_type.to_global_id.to_s,
          'name' => updated_name,
          'iconName' => updated_icon_name
        )
      )
    end
  end

  RSpec.shared_examples 'returns authorization error' do
    it 'returns authorization error' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_include(unauthorized_error_message)
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

  context 'with system-defined work item type' do
    it_behaves_like 'creates custom work item type with updated attributes'
  end

  context 'with custom work item type' do
    let(:work_item_type) { namespace_custom_work_item_type }

    it_behaves_like 'updates existing custom work item type'
  end

  context 'when work item type ID is not provided' do
    let(:params) { super().except(:id) }

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

  context 'when work item type does not exist' do
    let(:params) { super().merge(id: "gid://gitlab/WorkItems::Type/999") }
    let(:expected_error_message) { 'Work item type not found' }

    it_behaves_like 'returns error response'
  end

  context 'when full_path is a subgroup' do
    let(:params) { super().merge(full_path: subgroup.full_path) }

    it_behaves_like 'returns authorization error'
  end

  context 'when full_path is not provided' do
    let(:params) { super().except(:full_path) }

    context 'with authorized user' do
      let(:expected_error_message) { 'Work item types can only be modified at the root group level' }
      let(:current_user) { organization_owner }

      context 'with system-defined work item type' do
        it_behaves_like 'returns error response'
      end

      context 'with custom work item type' do
        let(:work_item_type) { organization_custom_work_item_type }

        it_behaves_like 'returns error response'
      end
    end

    context 'with unauthorized user' do
      it_behaves_like 'returns authorization error'
    end
  end

  context 'when full_path is not valid' do
    let(:params) { super().merge(full_path: 'invalid') }

    it_behaves_like 'returns authorization error'
  end

  context 'when no update arguments are provided' do
    let(:params) { { id: work_item_type.to_global_id.to_s } }

    it 'returns a validation error' do
      post_graphql_mutation(mutation, current_user: user)

      expect(response).to have_gitlab_http_status(:success)
      expect(graphql_errors).to include(
        a_hash_including(
          'message' => a_string_matching(
            /At least one of \[name, iconName, archive, enabledByDefaultForNewNamespaces\] arguments is required/
          )
        )
      )
    end
  end

  context 'with invalid parameters' do
    context 'when name is invalid' do
      let(:updated_name) { 'Task' }

      it 'returns validation error' do
        post_graphql_mutation(mutation, current_user: user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to include("Name 'Task' is already taken.")
      end
    end

    context 'when icon_name is invalid' do
      let(:updated_icon_name) { 'invalid' }

      it 'returns validation error' do
        post_graphql_mutation(mutation, current_user: user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to include(a_string_matching(/Icon name is not valid/))
      end
    end
  end

  context 'when user is unauthorized' do
    let_it_be(:developer) { create(:user, developer_of: group) }
    let(:user) { developer }

    it_behaves_like 'returns authorization error'
  end

  context 'when licensed feature is not available' do
    before do
      stub_licensed_features(configurable_work_item_types: false)
    end

    it_behaves_like 'returns authorization error'
  end

  context 'when enabledByDefaultForNewNamespaces is provided' do
    let(:work_item_type) { namespace_custom_work_item_type }
    let(:params) do
      {
        id: work_item_type.to_global_id.to_s,
        full_path: group.full_path,
        name: updated_name,
        enabled_by_default_for_new_namespaces: true
      }
    end

    it 'updates work item type and creates visibility default' do
      expect do
        post_graphql_mutation(mutation, current_user: current_user)
      end.to change { WorkItems::TypesFramework::VisibilityDefault.count }.by(1)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_be_empty
      expect(mutation_response['errors']).to be_empty

      expect(WorkItems::TypesFramework::VisibilityDefault.last).to have_attributes(
        work_item_type_id: work_item_type.id,
        enabled: true,
        namespace_id: group.id
      )
    end
  end

  context 'when enabledByDefaultForNewNamespaces is not provided' do
    let(:work_item_type) { namespace_custom_work_item_type }

    it 'does not create a visibility default record' do
      expect do
        post_graphql_mutation(mutation, current_user: current_user)
      end.not_to change { WorkItems::TypesFramework::VisibilityDefault.count }

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_be_empty
    end
  end

  context 'when visibility default upsert fails' do
    let(:work_item_type) { namespace_custom_work_item_type }
    let(:params) do
      {
        id: work_item_type.to_global_id.to_s,
        full_path: group.full_path,
        name: updated_name,
        enabled_by_default_for_new_namespaces: true
      }
    end

    before do
      allow(WorkItems::TypesFramework::VisibilityDefault).to receive(:upsert_for_settings)
        .and_raise(ActiveRecord::RecordInvalid.new(WorkItems::TypesFramework::VisibilityDefault.new))
    end

    it 'returns an error response instead of 500' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_be_empty
      expect(mutation_response['workItemType']).to be_nil
      expect(mutation_response['errors']).not_to be_empty
    end
  end

  context 'when archiving a work item type' do
    let(:work_item_type) { namespace_custom_work_item_type }
    let(:params) do
      {
        id: work_item_type.to_global_id.to_s,
        full_path: group.full_path,
        archive: true
      }
    end

    it 'archives the work item type' do
      post_graphql_mutation(mutation, current_user: user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_be_empty
      expect(work_item_type.reload.archived).to be true
    end
  end

  context 'when unarchiving a work item type' do
    let(:archived_custom_type) do
      create(:work_item_custom_type, :archived, namespace: group, name: 'Archived Type')
    end

    let(:params) do
      {
        id: archived_custom_type.to_global_id.to_s,
        full_path: group.full_path,
        archive: false
      }
    end

    it 'unarchives the work item type' do
      expect(archived_custom_type.archived).to be true

      post_graphql_mutation(mutation, current_user: user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_be_empty
      expect(archived_custom_type.reload.archived).to be false
    end

    context 'when maximum limit is reached' do
      let(:available_types_count) do
        WorkItems::TypesFramework::Provider.new(group).available_system_defined_types_count
      end

      it 'returns an error and does not unarchive the type' do
        archived_custom_type
        stub_const("WorkItems::TypesFramework::Custom::Type::MAX_TYPE_PER_PARENT", available_types_count)

        expect(archived_custom_type.archived).to be true

        post_graphql_mutation(mutation, current_user: user)

        expect(response).to have_gitlab_http_status(:success)
        expect_graphql_errors_to_be_empty
        expect(mutation_response['workItemType']).to be_nil
        expect(mutation_response['errors']).to include(
          a_string_including("Cannot unarchive because the maximum limit of #{available_types_count} " \
            "work item types has been reached.")
        )
        expect(archived_custom_type.reload.archived).to be true
      end
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

      context 'with system-defined work item type' do
        it_behaves_like 'creates custom work item type with updated attributes'
      end

      context 'with custom work item type' do
        let(:work_item_type) { organization_custom_work_item_type }

        it_behaves_like 'updates existing custom work item type'
      end

      context 'when enabledByDefaultForNewNamespaces is provided' do
        let(:work_item_type) { organization_custom_work_item_type }
        let(:params) do
          {
            id: work_item_type.to_global_id.to_s,
            name: updated_name,
            enabled_by_default_for_new_namespaces: true
          }
        end

        it 'creates visibility default scoped to organization' do
          expect do
            post_graphql_mutation(mutation, current_user: current_user)
          end.to change { WorkItems::TypesFramework::VisibilityDefault.count }.by(1)

          expect(response).to have_gitlab_http_status(:success)
          expect_graphql_errors_to_be_empty

          expect(WorkItems::TypesFramework::VisibilityDefault.last).to have_attributes(
            work_item_type_id: work_item_type.id,
            enabled: true,
            organization_id: current_organization.id,
            namespace_id: nil
          )
        end
      end
    end
  end
end
