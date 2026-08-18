# frozen_string_literal: true

module QA
  module EE
    module Page
      module Workspace
        class New < QA::Page::Base
          include QA::Page::Component::Dropdown

          view 'ee/app/assets/javascripts/workspaces/user/pages/create.vue' do
            element 'workspace-devfile-project-id-field'
            element 'workspace-cluster-agent-id-field'
            element 'create-workspace'
          end

          view 'ee/app/assets/javascripts/workspaces/user/components/workspace_variables.vue' do
            element 'add-variable'
          end

          def select_devfile_project(project)
            click_element('workspace-devfile-project-id-field')
            search_and_select(project)
          end

          def select_cluster_agent(agent)
            agent_selector = find_element('workspace-cluster-agent-id-field')
            options = agent_selector.all('option')

            raise "No agent available" if options.empty?

            agent_selector.select agent
          end

          def add_new_variable(key, value)
            click_element('add-variable')
            fill_in 'Variable Key', with: key
            fill_in 'Variable Value', with: value
          end

          def save_workspace
            click_element('create-workspace')
          end
        end
      end
    end
  end
end
