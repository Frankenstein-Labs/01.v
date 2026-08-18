# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Analytics::CycleAnalytics::SummaryController, feature_category: :value_stream_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, namespace: group) }

  let(:params) { { namespace_id: project.namespace.to_param, project_id: project.to_param, created_after: '2010-01-01', created_before: '2020-01-02' } }

  before do
    sign_in(user)
  end

  describe 'GET "time_summary"' do
    let_it_be(:first_mentioned_in_commit_at) { Date.new(2015, 1, 1) }
    let_it_be(:closed_at) { Date.new(2015, 2, 1) }

    let_it_be(:closed_issue) do
      create(:issue, project: project, created_at: closed_at, closed_at: closed_at).tap do |issue|
        issue.metrics.update!(first_mentioned_in_commit_at: first_mentioned_in_commit_at)
      end
    end

    subject(:time_summary_request) { get :time_summary, params: params }

    context 'when cycle_analytics_for_projects feature is available' do
      before_all do
        project.add_reporter(user)
      end

      before do
        stub_licensed_features(cycle_analytics_for_projects: true, cycle_analytics_for_groups: true)

        Analytics::CycleAnalytics::DataLoaderService.new(namespace: group, model: Issue).execute
      end

      it 'succeeds and returns correct value', :aggregate_failures do
        expected_cycle_time = (closed_at - first_mentioned_in_commit_at).to_f

        time_summary_request

        expect(response).to be_successful
        lead_time = json_response.find { |result| result['identifier'] == 'cycle_time' }.symbolize_keys
        expect(lead_time).to include({ value: expected_cycle_time.to_s, title: 'Cycle time', unit: 'days' })
      end

      context 'when analytics_disabled features are disabled' do
        it 'renders 404' do
          project.project_feature.update!(analytics_access_level: ProjectFeature::DISABLED)

          time_summary_request

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when user is not part of the project' do
      it 'renders 404' do
        time_summary_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the feature is not available' do
      it 'renders 404' do
        project.add_reporter(user)

        time_summary_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
