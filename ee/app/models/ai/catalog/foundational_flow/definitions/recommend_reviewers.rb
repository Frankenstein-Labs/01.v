# frozen_string_literal: true

module Ai
  module Catalog
    class FoundationalFlow
      module Definitions
        module RecommendReviewers
          module_function

          def configuration
            {
              foundational_flow_reference: "recommend_reviewers/v1",
              display_name: s_(
                "FoundationalFlow|Recommend Reviewers"
              ),
              description: s_(
                "FoundationalFlow|Recommend reviewers for merge requests based on availability, " \
                  "workload, and timezone."
              ),
              feature_maturity: "beta",
              avatar: "gitlab-duo-flow.png",
              pre_approved_agent_privileges: [
                ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB
              ],
              triggers: [],
              goal_templates: ::Ai::Catalog::GoalTemplates::RecommendReviewers,
              additional_context_resolver: ->(resource:) do
                # This flow has no supported_events restriction, so a trigger can
                # fire it for a non-merge-request resource. Only merge requests
                # have the reviewer data the builder reads.
                next {} unless resource.is_a?(::MergeRequest)

                {
                  "reviewer_data" => ::Ai::DuoWorkflows::RecommendReviewers::ReviewerDataBuilder.build(resource)
                }
              end
            }
          end
        end
      end
    end
  end
end
