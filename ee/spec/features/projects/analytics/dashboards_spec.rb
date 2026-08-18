# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Analytics Dashboards', :js, feature_category: :value_stream_management do
  include ValueStreamsDashboardHelpers
  include DoraMetricsDashboardHelpers
  include MrAnalyticsDashboardHelpers
  include ListboxHelpers
  include FilteredSearchHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:user) { current_user }
  let_it_be(:user_2) { create(:user) }
  let_it_be(:group) { create(:group, name: "vsd test group") }
  let_it_be(:project) { create(:project, :repository, name: "vsd project", namespace: group) }

  let(:metric_table) { find_by_testid('panel-dora-chart') }

  it 'renders a 404 error for a user without permission' do
    sign_in(user)
    visit_project_analytics_dashboards_list(project)

    expect(page).to have_content _("Page not found")
  end

  context 'with a valid user' do
    before_all do
      group.add_developer(user)
      project.add_developer(user)

      group.add_developer(user_2)
      project.add_developer(user_2)
    end

    context 'with project_level_analytics_dashboard license' do
      let_it_be(:environment) { create(:environment, :production, project: project) }

      before do
        stub_licensed_features(
          project_level_analytics_dashboard: true,
          dora4_analytics: true, security_dashboard: true, cycle_analytics_for_projects: true,
          group_level_analytics_dashboard: true, cycle_analytics_for_groups: true
        )

        sign_in(user)
      end

      context 'for dashboard listing' do
        before do
          visit_project_analytics_dashboards_list(project)
        end

        it 'renders the dashboard list correctly' do
          expect(page).to have_content _('Analytics dashboards')
        end

        it_behaves_like 'has value streams dashboard link'
      end

      context 'for Value streams dashboard' do
        context 'with default configuration' do
          before do
            visit_project_value_streams_dashboard(project)
          end

          it_behaves_like 'VSD renders as an analytics dashboard'

          it 'does not render dora performers score panel' do
            # Currently does not support project namespaces
            expect(page).not_to have_selector("[data-testid='panel-dora-performers-score']")
          end
        end

        context 'with usage overview background aggregation enabled' do
          before do
            create(:value_stream_dashboard_aggregation, namespace: group, enabled: true)

            visit_project_value_streams_dashboard(project)
          end

          it_behaves_like 'does not render usage overview background aggregation not enabled alert'
        end

        context 'for comparison table' do
          before_all do
            create_mock_dora_chart_metrics(environment)
          end

          context 'when ClickHouse is enabled for analytics', :saas,
            quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/538319' do
            before do
              allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)
              Analytics::CycleAnalytics::DataLoaderService.new(namespace: group, model: Issue).execute

              visit_project_value_streams_dashboard(project)
            end

            it_behaves_like 'renders metrics comparison tables' do
              let(:panel_title) { "#{project.name} project" }
            end

            it_behaves_like 'renders contributor count'
          end

          context 'when ClickHouse is disabled for analytics', :saas,
            quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/546755' do
            before do
              allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(false)
              Analytics::CycleAnalytics::DataLoaderService.new(namespace: group, model: Issue).execute

              visit_project_value_streams_dashboard(project)
            end

            it_behaves_like 'renders metrics comparison tables' do
              let(:panel_title) { "#{project.name} project" }
            end

            it_behaves_like 'does not render contributor count'
          end
        end

        context 'for usage overview panel' do
          context 'when background aggregation is disabled' do
            context 'with data' do
              before do
                create_mock_usage_overview_metrics(project)

                visit_project_value_streams_dashboard(project)
              end

              it_behaves_like 'renders usage overview metrics' do
                let(:panel_title) { "#{project.name} project" }
                let(:usage_overview_metrics) { expected_usage_overview_metrics(is_project: true) }
              end
            end

            context 'without data' do
              before do
                visit_project_value_streams_dashboard(project)
              end

              it_behaves_like 'renders usage overview metrics with empty values' do
                let(:panel_title) { "#{project.name} project" }
                let(:usage_overview_metrics) { expected_usage_overview_metrics_empty_values(is_project: true) }
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

                visit_project_value_streams_dashboard(project)
              end

              it_behaves_like 'renders usage overview metrics' do
                let(:panel_title) { "#{project.name} project" }
                let(:usage_overview_metrics) { expected_usage_overview_metrics(is_project: true) }
              end
            end

            context 'without data' do
              before do
                visit_project_value_streams_dashboard(project)
              end

              it_behaves_like 'renders usage overview metrics with zero values' do
                let(:panel_title) { "#{project.name} project" }
                let(:usage_overview_metrics) { expected_usage_overview_metrics_zero_values(is_project: true) }
              end
            end
          end
        end

        context 'without the dora4_analytics ability' do
          before do
            stub_licensed_features(project_level_analytics_dashboard: true, dora4_analytics: false)

            visit_project_value_streams_dashboard(project)
          end

          it_behaves_like 'renders unlicensed DORA metrics table visualization'
        end

        context 'without the security_dashboard ability' do
          before do
            stub_licensed_features(project_level_analytics_dashboard: true, security_dashboard: false)

            visit_project_value_streams_dashboard(project)
          end

          it_behaves_like 'renders unlicensed security metrics visualization'
        end
      end

      context 'for DORA metrics analytics dashboard' do
        context 'without data available' do
          before do
            visit_project_dora_metrics_dashboard(project)
          end

          it_behaves_like 'DORA metrics analytics renders as an analytics dashboard'

          it_behaves_like 'renders DORA metrics stats with zero values'

          it_behaves_like 'renders DORA metrics chart panels with empty states'
        end

        context 'with data available',
          quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/24084' do
          before do
            create_mock_dora_metrics(environment)

            visit_project_dora_metrics_dashboard(project)
          end

          it_behaves_like 'DORA metrics analytics renders as an analytics dashboard'

          it_behaves_like 'renders DORA metrics analytics stats' do
            let(:expected_dora_metrics_stats) { ['0.1 /day', '26.1 %', '5.0 days', '3.0 days'] }
          end

          it_behaves_like 'renders DORA metrics time series charts'

          it_behaves_like 'updates DORA metrics visualizations when filters applied', days_back: 90 do
            let(:filtered_dora_metrics_stats) { ['0.2 /day', '33.3 %', '4.0 days', '2.0 days'] }
          end
        end
      end

      context 'for Merge request analytics dashboard' do
        context 'without data available' do
          before do
            visit_mr_analytics_dashboard(project)
          end

          it_behaves_like 'MR analytics renders as an analytics dashboard'

          it_behaves_like 'renders `Mean time to merge` panel with correct value', expected_value: _('- days')

          it 'renders `Throughput` panel with an empty state' do
            within_testid('panel-merge-requests-over-time') do
              expect(page).to have_text _('Throughput')
              expect(page).to have_text _('No results match your query or filter.')
            end
          end

          it 'renders `Merge requests` panel with an empty state' do
            within_testid('panel-merge-requests-throughput-table') do
              expect(page).to have_text _('Merge Requests')
              expect(page).to have_text _('No results match your query or filter.')
            end
          end
        end

        context 'with data available' do
          let_it_be(:milestone) { create(:milestone, project: project) }

          let_it_be(:merge_request_1) do
            merged_at = Time.utc(2025, 5, 29)
            created_at = Time.utc(2025, 5, 27)

            create(:merge_request, :with_merged_metrics, :simple, created_at: created_at,
              source_project: project).tap do |mr|
              mr.metrics.update!(merged_at: merged_at, created_at: created_at)
            end
          end

          let_it_be(:merge_request_2) do
            merged_at = Time.utc(2025, 5, 20)
            created_at = Time.utc(2025, 5, 15)

            create(:merge_request, :with_merged_metrics, milestone: milestone, author: user_2, created_at: created_at,
              source_project: project).tap do |mr|
              mr.metrics.update!(merged_at: merged_at, created_at: created_at)
            end
          end

          let_it_be(:merge_request_3) do
            merged_at = Time.utc(2025, 5, 10)
            created_at = Time.utc(2025, 5, 7)

            create(:merge_request, :with_merged_metrics, :simple, milestone: milestone, author: user_2,
              created_at: created_at, source_project: project).tap do |mr|
              mr.metrics.update!(merged_at: merged_at, created_at: created_at)
            end
          end

          let_it_be(:merge_request_4) do
            merged_at = Time.utc(2025, 4, 25)
            created_at = Time.utc(2025, 4, 19)

            create(:merge_request, :with_merged_metrics, created_at: created_at,
              source_project: project).tap do |mr|
              mr.metrics.update!(merged_at: merged_at, created_at: created_at)
            end
          end

          before do
            visit_mr_analytics_dashboard_with_custom_date_range(project,
              start_date: Time.utc(2024, 5, 30).to_date.iso8601, end_date: Time.utc(2025, 5, 30).to_date.iso8601)
          end

          it_behaves_like 'MR analytics renders as an analytics dashboard'

          it_behaves_like 'renders `Mean time to merge` panel with correct value', expected_value: _('4 days')

          it_behaves_like 'renders chart in `Throughput` panel'

          it_behaves_like 'renders merge requests in table in `Merge Requests` panel' do
            let(:expected_mrs) { [merge_request_1, merge_request_2, merge_request_3, merge_request_4] }
          end

          context 'when date range changes' do
            before do
              within_testid('dashboard-filters-date-range') do
                toggle_listbox
                select_listbox_item(_('Custom range'), exact_text: true)

                fill_in _('From'), with: Time.utc(2025, 5, 1).to_date.iso8601
                fill_in _('To'), with: Time.utc(2025, 5, 30).to_date.iso8601

                send_keys :enter, :tab

                wait_for_requests
              end
            end

            it_behaves_like 'renders `Mean time to merge` panel with correct value', expected_value: _('3 days')

            it_behaves_like 'renders chart in `Throughput` panel'

            it_behaves_like 'renders merge requests in table in `Merge Requests` panel' do
              let(:expected_mrs) { [merge_request_1, merge_request_2, merge_request_3] }
            end
          end

          context 'when filtering by author' do
            before do
              select_tokens 'Author', user_2.username, submit: true

              wait_for_requests
            end

            it_behaves_like 'renders `Mean time to merge` panel with correct value', expected_value: _('4 days')

            it_behaves_like 'renders chart in `Throughput` panel'

            it_behaves_like 'renders merge requests in table in `Merge Requests` panel' do
              let(:expected_mrs) { [merge_request_2, merge_request_3] }
            end
          end

          context 'when filtering by target branch' do
            before do
              select_tokens 'Target branch', 'master', submit: true

              wait_for_requests
            end

            it_behaves_like 'renders `Mean time to merge` panel with correct value', expected_value: _('3 days')

            it_behaves_like 'renders chart in `Throughput` panel'

            it_behaves_like 'renders merge requests in table in `Merge Requests` panel' do
              let(:expected_mrs) { [merge_request_1, merge_request_3] }
            end
          end

          context 'when filtering by milestone' do
            before do
              select_tokens 'Milestone', '=', milestone.title, submit: true

              wait_for_requests
            end

            it_behaves_like 'renders `Mean time to merge` panel with correct value', expected_value: _('4 days')

            it_behaves_like 'renders chart in `Throughput` panel'

            it_behaves_like 'renders merge requests in table in `Merge Requests` panel' do
              let(:expected_mrs) { [merge_request_2, merge_request_3] }
            end
          end

          context 'when filtering by author, target branch and milestone' do
            before do
              select_tokens 'Author', user_2.username, 'Target branch', 'master', 'Milestone', '=', milestone.title,
                submit: true

              wait_for_requests
            end

            it_behaves_like 'renders `Mean time to merge` panel with correct value', expected_value: _('3 days')

            it_behaves_like 'renders chart in `Throughput` panel'

            it_behaves_like 'renders merge requests in table in `Merge Requests` panel' do
              let(:expected_mrs) { [merge_request_3] }
            end
          end
        end
      end

      context 'as a reporter' do
        context 'when the user is a direct member of the project' do
          let_it_be(:project_user) { create(:user, :with_namespace) }

          before_all do
            project.add_reporter(project_user)
          end

          before do
            sign_in(project_user)

            visit_project_value_streams_dashboard(project)
          end

          it_behaves_like 'renders licensed VSD for a reporter'
        end
      end
    end
  end
end
