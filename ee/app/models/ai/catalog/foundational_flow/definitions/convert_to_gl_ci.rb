# frozen_string_literal: true

module Ai
  module Catalog
    class FoundationalFlow
      module Definitions
        module ConvertToGlCi
          module_function

          def configuration
            {
              foundational_flow_reference: "convert_to_gl_ci/v1",
              display_name: s_(
                "FoundationalFlow|Convert to GitLab CI/CD"
              ),
              description: s_(
                "FoundationalFlow|Migrate your Jenkins pipelines to GitLab CI/CD."
              ),
              feature_maturity: "ga",
              avatar: "convert-ci-flow.png",
              pre_approved_agent_privileges: [
                ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES,
                ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_ONLY_GITLAB,
                ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB,
                ::Ai::DuoWorkflows::Workflow::AgentPrivileges::USE_GIT
              ],
              environment: "web",
              triggers: []
            }
          end
        end
      end
    end
  end
end
