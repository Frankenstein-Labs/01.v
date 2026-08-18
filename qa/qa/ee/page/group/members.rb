# frozen_string_literal: true

module QA
  module EE
    module Page
      module Group
        class Members < QA::Page::Base
          view 'ee/app/helpers/groups/ldap_sync_helper.rb' do
            element 'sync-now-button'
          end

          view 'ee/app/helpers/groups/ldap_sync_helper.rb' do
            element 'sync-ldap-confirm-button'
          end

          view 'ee/app/views/groups/group_members/_link_to_pending_members.html.haml' do
            element 'pending-members-alert'
          end

          # Sync can be started by a scheduled background job in which case
          # the "Sync now" button will not be shown
          def click_sync_now_if_needed
            wait_for_requests

            return unless has_element?('sync-now-button', wait: 2)

            click_element 'sync-now-button'
            click_element 'sync-ldap-confirm-button'
          end

          def has_pending_members_alert?
            has_element?('pending-members-alert')
          end

          def click_pending_members
            click_link('pending members')
          end
        end
      end
    end
  end
end
