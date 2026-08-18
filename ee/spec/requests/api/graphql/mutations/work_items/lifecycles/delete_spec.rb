# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Deleting a custom lifecycle', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user, maintainer_of: group) }

  let_it_be(:custom_lifecycle) { create(:work_item_custom_lifecycle, namespace: group) }

  let(:namespace_path) { group.full_path }
  let(:params) do
    {
      namespace_path: namespace_path,
      id: custom_lifecycle.to_gid
    }
  end

  let(:unauthorized_error_message) do
    "The resource that you are attempting to access does not exist or you don't have permission to perform this action"
  end

  let(:mutation) { graphql_mutation(:lifecycle_delete, params) }
  let(:mutation_response) { graphql_mutation_response(:lifecycle_delete) }

  before do
    stub_licensed_features(work_item_status: true)
  end

  it 'deletes the lifecycle and its statuses' do
    post_graphql_mutation(mutation, current_user: user)

    expect(response).to have_gitlab_http_status(:success)
    expect_graphql_errors_to_be_empty

    expect(mutation_response['lifecycle']['id']).to eq(custom_lifecycle.to_gid.to_s)

    expect(::WorkItems::Statuses::Custom::Lifecycle.count).to eq(0)
    expect(::WorkItems::Statuses::Custom::Status.count).to eq(0)
  end

  context 'when lifecycle is in use' do
    let!(:type_custom_lifecycle) do
      create(:work_item_type_custom_lifecycle,
        work_item_type: build(:work_item_system_defined_type, :issue),
        lifecycle: custom_lifecycle
      )
    end

    it 'returns an error' do
      post_graphql_mutation(mutation, current_user: user)

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to include(
        'Cannot delete lifecycle because it is currently in use.'
      )
    end
  end

  context 'when invalid input is provided' do
    let(:params) { {} }

    it 'returns validation error for all missing required attributes' do
      post_graphql_mutation(mutation, current_user: user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_include(
        "Variable $lifecycleDeleteInput of type LifecycleDeleteInput! was provided invalid value " \
          "for namespacePath (Expected value to not be null), id (Expected value to not be null)"
      )
    end
  end

  context 'when user is unauthorized' do
    it 'returns an error' do
      guest = create(:user, guest_of: group)

      post_graphql_mutation(mutation, current_user: guest)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_include(unauthorized_error_message)
    end
  end

  context 'when namespace is a subgroup' do
    let_it_be(:subgroup) { create(:group, parent: group) }
    let_it_be(:subgroup_maintainer) { create(:user, maintainer_of: subgroup) }

    let(:namespace_path) { subgroup.full_path }

    it 'returns an error' do
      post_graphql_mutation(mutation, current_user: subgroup_maintainer)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_include(unauthorized_error_message)
    end
  end
end
