# frozen_string_literal: true

module Ai
  module Catalog
    class FoundationalFlow
      module Definitions
        module CodeReview
          module_function

          REFERENCE = 'code_review/v1'

          def configuration
            {
              foundational_flow_reference: REFERENCE,
              display_name: s_(
                "FoundationalFlow|Code Review"
              ),
              description: s_(
                "FoundationalFlow|Streamline code reviews by analyzing code changes and relevant " \
                  "codebase context. " \
                  "[How can I use this flow](https://docs.gitlab.com/user/duo_agent_platform/flows/foundational_flows/code_review/#use-the-flow)?"
              ),
              avatar: "code-review-flow.png",
              feature_maturity: "ga",
              ai_feature: "review_merge_request",
              pre_approved_agent_privileges: [
                ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB,
                ::Ai::DuoWorkflows::Workflow::AgentPrivileges::RUN_COMMANDS,
                ::Ai::DuoWorkflows::Workflow::AgentPrivileges::USE_GIT
              ],
              # Code Review posts its own progress note when a review starts, so it
              # opts out of the generic agent-session-started system note.
              suppress_agent_session_note: true,
              # Code Review sets the goal to the merge request iid, so the noteable
              # resolves to that merge request and the session links to it.
              noteable_resolver: ->(project:, goal:) { project.merge_requests.find_by_iid(goal) },
              triggers: []
            }
          end
        end
      end
    end
  end
end
