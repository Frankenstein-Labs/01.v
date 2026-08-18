# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Toggling work item type availability', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, group: group) }

  let_it_be(:work_item_type) { create(:work_item_system_defined_type, :issue) }
  let_it_be(:custom_work_item_type) do
    create(:work_item_custom_type, namespace: group)
  end

  let_it_be(:sm_custom_work_item_type) do
    create(:work_item_custom_type, :with_organization, organization: group.organization)
  end

  let_it_be(:group_maintainer) { create(:user, maintainer_of: group) }

  let(:full_path) { group.full_path }
  let(:namespace) { group }
  let(:current_user) { group_maintainer }
  let(:target_type) { work_item_type }
  let(:work_item_type_id) { target_type.to_global_id.to_s }
  let(:action) { 'ENABLE' }
  let(:scope) { 'THIS' }
  let(:params) do
    {
      full_path: full_path,
      work_item_type_id: work_item_type_id,
      action: action,
      scope: scope
    }
  end

  let(:mutation) { graphql_mutation(:work_item_availability_toggle, params) }
  let(:mutation_response) { graphql_mutation_response(:work_item_availability_toggle) }
  let(:unauthorized_error_message) do
    "The resource that you are attempting to access does not exist or you don't have permission to perform this action"
  end

  before do
    stub_licensed_features(configurable_work_item_types: true)
  end

  shared_examples 'toggles work item type availability' do
    before do
      stub_saas_features(namespace_scoped_work_item_types: true)
      create(:work_item_settings, namespace: namespace.root_ancestor, customizable_type_visibility: true)
    end

    context 'when customizable_type_visibility is enabled' do
      let(:mutation) { graphql_mutation(:work_item_availability_toggle, params, 'workItemType { id enabled }') }

      it 'returns the updated enabled state in the response' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect_graphql_errors_to_be_empty
        expect(mutation_response['workItemType']['enabled']).to be true
      end

      context 'when disabling a type' do
        let(:action) { 'DISABLE' }

        it 'returns enabled: false immediately in the mutation response' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect_graphql_errors_to_be_empty
          expect(mutation_response['workItemType']['enabled']).to be false
        end
      end
    end

    it 'creates a visibility record for the work item type' do
      expect do
        post_graphql_mutation(mutation, current_user: current_user)
      end.to change { WorkItems::TypesFramework::Visibility.count }.by(1)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_be_empty
      expect(mutation_response['workItemType']).to include('id' => target_type.to_global_id.to_s)
      expect(mutation_response['errors']).to be_empty
    end

    context 'when disabling a work item type' do
      let(:action) { 'DISABLE' }

      it 'creates a visibility record with enabled: false' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect_graphql_errors_to_be_empty
        expect(mutation_response['errors']).to be_empty

        visibility = WorkItems::TypesFramework::Visibility.last
        expect(visibility.enabled).to be false
        expect(visibility.propagate).to be false
      end
    end

    context 'when enabling a work item type' do
      let(:action) { 'ENABLE' }

      it 'creates a visibility record with enabled: true' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect_graphql_errors_to_be_empty
        expect(mutation_response['errors']).to be_empty

        visibility = WorkItems::TypesFramework::Visibility.last
        expect(visibility.enabled).to be true
        expect(visibility.propagate).to be false
      end
    end

    context 'when scope is ALL_CHILDREN' do
      let(:scope) { 'ALL_CHILDREN' }

      it 'creates a visibility record with propagate: true' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect_graphql_errors_to_be_empty
        expect(mutation_response['errors']).to be_empty

        visibility = WorkItems::TypesFramework::Visibility.last
        expect(visibility.enabled).to be true
        expect(visibility.propagate).to be true
      end
    end

    context 'when a visibility record already exists' do
      let!(:existing_visibility) do
        create(:work_item_type_visibility,
          namespace: namespace,
          work_item_type_id: target_type.id,
          enabled: true,
          propagate: false
        )
      end

      let(:action) { 'DISABLE' }

      it 'updates the existing record' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.not_to change { WorkItems::TypesFramework::Visibility.count }

        expect(response).to have_gitlab_http_status(:success)
        expect_graphql_errors_to_be_empty
        expect(mutation_response['errors']).to be_empty

        expect(existing_visibility.reload.enabled).to be false
      end
    end

    context 'when the visibility record fails to save' do
      before do
        allow_next_instance_of(WorkItems::TypesFramework::Visibility) do |visibility|
          visibility.errors.add(:base, 'something went wrong')
          allow(visibility).to receive(:save).and_return(false)
        end
      end

      it 'returns errors' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect_graphql_errors_to_be_empty
        expect(mutation_response['workItemType']).to be_nil
        expect(mutation_response['errors']).to include('something went wrong')
      end
    end

    context 'with a custom work item type (SaaS, namespace-scoped)' do
      let(:target_type) { custom_work_item_type }

      it 'creates a visibility record for the custom type' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.to change { WorkItems::TypesFramework::Visibility.count }.by(1)

        expect(response).to have_gitlab_http_status(:success)
        expect_graphql_errors_to_be_empty
        expect(mutation_response['workItemType']).to include('id' => custom_work_item_type.to_global_id.to_s)
        expect(mutation_response['errors']).to be_empty
      end
    end
  end

  context 'with a custom work item type (self-managed, organization-scoped)' do
    let(:target_type) { sm_custom_work_item_type }
    let(:mutation) { graphql_mutation(:work_item_availability_toggle, params) }

    before do
      stub_saas_features(namespace_scoped_work_item_types: false)
      create(:work_item_settings, namespace: nil, organization: group.organization, customizable_type_visibility: true)
    end

    it 'creates a visibility record for the custom type' do
      expect do
        post_graphql_mutation(mutation, current_user: current_user)
      end.to change { WorkItems::TypesFramework::Visibility.count }.by(1)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_be_empty
      expect(mutation_response['workItemType']).to include('id' => sm_custom_work_item_type.to_global_id.to_s)
      expect(mutation_response['errors']).to be_empty
    end

    context 'when disabling a type' do
      let(:action) { 'DISABLE' }

      it 'creates a visibility record with enabled: false' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect_graphql_errors_to_be_empty
        visibility = WorkItems::TypesFramework::Visibility.last
        expect(visibility.enabled).to be false
      end
    end
  end

  context 'with group namespace' do
    let(:full_path) { group.full_path }
    let(:namespace) { group }
    let(:target_type) { build(:work_item_system_defined_type, :epic) }

    it_behaves_like 'toggles work item type availability'

    context 'when scope is ALL_CHILDREN and a conflicting descendant record exists' do
      let(:scope) { 'ALL_CHILDREN' }
      let(:action) { 'DISABLE' }

      before do
        stub_saas_features(namespace_scoped_work_item_types: true)
        create(:work_item_settings, namespace: group, customizable_type_visibility: true)
      end

      it 'deletes the conflicting descendant self-record' do
        create(:work_item_type_visibility, namespace: subgroup,
          work_item_type_id: target_type.id, enabled: true, propagate: false)

        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.to change { WorkItems::TypesFramework::Visibility.where(namespace_id: subgroup.id).count }.by(-1)

        expect(response).to have_gitlab_http_status(:success)
        expect_graphql_errors_to_be_empty
        expect(mutation_response['errors']).to be_empty
      end
    end

    context 'when namespace is a subgroup' do
      let(:full_path) { subgroup.full_path }
      let(:namespace) { subgroup }

      it_behaves_like 'toggles work item type availability'
    end

    context 'when user is a developer' do
      let_it_be(:group_developer) { create(:user, developer_of: group) }
      let(:current_user) { group_developer }

      it 'returns authorization error' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect_graphql_errors_to_include(unauthorized_error_message)
      end
    end
  end

  context 'with project namespace' do
    let_it_be(:project_maintainer) { create(:user, maintainer_of: project) }

    let(:full_path) { project.full_path }
    let(:namespace) { project.project_namespace }
    let(:current_user) { project_maintainer }

    it_behaves_like 'toggles work item type availability'

    context 'when user is a developer' do
      let_it_be(:project_developer) { create(:user, developer_of: project) }
      let(:current_user) { project_developer }

      it 'returns authorization error' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect_graphql_errors_to_include(unauthorized_error_message)
      end
    end
  end

  context 'when work item type does not exist' do
    let(:work_item_type_id) { "gid://gitlab/WorkItems::Type/#{non_existing_record_id}" }

    it 'returns a top-level error' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_include(unauthorized_error_message)
    end
  end

  context 'when current user cannot read the work item type' do
    before do
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?).with(current_user, :read_work_item_type, work_item_type).and_return(false)
    end

    it 'returns a top-level error' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_include(unauthorized_error_message)
    end
  end

  context 'when current user cannot read a custom work item type' do
    let(:target_type) { custom_work_item_type }

    before do
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?)
        .with(current_user, :read_work_item_type, custom_work_item_type).and_return(false)
    end

    it 'returns a top-level error' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_include(unauthorized_error_message)
    end
  end

  context 'when full_path is not valid' do
    let(:full_path) { 'invalid/path' }

    it 'returns authorization error' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_include(unauthorized_error_message)
    end
  end

  context 'when licensed feature is not available' do
    before do
      stub_licensed_features(configurable_work_item_types: false)
    end

    it 'returns authorization error' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_include(unauthorized_error_message)
    end
  end

  context 'when customizable_type_visibility is disabled' do
    before do
      stub_saas_features(namespace_scoped_work_item_types: true)
      create(:work_item_settings, namespace: group, customizable_type_visibility: false)
    end

    it 'returns authorization error' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_include(unauthorized_error_message)
    end
  end

  context 'when no settings record exists' do
    before do
      stub_saas_features(namespace_scoped_work_item_types: true)
    end

    it 'returns authorization error' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_include(unauthorized_error_message)
    end
  end
end
