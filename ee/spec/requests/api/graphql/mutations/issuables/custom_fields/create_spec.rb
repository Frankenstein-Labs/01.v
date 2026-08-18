# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Creating a custom field', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:maintainer) { create(:user, maintainer_of: group) }

  let(:params) { { name: 'My Custom Field', field_type: 'TEXT' } }
  let(:mutation) { graphql_mutation(:custom_field_create, params.merge(group_path: group.full_path)) }
  let(:mutation_response) { graphql_mutation_response(:custom_field_create) }

  before do
    stub_licensed_features(custom_fields: true)
  end

  it 'creates a custom field for the group' do
    post_graphql_mutation(mutation, current_user: maintainer)

    expect(response).to have_gitlab_http_status(:success)
    expect_graphql_errors_to_be_empty

    expect(mutation_response['customField']).to match(
      a_hash_including(
        'name' => 'My Custom Field',
        'fieldType' => 'TEXT',
        'createdBy' => a_hash_including(
          'id' => maintainer.to_global_id.to_s
        )
      )
    )
  end

  context 'when select options are provided' do
    let(:params) do
      {
        name: 'Select Field',
        field_type: 'SINGLE_SELECT',
        select_options: [
          { value: 'option1' },
          { value: 'option2' }
        ]
      }
    end

    it 'creates a select field with options' do
      post_graphql_mutation(mutation, current_user: maintainer)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_be_empty

      expect(mutation_response['customField']).to match(
        a_hash_including(
          'name' => 'Select Field',
          'fieldType' => 'SINGLE_SELECT',
          'selectOptions' => [
            a_hash_including('value' => 'option1'),
            a_hash_including('value' => 'option2')
          ]
        )
      )
    end
  end

  context 'when work item types are provided' do
    let_it_be(:issue_type) { build(:work_item_system_defined_type, :issue) }
    let_it_be(:task_type) { build(:work_item_system_defined_type, :task) }
    let(:issue_type_gid) { issue_type.to_global_id.to_s }
    let(:task_type_gid) { task_type.to_global_id.to_s }

    let(:params) do
      {
        name: 'Text Field',
        field_type: 'TEXT',
        work_item_type_ids: [
          issue_type_gid,
          task_type_gid
        ]
      }
    end

    it 'creates a custom field associated to the work item types' do
      post_graphql_mutation(mutation, current_user: maintainer)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_be_empty

      expect(mutation_response['customField']).to match(
        a_hash_including(
          'name' => 'Text Field',
          'fieldType' => 'TEXT',
          'workItemTypes' => [
            a_hash_including('id' => issue_type.to_global_id.to_s),
            a_hash_including('id' => task_type.to_global_id.to_s)
          ]
        )
      )
    end
  end

  context 'when user does not have access' do
    it 'returns an error' do
      guest = create(:user, guest_of: group)

      post_graphql_mutation(mutation, current_user: guest)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_include(
        "The resource that you are attempting to access does not exist " \
          "or you don't have permission to perform this action"
      )
    end
  end

  context 'when input is invalid' do
    let(:params) { { name: '', field_type: 'TEXT' } }

    it 'returns the validation error' do
      post_graphql_mutation(mutation, current_user: maintainer)

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to include(
        "Name can't be blank"
      )
    end
  end
end
