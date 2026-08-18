# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Delete a work item', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:owner) { create(:user, owner_of: group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:developer) { create(:user, developer_of: project) }

  let(:current_user) { developer }
  let(:mutation) { graphql_mutation(:workItemDelete, { 'id' => work_item.to_global_id.to_s }) }
  let(:mutation_response) { graphql_mutation_response(:work_item_delete) }

  before do
    stub_licensed_features(epics: true)
  end

  context 'when the user is not allowed to delete a work item' do
    let(:work_item) { create(:work_item, project: project) }

    it_behaves_like 'a mutation that returns a top-level access error'
  end

  context 'when user has permissions to delete a work item' do
    context 'when group owner can delete a work item even if not the author' do
      let!(:work_item) { create(:work_item, :group_level, namespace: group) }

      it 'deletes the group-level work item' do
        expect do
          post_graphql_mutation(mutation, current_user: owner)
        end.to change { WorkItem.count }.by(-1)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['namespace']).to include('id' => work_item.namespace.to_global_id.to_s)
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL', :delete_work_item do
        let(:user) { owner }
        let(:boundary_object) { group }
        let(:mutation) do
          graphql_mutation(:workItemDelete, { 'id' => work_item.to_global_id.to_s }, 'errors')
        end

        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end

      context 'without group level work item license' do
        before do
          stub_licensed_features(epics: false)
        end

        it 'does not deletes the epic work item' do
          expect do
            post_graphql_mutation(mutation, current_user: owner)
          end.not_to change { WorkItem.count }

          expect(graphql_errors.first["message"]).to eq(
            "The resource that you are attempting to access does not exist or you don't have " \
              "permission to perform this action"
          )
        end
      end
    end

    context 'when deleting an epic work item' do
      context 'when epic work item does not have a synced epic' do
        let_it_be_with_refind(:work_item) do
          create(:work_item, :epic, namespace: group)
        end

        it 'deletes the epic work item' do
          expect do
            post_graphql_mutation(mutation, current_user: owner)
          end.to change { WorkItem.count }.by(-1)
        end
      end

      context 'when epic work item has a synced epic' do
        let_it_be(:epic) { create(:epic, :with_synced_work_item, group: group) }
        let(:work_item) { epic.work_item }

        it 'deletes the epic work item' do
          expect do
            post_graphql_mutation(mutation, current_user: owner)
          end.to change { WorkItem.count }.by(-1)
        end
      end
    end
  end
end
