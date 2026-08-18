# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Add a closing merge request to a work item', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group, :private) }
  let_it_be(:project) { create(:project, :repository, :private, group: group) }
  let_it_be(:developer) { create(:user, developer_of: group) }
  let_it_be(:unauthorized_user) { create(:user) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:private_merge_request) { create(:merge_request, source_project: create(:project, :repository, :private)) }

  let(:fields) do
    <<~GRAPHQL
      closingMergeRequest {
        mergeRequest { id }
        fromMrDescription
      }
      workItem {
        id
        widgets {
          type
          ... on WorkItemWidgetDevelopment {
            closingMergeRequests {
              nodes {
                mergeRequest { id }
                fromMrDescription
              }
            }
          }
        }
      }
      errors
    GRAPHQL
  end

  let(:current_user) { developer }
  let(:mutation_response) { graphql_mutation_response(:work_item_add_closing_merge_request) }
  let(:mutation) { graphql_mutation(:workItemAddClosingMergeRequest, input, fields) }
  let(:mr_reference) { merge_request.to_reference }
  let(:namespace_path) { project.full_path }
  let(:input) do
    { 'id' => work_item.to_gid.to_s, 'mergeRequestReference' => mr_reference, 'contextNamespacePath' => namespace_path }
  end

  context 'when work item belongs to a group' do
    let_it_be_with_refind(:work_item) { create(:work_item, :group_level, namespace: group) }

    context 'with group level work item license' do
      before do
        stub_licensed_features(epics: true)
      end

      it_behaves_like 'a mutation that adds closing merge request'

      it_behaves_like 'authorizing granular token permissions for GraphQL', :update_work_item do
        let(:user) { current_user }
        let(:boundary_object) { group }
        let(:mutation) do
          graphql_mutation(:workItemAddClosingMergeRequest, input, 'errors')
        end

        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end
    end

    context 'without group level work item license' do
      before do
        stub_licensed_features(epics: false)
      end

      it_behaves_like 'a mutation that does not add closing merge request'
    end
  end
end
