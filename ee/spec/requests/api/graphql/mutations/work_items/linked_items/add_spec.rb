# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "Add linked items to a work item", feature_category: :portfolio_management do
  include GraphqlHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :private) }
  let_it_be(:reporter) { create(:user, reporter_of: [project, group]) }
  let_it_be(:work_item) { create(:work_item, :issue, project: project) }
  let_it_be(:work_item2) { create(:work_item, project: project) }

  let(:current_user) { reporter }
  let(:mutation_response) { graphql_mutation_response(:work_item_add_linked_items) }
  let(:mutation) { graphql_mutation(:workItemAddLinkedItems, input, fields) }
  let(:ids_to_link) { [work_item2.to_global_id.to_s] }
  let(:input) do
    { 'id' => work_item.to_global_id.to_s, 'workItemsIds' => ids_to_link, 'linkType' => link_type }
  end

  let(:fields) do
    <<~FIELDS
      workItem {
        widgets {
          type
          ... on WorkItemWidgetLinkedItems {
            linkedItems {
              edges {
                node {
                  linkType
                  workItem {
                    id
                  }
                }
              }
            }
          }
        }
      }
      errors
      message
    FIELDS
  end

  context 'when work item is created at the group level', :aggregate_failures do
    let(:related1) { create(:work_item, project: project) }
    let(:related2) { create(:work_item, project: project) }
    let(:work_item) { create(:work_item, :group_level, namespace: group) }
    let(:ids_to_link) { [related1.to_global_id.to_s, related2.to_global_id.to_s] }
    let(:link_type) { 'RELATED' }

    context 'with a group level work items license' do
      before do
        stub_licensed_features(epics: true)
      end

      it 'links the work item' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.to change { WorkItems::RelatedWorkItemLink.count }.by(2)

        expect(mutation_response['message']).to eq("Successfully linked ID(s): #{related1.id} and #{related2.id}.")
      end
    end

    context 'without a group level work items license' do
      before do
        stub_licensed_features(epics: false)
      end

      it 'links the work item' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.to not_change { WorkItems::RelatedWorkItemLink.count }

        expect(graphql_errors.first['message']).to eq(
          "The resource that you are attempting to access does not exist or you don't have " \
            "permission to perform this action"
        )
      end
    end
  end

  where(:link_type, :expected) do
    'BLOCKS'     | 'blocks'
    'BLOCKED_BY' | 'is_blocked_by'
  end

  with_them do
    context 'when licensed feature `blocked_work_items` is available' do
      before do
        stub_licensed_features(blocked_work_items: true)
      end

      it 'links the work items with correct link type' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.to change { WorkItems::RelatedWorkItemLink.count }.by(1)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['message']).to eq("Successfully linked ID(s): #{work_item2.id}.")
        expect(mutation_response['workItem']['widgets']).to include(
          {
            'linkedItems' => { 'edges' => match_array([
              { 'node' => { 'linkType' => expected, 'workItem' => { 'id' => work_item2.to_global_id.to_s } } }
            ]) },
            'type' => 'LINKED_ITEMS'
          }
        )
      end
    end

    context 'when licensed feature `blocked_work_items` is not available' do
      before do
        stub_licensed_features(blocked_work_items: false)
      end

      it 'returns an error' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.not_to change { WorkItems::RelatedWorkItemLink.count }

        expect(mutation_response['errors'])
          .to contain_exactly('Blocked work items are not available for the current subscription tier')
      end
    end
  end
end
