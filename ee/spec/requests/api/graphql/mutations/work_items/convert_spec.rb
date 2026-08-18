# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "Converts a work item to a new type", feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:developer) { create(:user, developer_of: project) }
  let_it_be(:new_type) { build(:work_item_system_defined_type, :objective) }
  let_it_be_with_refind(:work_item) do
    create(:work_item, :key_result, project: project, start_date: Time.current, due_date: Time.current + 1.day)
  end

  let(:mutation) { graphql_mutation(:workItemConvert, input) }
  let(:mutation_response) { graphql_mutation_response(:work_item_convert) }
  let(:input) do
    {
      'id' => work_item.to_global_id.to_s,
      'work_item_type_id' => new_type.to_global_id.to_s
    }
  end

  context 'when the work item type is not part of the license' do
    let(:current_user) { developer }

    before do
      stub_licensed_features(okrs: false)
    end

    it 'does not convert the work item', :aggregate_failures do
      expect do
        post_graphql_mutation(mutation, current_user: current_user)
      end.not_to change { work_item.reload.work_item_type }

      expect(response).to have_gitlab_http_status(:success)
      expect(work_item.reload.work_item_type.base_type).to eq('key_result')
      expect(work_item.start_date).to be_present
      expect(work_item.due_date).to be_present
      expect(graphql_errors).to include(
        a_hash_including('message' => "You are not allowed to change the Work Item type to Objective.")
      )
    end
  end

  context 'when user has permissions to convert the work item type' do
    let(:current_user) { developer }

    before do
      stub_licensed_features(okrs: true)
    end

    it 'converts the work item', :aggregate_failures do
      expect do
        post_graphql_mutation(mutation, current_user: current_user)
      end.to change { work_item.reload.work_item_type }.to(new_type)

      expect(response).to have_gitlab_http_status(:success)
      expect(work_item.reload.work_item_type.base_type).to eq('objective')
      expect(work_item.start_date).to be_nil
      expect(work_item.due_date).to be_nil
      expect(mutation_response['workItem']).to include('id' => work_item.to_global_id.to_s)
    end
  end

  context 'when converting epic work item' do
    let(:current_user) { developer }
    let_it_be(:group) { create(:group, developers: developer) }

    before do
      stub_licensed_features(epics: true, okrs: true)
    end

    context 'when epic work item does not have a synced epic' do
      let_it_be(:work_item) { create(:work_item, :epic, namespace: group) }

      context 'with group level work items license' do
        it 'converts the work item type', :aggregate_failures do
          expect do
            post_graphql_mutation(mutation, current_user: current_user)
          end.to change { work_item.reload.work_item_type }.to(new_type)

          expect(response).to have_gitlab_http_status(:success)
          expect(work_item.reload.work_item_type.base_type).to eq('objective')
          expect(mutation_response['workItem']).to include('id' => work_item.to_global_id.to_s)
        end

        it_behaves_like 'authorizing granular token permissions for GraphQL', :update_work_item do
          let(:user) { current_user }
          let(:boundary_object) { group }
          let(:mutation) do
            graphql_mutation(:workItemConvert, input, 'errors')
          end

          let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
        end
      end

      context 'without group level work items license' do
        before do
          stub_licensed_features(okrs: true, epics: false)
        end

        it 'does not convert the work item type', :aggregate_failures do
          expect do
            post_graphql_mutation(mutation, current_user: current_user)
          end.not_to change { work_item.reload.work_item_type }

          expect_graphql_errors_to_include(
            "The resource that you are attempting to access does not exist or " \
              "you don't have permission to perform this action"
          )
        end
      end
    end

    context 'when epic work item has a synced epic' do
      let_it_be(:epic) { create(:epic, :with_synced_work_item, group: group) }
      let(:work_item) { epic.work_item }

      it 'converts the work item type', :aggregate_failures do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(mutation_response['errors']).to contain_exactly(
          'Work item type cannot be changed to objective when the work item is a legacy epic synced work item'
        )
      end
    end
  end
end
