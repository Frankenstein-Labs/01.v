# frozen_string_literal: true

module QA
  module EE
    module Page
      module Group
        module Settings
          class LDAPSync < ::QA::Page::Base
            include QA::Page::Component::Dropdown

            view 'ee/app/views/ldap_group_links/_form.html.haml' do
              element 'add-sync-button'
              element 'ldap-group-field'
              element 'ldap-sync-group-radio'
              element 'ldap-sync-user-filter-radio'
              element 'ldap-user-filter-field'
            end

            def set_ldap_group_sync_method
              check_element('ldap-sync-group-radio', true)
            end

            def set_ldap_user_filter_sync_method
              check_element('ldap-sync-user-filter-radio', true)
            end

            def set_group_cn(group_cn)
              within_element('ldap-group-field') do
                expand_select_list
              end
              search_and_select(group_cn)
            end

            def set_user_filter(user_filter)
              fill_element('ldap-user-filter-field', user_filter)
            end

            def set_ldap_access(access_level)
              within_element('ldap-access-field') do
                expand_select_list
              end
              select_item(access_level)
            end

            def click_add_sync_button
              click_element('add-sync-button')
            end
          end
        end
      end
    end
  end
end
