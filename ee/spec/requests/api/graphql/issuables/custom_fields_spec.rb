# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Listing custom fields', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group, :private) }
  let_it_be(:guest) { create(:user, guest_of: group) }

  let_it_be(:issue_type) { build(:work_item_system_defined_type, :issue) }
  let_it_be(:task_type) { build(:work_item_system_defined_type, :task) }

  let_it_be(:text_field) do
    create(:custom_field, namespace: group, field_type: 'text', name: 'ZZZ Field', work_item_types: [issue_type])
  end

  let_it_be(:select_field) do
    create(
      :custom_field, namespace: group, field_type: 'single_select', name: 'CCC',
      work_item_types: [issue_type, task_type]
    )
  end

  let_it_be(:archived_field) do
    create(:custom_field, :archived, field_type: 'number', namespace: group, name: 'AAA Field')
  end

  let_it_be(:other_custom_field) { create(:custom_field, namespace: create(:group), name: 'BBB') }

  let_it_be(:select_option) { create(:custom_field_select_option, custom_field: select_field, position: 2) }
  let_it_be(:select_option_2) { create(:custom_field_select_option, custom_field: select_field, position: 1) }

  let(:namespace) { group }

  let(:query) do
    <<~QUERY
    query($active: Boolean, $fieldType: CustomFieldType, $search: String, $workItemTypeId: WorkItemsTypeID) {
      namespace(fullPath: "#{namespace.full_path}") {
        id
        customFields(active: $active, fieldType: $fieldType, search: $search, workItemTypeId: $workItemTypeId) {
          nodes {
            id
            name
            fieldType
            active
            createdAt
            updatedAt
            selectOptions {
              id
              value
            }
            workItemTypes {
              id
              name
            }
          }
        }
      }
    }
    QUERY
  end

  before do
    stub_licensed_features(custom_fields: true)
  end

  shared_examples 'returns configured custom fields' do
    it 'returns custom fields of the group' do
      post_graphql(query, current_user: guest)

      expect(response).to have_gitlab_http_status(:ok)

      custom_fields = graphql_data_at(:namespace, :customFields, :nodes)

      expect(custom_fields).to match([
        custom_field_attributes(select_field),
        custom_field_attributes(text_field),
        custom_field_attributes(archived_field)
      ])

      expect(custom_fields[0]['selectOptions']).to eq([
        { 'id' => select_option_2.to_global_id.to_s, 'value' => select_option_2.value },
        { 'id' => select_option.to_global_id.to_s, 'value' => select_option.value }
      ])
      expect(custom_fields[0]['workItemTypes']).to eq([
        { 'id' => issue_type.to_global_id.to_s, 'name' => issue_type.name },
        { 'id' => task_type.to_global_id.to_s, 'name' => task_type.name }
      ])

      expect(custom_fields[1]['workItemTypes']).to match_array([
        { 'id' => issue_type.to_global_id.to_s, 'name' => issue_type.name }
      ])
    end
  end

  it_behaves_like 'returns configured custom fields'

  context 'when querying from a subgroup' do
    let_it_be(:subgroup) { create(:group, :private, parent: group) }
    let_it_be(:sub_subgroup) { create(:group, :private, parent: subgroup) }

    let(:namespace) { sub_subgroup }

    it_behaves_like 'returns configured custom fields'
  end

  context 'when querying from a descendant project' do
    let_it_be(:project) { create(:project, group: group) }

    let(:namespace) { project.project_namespace }

    it_behaves_like 'returns configured custom fields'
  end

  context 'when querying from group field' do
    let(:query) do
      <<~QUERY
      query($active: Boolean, $fieldType: CustomFieldType, $search: String, $workItemTypeId: WorkItemsTypeID) {
        group(fullPath: "#{namespace.full_path}") {
          id
          customFields(active: $active, fieldType: $fieldType, search: $search, workItemTypeId: $workItemTypeId) {
            nodes {
              id
              name
              fieldType
              active
              createdAt
              updatedAt
              selectOptions {
                id
                value
              }
              workItemTypes {
                id
                name
              }
            }
          }
        }
      }
      QUERY
    end

    it 'returns custom fields of the group' do
      post_graphql(query, current_user: guest)

      expect(response).to have_gitlab_http_status(:ok)

      custom_fields = graphql_data_at(:group, :customFields, :nodes)

      expect(custom_fields).to match([
        custom_field_attributes(select_field),
        custom_field_attributes(text_field),
        custom_field_attributes(archived_field)
      ])

      expect(custom_fields[0]['selectOptions']).to eq([
        { 'id' => select_option_2.to_global_id.to_s, 'value' => select_option_2.value },
        { 'id' => select_option.to_global_id.to_s, 'value' => select_option.value }
      ])
      expect(custom_fields[0]['workItemTypes']).to eq([
        { 'id' => issue_type.to_global_id.to_s, 'name' => issue_type.name },
        { 'id' => task_type.to_global_id.to_s, 'name' => task_type.name }
      ])

      expect(custom_fields[1]['workItemTypes']).to match_array([
        { 'id' => issue_type.to_global_id.to_s, 'name' => issue_type.name }
      ])
    end
  end

  context 'when filtering by active' do
    it 'returns active fields only' do
      post_graphql(query, current_user: guest, variables: { active: true })

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_data_at(:namespace, :customFields, :nodes)).to match([
        custom_field_attributes(select_field),
        custom_field_attributes(text_field)
      ])
    end

    it 'returns archived fields only' do
      post_graphql(query, current_user: guest, variables: { active: false })

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_data_at(:namespace, :customFields, :nodes)).to match([
        custom_field_attributes(archived_field)
      ])
    end
  end

  context "when filtering by field type" do
    it 'returns fields of the given type' do
      post_graphql(query, current_user: guest, variables: { fieldType: 'TEXT' })

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_data_at(:namespace, :customFields, :nodes)).to match([
        custom_field_attributes(text_field)
      ])
    end
  end

  context 'when searching by name' do
    it 'returns matching fields' do
      post_graphql(query, current_user: guest, variables: { search: 'field' })

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_data_at(:namespace, :customFields, :nodes)).to match([
        custom_field_attributes(text_field),
        custom_field_attributes(archived_field)
      ])
    end
  end

  context 'when filtering by work item type id', :aggregate_failures do
    it 'returns matching fields while using work_item_types.id' do
      expect(task_type.to_global_id.model_id.to_i).to eq(task_type.id)

      post_graphql(query, current_user: guest, variables: { work_item_type_id: task_type.to_global_id })

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_data_at(:namespace, :customFields, :nodes)).to match([
        custom_field_attributes(select_field)
      ])
    end
  end

  context 'when querying associated select options and work item types' do
    it 'avoids N+1 queries', :use_sql_query_cache do
      post_graphql(query, current_user: guest)

      control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
        post_graphql(query, current_user: guest)
      end
      expect_graphql_errors_to_be_empty

      another_field = create(
        :custom_field, namespace: group, field_type: 'single_select', name: 'Other field',
        work_item_types: [task_type]
      )
      create(:custom_field_select_option, custom_field: another_field)
      create(:custom_field_select_option, custom_field: another_field)

      expect { post_graphql(query, current_user: guest) }.not_to exceed_all_query_limit(control).with_threshold(1)
      expect_graphql_errors_to_be_empty
    end
  end

  context 'when feature is not available' do
    before do
      stub_licensed_features(custom_fields: false)
    end

    it 'returns an empty result' do
      post_graphql(query, current_user: guest)

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_data_at(:namespace, :customFields, :nodes)).to be_blank
    end
  end

  def custom_field_attributes(field)
    a_hash_including({
      'id' => field.to_global_id.to_s,
      'name' => field.name,
      'fieldType' => field.field_type.upcase,
      'active' => field.active?,
      'createdAt' => field.created_at.iso8601,
      'updatedAt' => field.updated_at.iso8601
    })
  end
end
