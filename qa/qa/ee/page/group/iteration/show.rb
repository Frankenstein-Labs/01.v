# frozen_string_literal: true

module QA
  module EE
    module Page
      module Group
        module Iteration
          class Show < QA::Page::Base
            view 'ee/app/assets/javascripts/iterations/components/iteration_report_issues.vue' do
              element 'iteration-issues-container', required: true
              element 'iteration-issue-link'
            end

            view 'ee/app/assets/javascripts/burndown_chart/components/burndown_chart.vue' do
              element 'burndown-chart'
            end

            view 'ee/app/assets/javascripts/burndown_chart/components/burnup_chart.vue' do
              element 'burnup-chart'
            end

            def has_burndown_chart?
              has_element?('burndown-chart')
            end

            def has_burnup_chart?
              has_element?('burnup-chart')
            end

            def has_issue?(issue)
              within_element('iteration-issues-container') do
                has_element?('iteration-issue-link', issue_title: issue.title)
              end
            end

            def has_no_issue?(issue)
              within_element('iteration-issues-container') do
                has_no_element?('iteration-issue-link', issue_title: issue.title)
              end
            end
          end
        end
      end
    end
  end
end
