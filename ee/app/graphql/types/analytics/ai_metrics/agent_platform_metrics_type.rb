# frozen_string_literal: true

module Types
  module Analytics
    module AiMetrics
      # rubocop: disable Graphql/AuthorizeTypes -- authorized by parent type
      class AgentPlatformMetricsType < BaseObject
        graphql_name 'agentPlatformMetrics'
        description 'Requires ClickHouse. Premium and Ultimate only.'

        include ::Analytics::AiEventFields

        exposed_events(:agent_platform).each do |event_name|
          # Sample field transformation
          # "agent_platform_session_created" turns into "created_session_event_count"
          field_name = :"#{event_name.delete_prefix('agent_platform_session_')}_session#{COUNT_FIELD_SUFFIX}"

          field field_name, GraphQL::Types::Int,
            null: true,
            description: "Total count of `#{event_name}` event."
        end

        field :flow_metrics,
          null: true,
          description: 'Aggregated flow metrics for Duo Agent Platform.',
          resolver: Resolvers::Analytics::AiMetrics::AgentPlatform::FlowMetricsResolver

        field :user_flow_counts,
          null: true,
          description: 'Aggregated count of flows per user.',
          resolver: Resolvers::Analytics::AiMetrics::AgentPlatform::UserFlowCountsResolver
      end
      # rubocop: enable Graphql/AuthorizeTypes
    end
  end
end
