# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Loading usage overview for a project', feature_category: :value_stream_management do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:user) { create(:user, developer_of: group) }
  let_it_be(:metric) do
    create(:value_stream_dashboard_count, metric: :issues, count: 10, namespace: project.project_namespace,
      recorded_at: '2024-06-20')
  end

  let(:params) do
    {
      identifier: :ISSUES,
      timeframe: {
        start: '2024-06-01',
        end: '2024-06-30'
      }
    }
  end

  def query
    graphql_query_for("project", { "fullPath" => project.full_path },
      query_graphql_field("valueStreamDashboardUsageOverview", params, %i[count])
    )
  end

  context 'when the feature is available' do
    before do
      stub_licensed_features(project_level_analytics_dashboard: true)
    end

    it 'does return the count' do
      post_graphql(query, current_user: user)

      expect(response).to have_gitlab_http_status(:success)
      expect(graphql_data.dig('project', 'valueStreamDashboardUsageOverview', 'count')).to eq(10)
    end
  end

  context 'when requesting the CONTRIBUTORS and ClickHouse backend is off' do
    let(:params) do
      {
        identifier: :CONTRIBUTORS,
        timeframe: {
          start: '2023-01-01',
          end: '2023-01-31'
        }
      }
    end

    before do
      stub_licensed_features(project_level_analytics_dashboard: true)
      allow(::Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(false)
    end

    it 'returns GraphQL error' do
      post_graphql(query, current_user: user)

      expect(response).to have_gitlab_http_status(:success)

      error = Gitlab::Json.parse(response.body)['errors'].first
      message = s_('VsdContributorCount|the ClickHouse data store is not available for this namespace')
      expect(error['message']).to eq(message)
    end
  end

  context 'when the feature is not available' do
    it 'returns nil response' do
      post_graphql(query, current_user: user)

      expect(graphql_data.dig('project', 'valueStreamDashboardUsageOverview')).to be_nil
    end
  end
end
