# frozen_string_literal: true

module Types
  module WorkItems
    module Widgets
      # rubocop:disable Graphql/AuthorizeTypes -- authorized via parent work item
      class AgentPlanType < BaseObject
        graphql_name 'WorkItemWidgetAgentPlan'
        description 'Represents an agent plan widget.'

        authorize_granular_token skip_reason: :parent_authorizes

        implements ::Types::WorkItems::WidgetInterface

        # Wraps the generated `content_html_resolver` (defined below by `markdown_field`) so it
        # also tracks the agent plan read. Prepending keeps `super` pointing at the generated
        # resolver.
        module ContentHtmlTracking
          def content_html_resolver
            super.tap { track_agent_plan_read(object) }
          end
        end
        prepend ContentHtmlTracking

        def self.authorization_scopes
          super + [:ai_workflows]
        end

        # Fires a single `work_item_agent_plan_read` internal event per (request, work item).
        # Skips when:
        # - the agent plan has no content (don't count opens of work items that never had a plan)
        # - there is no authenticated user (TrackingService requires a User)
        # - the event was already tracked for this work item in the current request
        def self.track_agent_plan_read(widget, current_user)
          return unless widget&.content.present?
          return unless current_user.is_a?(User)

          work_item = widget.work_item
          guard_key = [:agent_plan_read_tracked, work_item.id]

          if ::Gitlab::SafeRequestStore.active?
            return if ::Gitlab::SafeRequestStore[guard_key]

            ::Gitlab::SafeRequestStore[guard_key] = true
          end

          ::Gitlab::WorkItems::Instrumentation::TrackingService.new(
            work_item: work_item,
            current_user: current_user,
            event: ::Gitlab::WorkItems::Instrumentation::EventActions::AGENT_PLAN_READ,
            extra_properties: {
              source: ::Gitlab::WorkItems::Instrumentation::TrackingService.current_source
            }
          ).execute
        end

        field :ai_planning_enabled, GraphQL::Types::Boolean,
          null: false,
          scopes: [:api, :read_api, :ai_workflows],
          description: 'Indicates whether AI planning is enabled for the work item.',
          method: :ai_planning_enabled_for_widget

        # The work item's agent plan content may be stored in object storage, so each call
        # to `content` or `content_html` can cost a network round-trip. We cap call count so
        # that, for example, listing many work items with their agent plans is impossible.
        field :content, GraphQL::Types::String,
          null: true,
          scopes: [:api, :read_api, :ai_workflows],
          description: 'Content of the agent plan. ' \
            'This field can only be resolved for one work item in any single request.' do
          extension ::Gitlab::Graphql::Limit::FieldCallCount, limit: 1
        end

        field :readiness_score, GraphQL::Types::Int,
          null: true,
          scopes: [:api, :read_api, :ai_workflows],
          experiment: { milestone: '19.3' },
          description: 'Readiness score of the agent plan (0-100). ' \
            'Null when the score is not yet available. ' \
            'Only available when the `workplan_score` feature flag is enabled.'

        markdown_field :content_html,
          null: true,
          scopes: [:api, :read_api, :ai_workflows],
          extensions: [::Gitlab::Graphql::Limit::FieldCallCount => { limit: 1 }],
          description: 'GitLab Flavored Markdown rendering of `content`. ' \
            'This field can only be resolved for one work item in any single request.' do |widget|
          widget.work_item.agent_plan
        end

        def content
          object.content.tap do |value|
            track_agent_plan_read(object) if value.present?
          end
        end

        def readiness_score
          return unless Feature.enabled?(:workplan_score, object.work_item.namespace&.root_ancestor)

          object.readiness_score
        end

        private

        def track_agent_plan_read(widget)
          self.class.track_agent_plan_read(widget, current_user)
        end
      end
      # rubocop:enable Graphql/AuthorizeTypes
    end
  end
end
