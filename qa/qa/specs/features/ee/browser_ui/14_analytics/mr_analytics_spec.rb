# frozen_string_literal: true

module QA
  RSpec.describe 'Analytics', feature_category: :value_stream_management do
    describe 'Merge Request Analytics', :requires_admin do
      let(:label) { "mr-label" }
      let(:project) { create(:project, name: 'mr_analytics') }

      let(:mr_1) do
        create(:merge_request,
          title: 'First merge request',
          labels: [label],
          project: project)
      end

      let(:mr_2) do
        create(:merge_request,
          title: 'Second merge request',
          project: project)
      end

      before do
        # Retry is needed due to delays with project authorization updates
        # Long term solution to accessing the status of a project authorization update
        # has been proposed in https://gitlab.com/gitlab-org/gitlab/-/issues/393369
        Support::Retrier.retry_until(max_duration: 60, retry_on_exception: true, sleep_interval: 1) do
          create(:project_label, project: project, title: label)
        end

        mr_2.add_comment(body: "This is mr comment")
        mr_1.merge_via_api!
        mr_2.merge_via_api!

        Flow::Login.sign_in
        project.visit!
        Page::Project::Menu.perform(&:go_to_analytics_dashboards)
        EE::Page::Project::Analyze::AnalyticsDashboards::Home.perform(&:open_mr_analytics_dashboard)
      end

      it(
        "shows merge request analytics chart and stats"
      ) do
        EE::Page::Project::MergeRequestAnalytics.perform do |mr_analytics_page|
          expect(mr_analytics_page.throughput_chart).to be_visible
          # chart elements will be loaded even when no data is fetched,
          # so explicit check for missing no data warning is required
          expect(mr_analytics_page).not_to(
            have_content("There is no chart data available"),
            "Expected chart data to be available"
          )

          aggregate_failures do
            expect(mr_analytics_page.mean_time_to_merge).to eq("0 days")
            expect(mr_analytics_page.merged_mrs(expected_count: 2)).to match_array([
              {
                title: mr_1.title,
                label_count: 1,
                comment_count: 0
              },
              {
                title: mr_2.title,
                label_count: 0,
                comment_count: 1
              }
            ])
          end
        end
      end
    end
  end
end
