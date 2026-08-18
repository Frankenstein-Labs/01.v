# frozen_string_literal: true

module QA
  module EE
    module Page
      module Component
        module LicenseManagement
          extend QA::Page::PageConcern

          def self.prepended(base)
            super

            base.class_eval do
              view 'app/assets/javascripts/vue_merge_request_widget/components/widget/widget.vue' do
                element 'widget-extension'
                element 'toggle-button'
              end

              view 'app/assets/javascripts/vue_merge_request_widget/components/widget/widget.vue' do
                element 'extension-list-item'
              end
            end
          end

          def has_license?(name)
            has_element?('extension-list-item', text: name)
          end
        end
      end
    end
  end
end
