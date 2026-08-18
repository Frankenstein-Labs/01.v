# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Analytics Dashboard Visualizations', :js, feature_category: :value_stream_management do
  include ValueStreamsDashboardHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:user) { current_user }
  let_it_be(:group) { create(:group, name: "vsd test group") }
  let_it_be(:project) { create(:project, :repository, name: "vsd project", namespace: group) }
  let_it_be(:environment) { create(:environment, :production, project: project) }

  before_all do
    group.add_developer(user)
  end

  context 'for dora_chart visualization' do
    before do
      stub_licensed_features(group_level_analytics_dashboard: true, dora4_analytics: true, security_dashboard: true,
        cycle_analytics_for_groups: true)

      create_mock_dora_chart_metrics(environment)

      sign_in(user)
    end

    context 'when ClickHouse is enabled for analytics', :saas,
      quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/532963' do
      before do
        allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)

        visit_group_value_streams_dashboard(group)
      end

      it_behaves_like 'renders metrics comparison tables' do
        let(:panel_title) { "#{group.name} group" }
      end

      it_behaves_like 'renders contributor count'
    end

    context 'when ClickHouse is disabled for analytics', :saas,
      quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/516903' do
      before do
        allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(false)

        visit_group_value_streams_dashboard(group)
      end

      it_behaves_like 'renders metrics comparison tables' do
        let(:panel_title) { "#{group.name} group" }
      end

      it_behaves_like 'does not render contributor count'
    end
  end

  context 'for usage_overview visualization' do
    before do
      stub_licensed_features(group_level_analytics_dashboard: true)

      sign_in(user)
    end

    context 'when background aggregation is disabled' do
      context 'with data' do
        before do
          create_mock_usage_overview_metrics(project)

          visit_group_value_streams_dashboard(group)
        end

        it_behaves_like 'renders usage overview metrics' do
          let(:panel_title) { "#{group.name} group" }
          let(:usage_overview_metrics) { expected_usage_overview_metrics }
        end
      end

      context 'without data' do
        before do
          visit_group_value_streams_dashboard(group)
        end

        it_behaves_like 'renders usage overview metrics with empty values' do
          let(:panel_title) { "#{group.name} group" }
          let(:usage_overview_metrics) { expected_usage_overview_metrics_empty_values }
        end
      end
    end

    context 'when background aggregation is enabled' do
      before do
        create(:value_stream_dashboard_aggregation, namespace: group, enabled: true)
      end

      context 'with data' do
        before do
          create_mock_usage_overview_metrics(project)

          visit_group_value_streams_dashboard(group)
        end

        it_behaves_like 'renders usage overview metrics' do
          let(:panel_title) { "#{group.name} group" }
          let(:usage_overview_metrics) { expected_usage_overview_metrics }
        end
      end

      context 'without data' do
        before do
          visit_group_value_streams_dashboard(group)
        end

        it_behaves_like 'renders usage overview metrics with zero values' do
          let(:panel_title) { "#{group.name} group" }
          let(:usage_overview_metrics) { expected_usage_overview_metrics_zero_values }
        end
      end
    end
  end

  context 'for dora_performers_score visualization' do
    before do
      stub_licensed_features(dora4_analytics: true, group_level_analytics_dashboard: true)

      create_mock_dora_performers_score_metrics(group)

      sign_in(user)

      visit_group_value_streams_dashboard(group)
    end

    it_behaves_like 'renders dora performers score'
  end
end
