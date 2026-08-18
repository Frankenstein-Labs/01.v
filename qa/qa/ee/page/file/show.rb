# frozen_string_literal: true

module QA
  module EE
    module Page
      module File
        module Show
          extend QA::Page::PageConcern

          def self.prepended(base)
            super

            base.class_eval do
              include QA::Page::Component::ConfirmModal

              # These two lock button elements are used for locking at directory level
              view 'ee/app/assets/javascripts/repository/components/lock_directory_button.vue' do
                element 'lock-button'
                element 'disabled-lock-button'
              end

              view 'ee/app/assets/javascripts/vue_shared/components/code_owners/code_owners.vue' do
                element 'collapse-toggle'
              end
            end
          end

          def lock
            click_element('lock-button')
            click_confirmation_ok_button

            unless has_element?('lock-button', text: 'Unlock')
              raise QA::Page::Base::ElementNotFound, %q(Button did not show expected state)
            end
          end

          def unlock
            click_element('lock-button')
            click_confirmation_ok_button

            unless has_element?('lock-button', text: 'Lock')
              raise QA::Page::Base::ElementNotFound, %q(Button did not show expected state)
            end
          end

          def has_lock_button_disabled?
            has_element?('disabled-lock-button')
          end

          def has_code_owners_container?
            has_element?('codeowners-container')
          end

          def reveal_code_owners
            if has_element?('collapse-toggle', text: 'Show all')
              scroll_to_element('collapse-toggle', text: 'Show all')
              click_element('collapse-toggle', text: 'Show all')
            end
          end
        end
      end
    end
  end
end
