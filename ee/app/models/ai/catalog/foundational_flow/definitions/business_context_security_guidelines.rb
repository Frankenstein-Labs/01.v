# frozen_string_literal: true

module Ai
  module Catalog
    class FoundationalFlow
      module Definitions
        module BusinessContextSecurityGuidelines
          module_function

          def configuration
            {
              foundational_flow_reference: "business_context_security_guidelines/experimental",
              display_name: s_(
                "FoundationalFlow|Vulnerability Context Analysis"
              ),
              description: s_(
                "FoundationalFlow|Analyze project codebase to generate security context for " \
                  "vulnerability prioritization."
              ),
              avatar: "security-flow.png",
              feature_maturity: "experimental",
              feature_flag: "sdlc_context_agent_trigger",
              pre_approved_agent_privileges: [
                ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_ONLY_GITLAB,
                ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB
              ],
              environment: "ambient",
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
