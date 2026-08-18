# frozen_string_literal: true

module Ai
  module Catalog
    module GoalTemplates
      class Developer
        class AssignIssue
          TEMPLATE = <<~GOAL.strip
            @%{triggered_by_username} assigned you to solve the following %{resource_name}: %{resource_url}

            Fetch the details and understand the problem thoroughly before writing any code. Consider what might be causing the issue and where in the codebase the relevant logic lives. If there are multiple possible approaches, reason about the tradeoffs and pick the simplest one that fully addresses the issue. Implement your solution, verify it works, then create a merge request with your changes.

            When you have completed your work, @mention @%{triggered_by_username} in a comment on the issue to notify them. Assign @%{triggered_by_username} as the assignee of the merge request unless told differently.
          GOAL

          def self.template
            TEMPLATE
          end

          def self.vars(resource:, params:, **_)
            {
              resource_url: Gitlab::UrlBuilder.build(resource),
              resource_name: Developer.resource_display_name(resource),
              triggered_by_username: params[:triggered_by_username].to_s
            }
          end
        end
      end
    end
  end
end
