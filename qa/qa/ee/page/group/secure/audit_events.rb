# frozen_string_literal: true

module QA
  module EE
    module Page
      module Group
        module Secure
          class AuditEvents < QA::Page::Base
            view 'ee/app/assets/javascripts/audit_events/components/audit_events_app.vue' do
              element 'streams-tab'
              element 'streams-tab-button'
            end

            view 'ee/app/assets/javascripts/audit_events/components/audit_events_stream.vue' do
              element 'dropdown-toggle'
              element 'all-stream-destinations'
            end

            view 'ee/app/assets/javascripts/audit_events/components/stream/stream_empty_state.vue' do
              element 'dropdown-toggle'
              element 'add-http-destination'
            end

            view 'ee/app/assets/javascripts/audit_events/components/stream/stream_destination_editor.vue' do
              element 'destination-name'
              element 'stream-destination-submit-button'
            end

            view 'ee/app/assets/javascripts/audit_events/components/stream/stream_destination_editor_http_fields.vue' do
              element 'destination-url'
            end

            def click_streams_tab
              click_element('streams-tab-button')
              find_element('streams-tab')
              wait_for_requests
            end

            def add_streaming_destination(name, url)
              click_element('dropdown-toggle')
              click_element('add-http-destination')
              fill_element('destination-name', name)
              fill_element('destination-url', url)
              click_element('stream-destination-submit-button')
              wait_for_requests
            end

            def has_stream_destination?(name)
              if has_element?('all-stream-destinations', wait: 1)
                within_element('all-stream-destinations') do
                  has_element?('toggle-btn', text: name)
                end
              else
                within_element('stream-destinations') do
                  has_element?('toggle-btn', text: name)
                end
              end
            end
          end
        end
      end
    end
  end
end
