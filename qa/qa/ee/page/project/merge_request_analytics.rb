# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        class MergeRequestAnalytics < QA::Page::Base
          view "ee/app/assets/javascripts/analytics/analytics_dashboards/components/analytics_dashboard.vue" do
            # Elements are loaded async
          end

          # Throughput chart
          #
          # @param [Integer] wait
          # @return [Capybara::Node::Element]
          def throughput_chart(wait: 5)
            find_element('panel-merge-requests-over-time', wait: wait)
          end

          # Mean time to merge stat
          #
          # @return [String]
          def mean_time_to_merge
            within_element('panel-mean-time-to-merge') do
              value = find_element("displayValue").text
              unit = find_element("unit").text

              "#{value} #{unit}"
            end
          end

          # List of merged mrs
          #
          # @return [Array<Hash>]
          def merged_mrs(expected_count:)
            within_element('panel-merge-requests-throughput-table') do
              all_elements("td[data-label=\"Merge Request\"]", count: expected_count).map do |el|
                {
                  title: el.find("a").text,
                  label_count: el.find("[data-testid=\"labels-count\"]").text.to_i,
                  comment_count: el.find("[data-testid=\"user-notes-count\"]").text.to_i
                }
              end
            end
          end
        end
      end
    end
  end
end
