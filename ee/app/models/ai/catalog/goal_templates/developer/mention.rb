# frozen_string_literal: true

module Ai
  module Catalog
    module GoalTemplates
      class Developer
        class Mention
          TEMPLATE = <<~GOAL.strip
            @%{triggered_by_username} is talking to you in a conversation on this %{resource_name}.

            <gitlab_context>
            %{source_context}
            </gitlab_context>

            <conversation>
            %{user_input}
            </conversation>

            Read the conversation and do what's being asked. Use tools for the work — reading the MR, running commands, pushing commits, or writing elsewhere when the task asks.

            Reply to @%{triggered_by_username} in your response, not by posting a comment — your response reaches them automatically, so a comment would duplicate it.

            If you change code, verify it, and assign @%{triggered_by_username} to any merge request you open.
          GOAL

          def self.template
            TEMPLATE
          end

          def self.vars(resource:, params:)
            resource_url = Gitlab::UrlBuilder.build(resource)
            triggered_by_username = params[:triggered_by_username].to_s
            note_id = params[:note_id]
            note_url = note_id ? "#{resource_url}#note_#{note_id}" : resource_url

            default_context = "#{Developer.resource_display_name(resource).capitalize}: #{note_url}"
            source_context = params[:source_context] || default_context

            {
              resource_name: Developer.resource_display_name(resource),
              triggered_by_username: triggered_by_username,
              source_context: source_context
            }
          end
        end
      end
    end
  end
end
