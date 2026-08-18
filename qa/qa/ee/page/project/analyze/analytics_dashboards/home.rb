# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Analyze
          module AnalyticsDashboards
            class Home < QA::Page::Base
              view 'ee/app/assets/javascripts/analytics/analytics_dashboards/components/list/dashboard_list_item.vue' do
                element 'dashboard-list-item'
                element 'dashboard-router-link'
                element 'dashboard-errors-badge'
              end

              def open_mr_analytics_dashboard
                open_dashboard('Merge request analytics')
              end

              def open_dashboard(name)
                click_link(name)
                wait_for_requests
              end
            end
          end
        end
      end
    end
  end
end
