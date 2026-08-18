# frozen_string_literal: true

module Ai
  module Catalog
    class FoundationalFlow
      module Definitions
        module SecurityReview
          module_function

          def configuration
            {
              foundational_flow_reference: "security_review/v1",
              display_name: s_(
                "FoundationalFlow|Security Review"
              ),
              description: s_(
                "FoundationalFlow|Review merge request code changes for business logic security vulnerabilities."
              ),
              avatar: "security-flow.png",
              feature_maturity: "beta",
              ai_feature: "security_review",
              pre_approved_agent_privileges: [
                ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB,
                ::Ai::DuoWorkflows::Workflow::AgentPrivileges::RUN_COMMANDS,
                ::Ai::DuoWorkflows::Workflow::AgentPrivileges::USE_GIT
              ],
              environment: "web",
              ultimate_only: true,
              # Security Review owns its own discussion threads (it replies to and
              # resolves them in its validate_and_publish step), so it skips the
              # generic mention progress note.
              suppress_mention_progress_note: true,
              triggers: [
                ::Ai::FlowTrigger::EVENT_TYPES[:assign_reviewer],
                ::Ai::FlowTrigger::EVENT_TYPES[:mention]
              ],
              goal_templates: ::Ai::Catalog::GoalTemplates::SecurityReview
            }
          end
        end
      end
    end
  end
end
