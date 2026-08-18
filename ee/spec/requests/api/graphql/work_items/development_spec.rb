# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Getting work item development widget from a work item', feature_category: :team_planning do
  include_context 'with work items list request'

  let(:item1) { create(:work_item, project: project) }

  let(:merge_request) { create(:merge_request, author: current_user, source_project: project) }

  let!(:merge_request_linking_note) do
    create(:note, project: project, noteable: item1, note: merge_request.to_reference(full: true))
  end

  describe 'request with different scopes' do
    let(:fields) do
      <<~GRAPHQL
            nodes {
                widgets {
                    ... on WorkItemWidgetDevelopment {
                        relatedMergeRequests {
                            nodes {
                                id
                                state
                                webUrl
                                sourceProjectId
                            }
                        }
                    }
                }
            }
      GRAPHQL
    end

    let(:query) do
      graphql_query_for(
        'project',
        { 'fullPath' => project.full_path },
        query_graphql_field('workItems', {}, fields)
      )
    end

    let(:token) { create(:oauth_access_token, user: current_user, scopes: scopes) }
    let(:scopes) { [:api] }

    let(:widgets) { graphql_data.dig('project', 'workItems', 'nodes').first['widgets'] }
    let(:development_widget) { widgets.find { |widget| widget.key?('relatedMergeRequests') }['relatedMergeRequests'] }
    let(:related_mr) { development_widget['nodes'].first }

    it 'returns development widget with api scope' do
      post_graphql(query, token: { oauth_access_token: token })
      expect(related_mr).to include(
        'id' => merge_request.to_global_id.to_s,
        'state' => 'opened',
        'webUrl' => Gitlab::UrlBuilder.build(merge_request, only_path: false).to_s,
        'sourceProjectId' => project.id
      )
    end

    context 'when using ai_workflows scope' do
      let(:scopes) { [:ai_workflows] }

      it 'returns development widget with ai_workflows scope' do
        post_graphql(query, token: { oauth_access_token: token })
        expect(related_mr).to include(
          'id' => merge_request.to_global_id.to_s,
          'state' => 'opened',
          'webUrl' => Gitlab::UrlBuilder.build(merge_request, only_path: false).to_s,
          'sourceProjectId' => nil # Returns nil as sourceProjectId is not exposed with ai_workflows scope
        )
      end
    end
  end
end
