# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module PathLocks
          class Index < QA::Page::Base
            include QA::Page::Component::ConfirmModal

            view 'ee/app/views/projects/path_locks/_path_lock.html.haml' do
              element 'locked-file-content'
              element 'locked-file-title-content'
              element 'unlock-button'
            end

            def has_file_with_title?(file_title)
              has_element? 'locked-file-title-content', text: file_title
            end

            def unlock_file(file_title)
              within_element 'locked-file-content', text: file_title do
                click_element 'unlock-button'
              end
              click_confirmation_ok_button
            end
          end
        end
      end
    end
  end
end
