# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Reorder a work item in the hierarchy tree', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group, :private) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:guest) { create(:user, guest_of: group) }

  let_it_be(:parent_epic) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
  let_it_be(:child_epic1) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
  let_it_be(:child_epic2) { create(:work_item, :epic_with_legacy_epic, namespace: group) }

  let_it_be(:child_epic1_link) do
    create(:parent_link, work_item_parent: parent_epic, work_item: child_epic1, relative_position: 20)
  end

  let_it_be(:child_epic2_link) do
    create(:parent_link, work_item_parent: parent_epic, work_item: child_epic2, relative_position: 30)
  end

  let(:mutation) do
    graphql_mutation(:workItemsHierarchyReorder, input.merge('id' => work_item.to_global_id.to_s), fields)
  end

  let(:mutation_response) { graphql_mutation_response(:work_items_hierarchy_reorder) }

  describe 'reordering' do
    let(:fields) do
      <<~FIELDS
        workItem {
          id
        }
        adjacentWorkItem {
          id
        }
        parentWorkItem {
          id
        }
        errors
      FIELDS
    end

    before do
      stub_licensed_features(epics: true, subepics: true)
    end

    shared_examples 'reorders child work item' do
      shared_examples 'reorders item position' do
        it 'moves the item to the specified position in relation to the adjacent item' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(parent.reload.work_item_children_by_relative_position).to match_array(expected_items_in_order)

          expect(mutation_response['workItem']['id']).to eq(work_item.to_gid.to_s)
          expect(mutation_response['parentWorkItem']['id']).to eq(parent.to_gid.to_s)
          expect(mutation_response['adjacentWorkItem']['id']).to eq(adjacent_item_id)
        end
      end

      context 'when user lacks permissions' do
        let(:current_user) { create(:user) }

        let(:input) do
          { 'adjacentWorkItemId' => child_epic1.to_gid.to_s, 'relativePosition' => 'AFTER' }
        end

        it 'returns an error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect_graphql_errors_to_include(
            "The resource that you are attempting to access does not " \
              "exist or you don't have permission to perform this action"
          )
        end
      end

      context 'when user has permissions' do
        let(:current_user) { guest }

        it_behaves_like 'reorders item position' do
          let(:input) { { 'adjacentWorkItemId' => child_epic1.to_gid.to_s, 'relativePosition' => 'AFTER' } }
          let(:expected_items_in_order) { [child_epic1, work_item, child_epic2] }
          let(:adjacent_item_id) { child_epic1.to_gid.to_s }
          let(:parent) { parent_epic }
        end

        it_behaves_like 'reorders item position' do
          let(:input) { { 'adjacentWorkItemId' => child_epic1.to_gid.to_s, 'relativePosition' => 'BEFORE' } }
          let(:expected_items_in_order) { [work_item, child_epic1, child_epic2] }
          let(:adjacent_item_id) { child_epic1.to_gid.to_s }
          let(:parent) { parent_epic }
        end

        context 'when moving under a new parent' do
          let_it_be(:subepic1) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
          let_it_be(:subepic2) { create(:work_item, :epic_with_legacy_epic, namespace: group) }

          let_it_be(:subepic1_link) do
            create(:parent_link, work_item_parent: child_epic2, work_item: subepic1, relative_position: 10)
          end

          let_it_be(:subepic2_link) do
            create(:parent_link, work_item_parent: child_epic2, work_item: subepic2, relative_position: 20)
          end

          context 'when relative position is not present' do
            let(:input) { { 'parentId' => child_epic2.to_gid.to_s } }

            it 'is positions the item at the top of the list' do
              post_graphql_mutation(mutation, current_user: current_user)

              expect(response).to have_gitlab_http_status(:success)
              expect(child_epic2.reload.work_item_children_by_relative_position)
                .to match_array([work_item, subepic1, subepic2])

              expect(mutation_response['workItem']['id']).to eq(work_item.to_gid.to_s)
              expect(mutation_response['parentWorkItem']['id']).to eq(child_epic2.to_gid.to_s)
              expect(mutation_response['adjacentWorkItem']).to be_nil
            end
          end

          context 'when relative position is present' do
            it_behaves_like 'reorders item position' do
              let(:input) do
                {
                  'parentId' => child_epic2.to_gid.to_s,
                  'adjacentWorkItemId' => subepic1.to_gid.to_s,
                  'relativePosition' => 'AFTER'
                }
              end

              let(:expected_items_in_order) { [subepic1, work_item, subepic2] }
              let(:parent) { child_epic2 }
              let(:adjacent_item_id) { subepic1.to_gid.to_s }
            end

            it_behaves_like 'reorders item position' do
              let(:input) do
                {
                  'parentId' => child_epic2.to_gid.to_s,
                  'adjacentWorkItemId' => subepic1.to_gid.to_s,
                  'relativePosition' => 'BEFORE'
                }
              end

              let(:expected_items_in_order) { [work_item, subepic1, subepic2] }
              let(:parent) { child_epic2 }
              let(:adjacent_item_id) { subepic1.to_gid.to_s }
            end
          end
        end
      end
    end

    context 'when moving a child issue' do
      let_it_be_with_reload(:work_item_issue) { create(:work_item, project: project) }

      let_it_be(:child_issue_link) do
        create(:parent_link, work_item_parent: parent_epic, work_item: work_item_issue, relative_position: 40)
      end

      it_behaves_like 'reorders child work item' do
        let(:work_item) { work_item_issue }
      end
    end

    context 'when moving a child epic' do
      let_it_be_with_reload(:work_item_epic) { create(:work_item, :epic_with_legacy_epic, namespace: group) }

      let_it_be(:child_epic1_link) do
        create(:parent_link, work_item_parent: parent_epic, work_item: work_item_epic, relative_position: 40)
      end

      it_behaves_like 'reorders child work item' do
        let(:work_item) { work_item_epic }
      end
    end
  end
end
