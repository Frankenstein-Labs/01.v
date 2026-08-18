# frozen_string_literal: true

module QA
  module EE
    module Page
      module Group
        class ContributionAnalytics < QA::Page::Base
          view 'ee/app/assets/javascripts/analytics/contribution_analytics/components/issues_chart.vue' do
            element 'issue-content'
          end

          view 'ee/app/assets/javascripts/analytics/contribution_analytics/components/merge_requests_chart.vue' do
            element 'merge-request-content'
          end

          view 'ee/app/assets/javascripts/analytics/contribution_analytics/components/pushes_chart.vue' do
            element 'push-content'
          end

          def issue_analytics_content
            find_element('issue-content')
          end

          def mr_analytics_content
            find_element('merge-request-content')
          end

          def push_analytics_content
            find_element('push-content')
          end
        end
      end
    end
  end
end
