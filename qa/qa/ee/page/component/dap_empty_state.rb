# frozen_string_literal: true

module QA
  module EE
    module Page
      module Component
        module DapEmptyState
          extend QA::Page::PageConcern

          def self.prepended(base)
            super

            base.class_eval do
              view 'ee/app/assets/javascripts/ai/components/content_container.vue' do
                element 'content-container-close-button'
              end
            end
          end

          def close_dap_panel_if_exists
            return unless has_element?('content-container-close-button', wait: 0.5)

            click_element('content-container-close-button')
          end
        end
      end
    end
  end
end
