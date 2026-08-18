# frozen_string_literal: true

module Ai
  module Catalog
    class FoundationalFlow
      module Definitions
        module Developer
          module_function

          REFERENCE = 'developer/v1'

          def configuration
            {
              foundational_flow_reference: REFERENCE,
              display_name: s_(
                "FoundationalFlow|Developer"
              ),
              description: s_(
                "FoundationalFlow|Turn feedback into actionable merge requests or issues."
              ),
              feature_maturity: "ga",
              avatar: "gitlab-duo-flow.png",
              pre_approved_agent_privileges: [
                ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES,
                ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_ONLY_GITLAB,
                ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB,
                ::Ai::DuoWorkflows::Workflow::AgentPrivileges::USE_GIT
              ],
              environment: "web",
              triggers: [
                ::Ai::FlowTrigger::EVENT_TYPES[:assign],
                ::Ai::FlowTrigger::EVENT_TYPES[:mention],
                ::Ai::FlowTrigger::EVENT_TYPES[:merge_request]
              ],
              goal_templates: ::Ai::Catalog::GoalTemplates::Developer,
              flow_version: '^2.0.0'
            }
          end
        end
      end
    end
  end
end
