# frozen_string_literal: true

module QA
  module EE
    module Page
      module Group
        class IssuesAnalytics < QA::Page::Base
          view 'ee/app/assets/javascripts/issues_analytics/components/issues_analytics.vue' do
            element 'issues-analytics-chart-wrapper'
            element 'issues-analytics-graph'
          end

          def graph
            wait_issues_analytics_graph_finish_loading do
              find_element('issues-analytics-graph')
            end
          end

          private

          def wait_issues_analytics_graph_finish_loading
            within_element('issues-analytics-chart-wrapper') do
              wait_until(reload: false, max_duration: 5, sleep_interval: 1) do
                spinner_cleared?
                yield
              end
            end
          end
        end
      end
    end
  end
end
