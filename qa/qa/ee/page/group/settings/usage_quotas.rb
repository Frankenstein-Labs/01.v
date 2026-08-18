# frozen_string_literal: true

module QA
  module EE
    module Page
      module Group
        module Settings
          class UsageQuotas < QA::Page::Base
            view 'app/assets/javascripts/usage_quotas/storage/utils.js' do
              element 'storage-tab'
            end

            view 'ee/app/assets/javascripts/usage_quotas/storage/namespace/components/storage_usage_statistics.vue' do
              element 'namespace-usage-total-content'
            end

            view 'app/views/groups/usage_quotas/root.html.haml' do
              element 'group-usage-message-content'
            end

            view 'app/assets/javascripts/usage_quotas/storage/namespace/components/dependency_proxy_usage.vue' do
              element 'dependency-proxy-size-content'
            end

            view 'app/assets/javascripts/usage_quotas/storage/namespace/components/project_list.vue' do
              element 'project-repository-size-content'
              element 'project-wiki-size-content'
              element 'project-snippets-size-content'
              element 'project-containers-registry-size-content'
            end

            view 'ee/app/assets/javascripts/pending_members/components/app.vue' do
              element 'pending-members-content'
              element 'approve-member-button'
            end

            def click_storage_tab
              click_element('storage-tab')
            end

            def project_repository_size
              find_element('project-repository-size-content').text
            end

            def project_snippets_size
              find_element('project-snippets-size-content').text
            end

            def project_wiki_size
              find_element('project-wiki-size-content').text
            end

            def project_containers_registry_size
              find_element('project-containers-registry-size-content').text
            end

            def dependency_proxy_size
              find_element('dependency-proxy-size-content').text
            end

            def namespace_usage_total
              find_element('namespace-usage-total-content').text
            end

            def group_usage_message
              find_element('group-usage-message-content').text
            end

            def pending_members
              find_element('pending-members-content').text
            end

            def click_approve_member_button
              click_element('approve-member-button')
            end

            def confirm_member_approval
              click_button('OK')
            end
          end
        end
      end
    end
  end
end
