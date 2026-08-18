# frozen_string_literal: true

module Ai
  module Catalog
    class FoundationalFlow
      module Definitions
        module SecretsFpDetection
          module_function

          def configuration
            {
              foundational_flow_reference: "secrets_fp_detection/v1",
              display_name: s_(
                "FoundationalFlow|Secret Detection False Positive Detection"
              ),
              description: s_(
                "FoundationalFlow|Analyze critical Secret Detection vulnerabilities."
              ),
              feature_maturity: "ga",
              ai_feature: "secret_vulnerability_fp_detection",
              avatar: "security-flow.png",
              pre_approved_agent_privileges: [
                ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES,
                ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_ONLY_GITLAB,
                ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB,
                ::Ai::DuoWorkflows::Workflow::AgentPrivileges::RUN_COMMANDS,
                ::Ai::DuoWorkflows::Workflow::AgentPrivileges::USE_GIT
              ],
              environment: "web",
              triggers: [],
              supported_events: [],
              ultimate_only: true
            }
          end
        end
      end
    end
  end
end
