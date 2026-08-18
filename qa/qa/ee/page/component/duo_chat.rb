# frozen_string_literal: true

module QA
  module EE
    module Page
      module Component
        class DuoChat < QA::Page::Base
          view 'ee/app/assets/javascripts/ai/components/new_chat_button.vue' do
            # components are derived from gitlab/ui
          end

          view 'ee/app/assets/javascripts/ai/components/content_container.vue' do
            element 'content-container-close-button'
          end

          def open_duo_chat
            dismiss_duo_chat_popup if respond_to?(:dismiss_duo_chat_popup)

            click_element('ai-chat-toggle')
          end

          def send_duo_chat_prompt(prompt)
            fill_element('chat-prompt-input', prompt)
            click_element('chat-prompt-submit-button')
            wait_for_requests
          end

          def clear_chat_history
            send_duo_chat_prompt('/clear')
          end

          def empty_state?
            has_element?('gl-duo-chat-empty-state')
          end

          def latest_response
            QA::Support::Retrier.retry_until(retry_on_exception: true, max_duration: 60) do
              find_all('.duo-chat-message p').last&.text.presence
            end
          end

          def has_feedback_message?
            has_css?('.duo-chat-message-actions', wait: 30)
          end

          def has_error?
            has_css?('.has-error', wait: 1)
          end

          def error_text
            find_all('.has-error').map(&:text)
          end

          def number_of_messages
            find_all('.duo-chat-message').size
          end

          def close
            click_element('content-container-close-button')
          end

          def response
            find_element('chat-history').text
          end

          def duo_chat_open?
            has_element?('chat-prompt-input') && has_element?('chat-component')
          end

          def wait_for_response
            QA::Support::Waiter.wait_until { find_all('.duo-chat-message').present? }
          end

          def agentic_mode_toggle_visible?
            has_element?('toggle-label', text: /Agentic/i)
          end

          def agentic_mode_enabled?
            toggle_wrapper = find_element("toggle-wrapper", text: /Agentic/i)
            toggle_button = toggle_wrapper.find('button[role="switch"]')
            toggle_button['aria-checked'] == 'true'
          end

          def switch_to_classic_mode
            return unless agentic_mode_enabled?

            within_element("toggle-wrapper", text: /Agentic/i) do
              click_element('button[role="switch"]')
            end
            wait_for_requests
          end

          def ensure_classic_mode!
            raise 'Agentic mode toggle is not visible - cannot verify chat mode' unless agentic_mode_toggle_visible?

            switch_to_classic_mode
          end
        end
      end
    end
  end
end
