# frozen_string_literal: true

module Ai
  module Catalog
    class FoundationalFlow
      module Definitions
        module RiskClassification
          module_function

          def configuration
            {
              foundational_flow_reference: "risk_classification/v1",
              display_name: s_(
                "FoundationalFlow|Risk Classification"
              ),
              description: s_(
                "FoundationalFlow|Classify the risk of a merge request so review effort can be " \
                  "routed to the changes that warrant it."
              ),
              avatar: "gitlab-duo-flow.png",
              feature_maturity: "experimental",
              ai_feature: "risk_classification",
              environment: "web",
              ultimate_only: true,
              feature_flag: "duo_mr_risk_classification",
              pre_approved_agent_privileges: [
                ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB,
                ::Ai::DuoWorkflows::Workflow::AgentPrivileges::RUN_COMMANDS,
                ::Ai::DuoWorkflows::Workflow::AgentPrivileges::USE_GIT
              ],
              suppress_agent_session_note: true,
              # Triggered programmatically on open and on draft-to-ready, not by
              # mention or reviewer assignment.
              triggers: [],
              # The goal is the merge request iid, so the session links to that
              # merge request.
              noteable_resolver: ->(project:, goal:) { project.merge_requests.find_by_iid(goal) }
            }
          end
        end
      end
    end
  end
end
