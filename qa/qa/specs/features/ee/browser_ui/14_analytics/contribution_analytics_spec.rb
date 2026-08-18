# frozen_string_literal: true

module QA
  RSpec.describe 'Analytics', feature_category: :value_stream_management do
    describe 'Contribution Analytics' do
      let(:group) { create(:group, path: "contribution_anayltics-#{SecureRandom.hex(8)}") }

      let(:project) { create(:project, name: 'contribution_analytics', group: group) }

      let(:issue) { create(:issue, project: project) }

      let(:mr) { create(:merge_request, project: project) }

      before do
        Flow::Login.sign_in

        issue.visit!

        Page::Project::WorkItem::Show.perform(&:click_close_issue_button)

        mr.visit!
        Page::MergeRequest::Show.perform(&:merge!)

        group.visit!
        Page::Group::Menu.perform(&:go_to_contribution_analytics)
      end

      it(
        'tests contributions',
        :aggregate_failures
      ) do
        EE::Page::Group::ContributionAnalytics.perform do |analytics_page|
          # Wait once for data to appear, then assert all values
          expect { analytics_page.push_analytics_content.text }.to eventually_include('4 pushes')
            .within(max_duration: 240, reload_page: analytics_page)

          # Once data is loaded, no need for retries or reloads
          expect(analytics_page.push_analytics_content).to have_content('1 contributor')
          expect(analytics_page.mr_analytics_content).to have_content('1 created, 1 merged, 0 closed.')
          expect(analytics_page.issue_analytics_content).to have_content('1 created, 1 closed.')
        end
      end
    end
  end
end
