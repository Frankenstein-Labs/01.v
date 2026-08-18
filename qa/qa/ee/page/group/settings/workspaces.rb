# frozen_string_literal: true

module QA
  module EE
    module Page
      module Group
        module Settings
          class Workspaces < QA::Page::Base
            view 'ee/app/assets/javascripts/workspaces/agent_mapping/components/agent_mapping_status_toggle.vue' do
              element 'agent-mapping-status-toggle'
            end

            def allow_agent
              click_link 'All agents'

              return unless has_element?('agent-mapping-status-toggle', text: 'Allow', wait: 3)

              click_element('agent-mapping-status-toggle')
              click_button 'Allow agent'
            end
          end
        end
      end
    end
  end
end
