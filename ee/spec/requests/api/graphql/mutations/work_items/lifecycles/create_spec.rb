# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Creating a custom lifecycle', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user, maintainer_of: group) }

  let_it_be(:system_defined_lifecycle) { build(:work_item_system_defined_lifecycle) }
  let_it_be(:system_defined_in_progress_status) { build(:work_item_system_defined_status, :in_progress) }
  let_it_be(:system_defined_wont_do_status) { build(:work_item_system_defined_status, :wont_do) }

  let(:namespace_path) { group.full_path }
  let(:lifecycle_name) { 'New Lifecycle' }
  let(:params) do
    {
      namespace_path: namespace_path,
      name: lifecycle_name,
      statuses: [
        {
          name: "New To do",
          color: "#000000",
          category: "TO_DO"
        },
        {
          name: "New Done",
          color: "#000000",
          category: "DONE"
        },
        {
          name: "New Duplicate",
          color: "#000000",
          category: "CANCELED"
        }
      ],
      default_open_status_index: 0,
      default_closed_status_index: 1,
      default_duplicate_status_index: 2
    }
  end

  let(:unauthorized_error_message) do
    "The resource that you are attempting to access does not exist or you don't have permission to perform this action"
  end

  let(:mutation) { graphql_mutation(:lifecycle_create, params) }
  let(:mutation_response) { graphql_mutation_response(:lifecycle_create) }

  before do
    stub_licensed_features(work_item_status: true)
  end

  it 'creates a custom lifecycle' do
    post_graphql_mutation(mutation, current_user: user)

    expect(response).to have_gitlab_http_status(:success)
    expect_graphql_errors_to_be_empty

    expect(mutation_response['lifecycle']).to match(
      a_hash_including(
        'name' => lifecycle_name,
        'statuses' => include(
          a_hash_including('name' => "New To do"),
          a_hash_including('name' => "New Done"),
          a_hash_including('name' => "New Duplicate")
        )
      )
    )
  end

  context 'when namespace path is not provided' do
    let(:params) do
      super().except(:namespace_path)
    end

    it 'returns validation error for missing required argument' do
      post_graphql_mutation(mutation, current_user: user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_include(
        "Variable $lifecycleCreateInput of type LifecycleCreateInput! was provided invalid value " \
          "for namespacePath (Expected value to not be null)"
      )
    end
  end

  context 'when status has invalid category' do
    let(:params) do
      super().merge(statuses: [
        {
          name: "New To do",
          color: "#000000",
          category: "INVALID_CATEGORY"
        },
        {
          name: "New Done",
          color: "#000000",
          category: "DONE"
        },
        {
          name: "New Duplicate",
          color: "#000000",
          category: "CANCELED"
        }
      ])
    end

    it 'returns validation error for invalid argument value' do
      post_graphql_mutation(mutation, current_user: user)

      expect_graphql_errors_to_include(
        /Expected "INVALID_CATEGORY" to be one of: TRIAGE, TO_DO, IN_PROGRESS, DONE, CANCELED/
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
