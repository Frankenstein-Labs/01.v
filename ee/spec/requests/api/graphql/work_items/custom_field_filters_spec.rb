# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Custom field filters', feature_category: :team_planning do
  include GraphqlHelpers

  include_context 'with group configured with custom fields'

  let_it_be(:group_label) { create(:group_label, group: group) }

  let_it_be(:project) { create(:project, group: group) }

  let_it_be(:work_item_a) { create(:work_item, project: project, labels: [group_label]) }
  let_it_be(:work_item_b) { create(:work_item, project: project, labels: [group_label]) }
  let_it_be(:work_item_c) { create(:work_item, project: project, labels: [group_label]) }

  let(:current_user) { create(:user, guest_of: group) }
  let(:params) do
    {
      custom_field: [
        {
          custom_field_id: select_field.to_global_id.to_s,
          selected_option_ids: [
            select_option_2.to_global_id.to_s
          ]
        }
      ]
    }
  end

  let(:not_params) do
    {
      custom_field: [
        {
          custom_field_id: select_field.to_global_id.to_s,
          selected_option_ids: [
            select_option_2.to_global_id.to_s
          ]
        }
      ]
    }
  end

  let(:or_params) do
    {
      custom_field: [
        {
          custom_field_id: select_field.to_global_id.to_s,
          selected_option_ids: [
            select_option_1.to_global_id.to_s,
            select_option_2.to_global_id.to_s
          ]
        }
      ]
    }
  end

  before_all do
    create(:work_item_select_field_value, work_item_id: work_item_a.id, custom_field: select_field,
      custom_field_select_option: select_option_1)
    create(:work_item_select_field_value, work_item_id: work_item_b.id, custom_field: select_field,
      custom_field_select_option: select_option_2)
    create(:work_item_select_field_value, work_item_id: work_item_c.id, custom_field: select_field,
      custom_field_select_option: select_option_2)
  end

  before do
    stub_licensed_features(custom_fields: true)
  end

  shared_examples 'returns filtered counts' do
    it 'returns counts matching the custom field filter' do
      post_graphql(query, current_user: current_user)

      expect(count).to eq(2)
    end
  end

  shared_examples 'returns filtered items' do
    it 'returns items matching the custom field filter' do
      post_graphql(query, current_user: current_user)

      model_ids = items.map { |item| GlobalID.parse(item['id']).model_id.to_i }

      expect(model_ids.size).to eq(2)
      expect(model_ids).to contain_exactly(work_item_b.id, work_item_c.id)
    end
  end

  shared_examples 'returns inverse filtered counts' do
    it 'returns counts excluding the custom field filter' do
      post_graphql(query, current_user: current_user)

      expect(count).to eq(1)
    end
  end

  shared_examples 'returns inverse filtered items' do
    it 'returns items excluding the custom field filter' do
      post_graphql(query, current_user: current_user)

      model_ids = items.map { |item| GlobalID.parse(item['id']).model_id.to_i }

      expect(model_ids.size).to eq(1)
      expect(model_ids).to contain_exactly(work_item_a.id)
    end
  end

  shared_examples 'returns OR filtered counts' do
    it 'returns counts matching any of the custom field filter options' do
      post_graphql(query, current_user: current_user)

      expect(count).to eq(3) # All work items should match (a has option_1, b and c have option_2)
    end
  end

  shared_examples 'returns OR filtered items' do
    it 'returns items matching any of the custom field filter options' do
      post_graphql(query, current_user: current_user)

      model_ids = items.map { |item| GlobalID.parse(item['id']).model_id.to_i }

      expect(model_ids.size).to eq(3)
      expect(model_ids).to contain_exactly(work_item_a.id, work_item_b.id, work_item_c.id)
    end
  end

  context 'when querying project.issueStatusCounts' do
    let(:query) do
      graphql_query_for(:project, { full_path: project.full_path },
        query_graphql_field(:issueStatusCounts, params, :opened)
      )
    end

    let(:count) { graphql_data.dig('project', 'issueStatusCounts', 'opened') }

    it_behaves_like 'returns filtered counts'

    context "when using not params for inverse filtering" do
      let(:params) { { not: not_params } }

      it_behaves_like 'returns inverse filtered counts'
    end

    context 'when using or params for OR filtering' do
      let(:params) { { or: or_params } }

      it_behaves_like 'returns OR filtered counts'
    end
  end

  context 'when querying project.issues' do
    let(:query) do
      graphql_query_for(:project, { full_path: project.full_path },
        query_nodes(:issues, :id, args: params)
      )
    end

    let(:items) { graphql_data.dig('project', 'issues', 'nodes') }

    it_behaves_like 'returns filtered items'

    context "when using not params for inverse filtering" do
      let(:params) { { not: not_params } }

      it_behaves_like 'returns inverse filtered items'
    end

    context 'when using or params for OR filtering' do
      let(:params) { { or: or_params } }

      it_behaves_like 'returns OR filtered items'
    end
  end

  context 'when querying group.issues' do
    let(:query) do
      graphql_query_for(:group, { full_path: group.full_path },
        query_nodes(:issues, :id, args: params)
      )
    end

    let(:items) { graphql_data.dig('group', 'issues', 'nodes') }

    it_behaves_like 'returns filtered items'

    context "when using not params for inverse filtering" do
      let(:params) { { not: not_params } }

      it_behaves_like 'returns inverse filtered items'
    end

    context 'when using or params for OR filtering' do
      let(:params) { { or: or_params } }

      it_behaves_like 'returns OR filtered items'
    end
  end

  context 'when querying project.workItemStateCounts' do
    let(:query) do
      graphql_query_for(:project, { full_path: project.full_path },
        query_graphql_field(:workItemStateCounts, params, :opened)
      )
    end

    let(:count) { graphql_data.dig('project', 'workItemStateCounts', 'opened') }

    it_behaves_like 'returns filtered counts'

    context "when using not params for inverse filtering" do
      let(:params) { { not: not_params } }

      it_behaves_like 'returns inverse filtered counts'
    end

    context 'when using or params for OR filtering' do
      let(:params) { { or: or_params } }

      it_behaves_like 'returns OR filtered counts'
    end
  end

  context 'when querying group.workItemStateCounts' do
    let(:query) do
      graphql_query_for(:group, { full_path: group.full_path },
        query_graphql_field(:workItemStateCounts, params.merge(include_descendants: true), :opened)
      )
    end

    let(:count) { graphql_data.dig('group', 'workItemStateCounts', 'opened') }

    it_behaves_like 'returns filtered counts'

    context "when using not params for inverse filtering" do
      let(:params) { { not: not_params } }

      it_behaves_like 'returns inverse filtered counts'
    end

    context 'when using or params for OR filtering' do
      let(:params) { { or: or_params } }

      it_behaves_like 'returns OR filtered counts'
    end
  end

  context 'when querying project.workItems' do
    let(:query) do
      graphql_query_for(:project, { full_path: project.full_path },
        query_nodes(:work_items, :id, args: params)
      )
    end

    let(:items) { graphql_data.dig('project', 'workItems', 'nodes') }

    it_behaves_like 'returns filtered items'

    context 'when filtering using custom field names and values' do
      context "with existing selected option value" do
        let(:params) do
          {
            custom_field: [
              {
                custom_field_name: select_field.name,
                selected_option_values: [
                  select_option_2.value
                ]
              }
            ]
          }
        end

        it_behaves_like 'returns filtered items'
      end

      context "without existing select option value" do
        let(:option) { build(:custom_field_select_option) }
        let(:params) do
          {
            custom_field: [
              {
                custom_field_name: select_field.name,
                selected_option_values: [
                  option.value
                ]
              }
            ]
          }
        end

        it 'returns 0 items' do
          post_graphql(query, current_user: current_user)

          model_ids = items.map { |item| GlobalID.parse(item['id']).model_id.to_i }

          expect(model_ids.size).to eq(0)
          expect(model_ids).to be_empty
        end
      end
    end

    context "when using not params for inverse filtering" do
      let(:params) { { not: not_params } }

      it_behaves_like 'returns inverse filtered items'

      context 'when filtering using custom field names and values with not_params' do
        context "with existing selected option value" do
          let(:not_params) do
            {
              custom_field: [
                {
                  custom_field_name: select_field.name,
                  selected_option_values: [
                    select_option_2.value
                  ]
                }
              ]
            }
          end

          it_behaves_like 'returns inverse filtered items'
        end

        context "without existing select option value" do
          let(:option) { build(:custom_field_select_option) }
          let(:not_params) do
            {
              custom_field: [
                {
                  custom_field_name: select_field.name,
                  selected_option_values: [
                    option.value
                  ]
                }
              ]
            }
          end

          it 'returns all items' do
            post_graphql(query, current_user: current_user)

            model_ids = items.map { |item| GlobalID.parse(item['id']).model_id.to_i }

            expect(model_ids.size).to eq(3)
            expect(model_ids).to contain_exactly(work_item_a.id, work_item_b.id, work_item_c.id)
          end
        end
      end

      context 'when both name and id are given' do
        let(:not_params) do
          {
            custom_field: [
              {
                custom_field_id: select_field.to_global_id.to_s,
                custom_field_name: select_field.name,
                selected_option_values: [
                  select_option_2.value
                ]
              }
            ]
          }
        end

        it 'returns an error' do
          post_graphql(query, current_user: current_user)

          expect_graphql_errors_to_include(
            'One and only one of [customFieldId, customFieldName] arguments is required.'
          )
        end
      end
    end

    context 'when using or params for OR filtering' do
      let(:params) { { or: or_params } }

      it_behaves_like 'returns OR filtered items'

      context 'when filtering using custom field names and values with or_params' do
        let(:or_params) do
          {
            custom_field: [
              {
                custom_field_name: select_field.name,
                selected_option_values: [
                  select_option_1.value,
                  select_option_2.value
                ]
              }
            ]
          }
        end

        it_behaves_like 'returns OR filtered items'
      end

      context "without existing select option value" do
        let(:option) { build(:custom_field_select_option) }
        let(:or_params) do
          {
            custom_field: [
              {
                custom_field_name: select_field.name,
                selected_option_values: [
                  option.value
                ]
              }
            ]
          }
        end

        it 'returns 0 items' do
          post_graphql(query, current_user: current_user)

          model_ids = items.map { |item| GlobalID.parse(item['id']).model_id.to_i }

          expect(model_ids.size).to eq(0)
          expect(model_ids).to be_empty
        end
      end

      context "when only one select option value exists" do
        let(:option) { build(:custom_field_select_option) }
        let(:or_params) do
          {
            custom_field: [
              {
                custom_field_name: select_field.name,
                selected_option_values: [
                  select_option_1.value,
                  option.value
                ]
              }
            ]
          }
        end

        it 'returns 1 items' do
          post_graphql(query, current_user: current_user)

          model_ids = items.map { |item| GlobalID.parse(item['id']).model_id.to_i }

          expect(model_ids.size).to eq(1)
          expect(model_ids).to contain_exactly(work_item_a.id)
        end
      end

      context 'when testing OR with single option (should behave like regular filter)' do
        let(:or_params) do
          {
            custom_field: [
              {
                custom_field_id: select_field.to_global_id.to_s,
                selected_option_ids: [
                  select_option_2.to_global_id.to_s
                ]
              }
            ]
          }
        end

        it_behaves_like 'returns filtered items'
      end
    end
  end

  context 'when querying group.workItems' do
    let(:query) do
      graphql_query_for(:group, { full_path: group.full_path },
        query_nodes(:work_items, :id, args: params.merge(include_descendants: true))
      )
    end

    let(:items) { graphql_data.dig('group', 'workItems', 'nodes') }

    it_behaves_like 'returns filtered items'

    context "when using not params for inverse filtering" do
      let(:params) { { not: not_params } }

      it_behaves_like 'returns inverse filtered items'
    end

    context 'when using or params for OR filtering' do
      let(:params) { { or: or_params } }

      it_behaves_like 'returns OR filtered items'
    end
  end

  context 'when querying project.board.lists.issues' do
    let_it_be(:board) { create(:board, resource_parent: project) }
    let_it_be(:label_list) { create(:list, board: board, label: group_label) }

    let(:query) do
      graphql_query_for(:project, { full_path: project.full_path },
        <<~BOARDS
          boards(first: 1) {
            nodes {
              lists(id: "#{label_list.to_global_id}") {
                nodes {
                  issues(#{attributes_to_graphql(filters: params)}) {
                    nodes {
                      id
                    }
                  }
                }
              }
            }
          }
        BOARDS
      )
    end

    let(:items) do
      graphql_data.dig('project', 'boards', 'nodes')[0]
        .dig('lists', 'nodes')[0]
        .dig('issues', 'nodes')
    end

    it_behaves_like 'returns filtered items'

    context "when using not params for inverse filtering" do
      let(:params) { { not: not_params } }

      it_behaves_like 'returns inverse filtered items'
    end

    context 'when using or params for OR filtering' do
      let(:params) { { or: or_params } }

      it_behaves_like 'returns OR filtered items'
    end
  end

  context 'when querying group.board.lists.issues' do
    let_it_be(:board) { create(:board, resource_parent: group) }
    let_it_be(:label_list) { create(:list, board: board, label: group_label) }

    let(:query) do
      graphql_query_for(:group, { full_path: group.full_path },
        <<~BOARDS
          boards(first: 1) {
            nodes {
              lists(id: "#{label_list.to_global_id}") {
                nodes {
                  issues(#{attributes_to_graphql(filters: params)}) {
                    nodes {
                      id
                    }
                  }
                }
              }
            }
          }
        BOARDS
      )
    end

    let(:items) do
      graphql_data.dig('group', 'boards', 'nodes')[0]
        .dig('lists', 'nodes')[0]
        .dig('issues', 'nodes')
    end

    it_behaves_like 'returns filtered items'

    context "when using not params for inverse filtering" do
      let(:params) { { not: not_params } }

      it_behaves_like 'returns inverse filtered items'
    end

    context 'when using or params for OR filtering' do
      let(:params) { { or: or_params } }

      it_behaves_like 'returns OR filtered items'
    end
  end

  context 'with legacy epics' do
    let_it_be(:work_item_a) { create(:epic, group: group, labels: [group_label]) }
    let_it_be(:work_item_b) { create(:epic, group: group, labels: [group_label]) }
    let_it_be(:work_item_c) { create(:epic, group: group, labels: [group_label]) }

    before_all do
      create(:work_item_select_field_value, work_item_id: work_item_a.issue_id, custom_field: select_field,
        custom_field_select_option: select_option_1)
      create(:work_item_select_field_value, work_item_id: work_item_b.issue_id, custom_field: select_field,
        custom_field_select_option: select_option_2)
      create(:work_item_select_field_value, work_item_id: work_item_c.issue_id, custom_field: select_field,
        custom_field_select_option: select_option_2)
    end

    before do
      stub_licensed_features(epics: true, custom_fields: true)
    end

    context 'when querying group.epics' do
      let(:query) do
        graphql_query_for(:group, { full_path: group.full_path },
          query_nodes(:epics, :id, args: params)
        )
      end

      let(:items) { graphql_data.dig('group', 'epics', 'nodes') }

      it_behaves_like 'returns filtered items'

      context "when using not params for inverse filtering" do
        let(:params) { { not: not_params } }

        it_behaves_like 'returns inverse filtered items'
      end

      context 'when using or params for OR filtering' do
        let(:params) { { or: or_params } }

        it_behaves_like 'returns OR filtered items'
      end
    end

    context 'when querying group.epicBoards.lists.epics' do
      let_it_be(:board) { create(:epic_board, group: group) }
      let_it_be(:label_list) { create(:epic_list, epic_board: board, label: group_label) }

      let(:query) do
        graphql_query_for(:group, { full_path: group.full_path },
          <<~BOARDS
            epicBoards(first: 1) {
              nodes {
                lists(id: "#{label_list.to_global_id}") {
                  nodes {
                    epics(#{attributes_to_graphql(filters: params)}) {
                      nodes {
                        id
                      }
                    }
                  }
                }
              }
            }
          BOARDS
        )
      end

      let(:items) do
        graphql_data.dig(
          'group', 'epicBoards', 'nodes', 0,
          'lists', 'nodes', 0,
          'epics', 'nodes'
        )
      end

      it_behaves_like 'returns filtered items'

      context "when using not params for inverse filtering" do
        let(:params) { { not: not_params } }

        it_behaves_like 'returns inverse filtered items'
      end

      context 'when using or params for OR filtering' do
        let(:params) { { or: or_params } }

        it_behaves_like 'returns OR filtered items'
      end
    end
  end
end
