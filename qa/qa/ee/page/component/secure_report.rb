# frozen_string_literal: true

module QA
  module EE
    module Page
      module Component
        module SecureReport
          extend QA::Page::PageConcern

          def self.prepended(base)
            super

            base.class_eval do
              view 'ee/app/assets/javascripts/security_dashboard/components/shared/filtered_search/tokens/
                    activity_token.vue' do
                element 'activity-token'
              end

              view 'ee/app/assets/javascripts/security_dashboard/components/
                    shared/vulnerability_report/vulnerability_list.vue' do
                element 'vulnerability-status-content'
              end
            end
          end

          def filter_by(token_name:, token_value:)
            has_cleared = clear_filter_token(token_name)

            if has_cleared
              click_element("search-button")
              click_element("search-button") # Click twice to make dropdown go away
            end

            click_element('filtered-search-term')
            click_button(token_name)
            click_button(token_value)
            click_element("search-button")
            click_element("search-button") # Click twice to make dropdown go away
          end

          def clear_filter_token(token_name)
            return unless has_css?('[data-testid="filtered-search-token"]', text: token_name, wait: 1)

            token = find(:css, '[data-testid="filtered-search-token"]', text: token_name)
            token.find('button[aria-label="Remove"]').click
            true
          end

          def filter_by_status(statuses)
            filter_by_status_new(statuses)

            state = statuses_list(statuses).map { |item| "state=#{item}" }.join("&")
            raise 'Status unchanged in the URL' unless page.current_url.downcase.include?(state)
          end

          def filter_by_status_new(statuses)
            click_element('clear-icon')
            click_element('filtered-search-token-segment')
            click_button('Status')
            click_button('All statuses')
            statuses_list_advanced_filter(statuses).each do |status|
              click_button(status) unless status == 'Dismissed'
              click_button('All dismissal reasons') if status == 'Dismissed'
              wait_for_requests
            end
            click_element('search-button')
            click_element('search-button') # second click removes the dynamic dropdown
          end

          def statuses_list(statuses)
            statuses.map do |status|
              case status
              when /all/i
                'all'
              when /needs triage/i
                'detected'
              else
                status
              end
            end
          end

          def statuses_list_advanced_filter(statuses)
            statuses.map do |status|
              case status
              when /all/i
                'All statuses'
              when /needs triage/i
                'Needs triage'
              else
                status.capitalize
              end
            end
          end

          def has_vulnerability?(name)
            retry_until(reload: true, sleep_interval: 10, max_attempts: 6, message: "Retry for vulnerability text") do
              has_element?(:vulnerability, text: name)
            end
          end

          def has_status?(status, vulnerability_name)
            retry_until(reload: true, sleep_interval: 3, raise_on_failure: false) do
              # Capitalizing first letter in each word to account for "Needs Triage" state
              has_element?(
                'vulnerability-status-content',
                status_description: vulnerability_name,
                text: status.split.map(&:capitalize).join(' ').to_s
              )
            end
          end
        end
      end
    end
  end
end
