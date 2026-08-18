# frozen_string_literal: true

module QA
  module EE
    module Page
      module Admin
        class Dashboard < QA::Page::Base
          view 'ee/app/views/admin/licenses/_breakdown.html.haml' do
            element 'users-in-license-content'
            element 'billable-users-content'
          end

          def self.path
            '/admin'
          end

          def users_in_license
            find_element('users-in-license-content').text
          end

          def billable_users
            find_element('billable-users-content').text
          end
        end
      end
    end
  end
end
