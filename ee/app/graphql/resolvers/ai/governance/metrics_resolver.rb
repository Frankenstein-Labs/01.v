# frozen_string_literal: true

module Resolvers
  module Ai
    module Governance
      class MetricsResolver < BaseResolver
        include Gitlab::Graphql::Authorize::AuthorizeResource

        type ::Types::Ai::Governance::MetricsType, null: true

        authorize :read_agent_artifacts
        authorizes_object!

        argument :timeframe, ::Types::Ai::Governance::MetricsTimeframeEnum,
          required: false,
          default_value: :last_7_days,
          description: 'Time window for the metrics. Defaults to LAST_7_DAYS.'

        argument :agent_class, ::Types::Ai::Governance::AgentClassEnum,
          required: false,
          default_value: :all,
          description: 'Agent class to segment the metrics by. Defaults to ALL.'

        def resolve(timeframe:, agent_class:)
          return unless Feature.enabled?(:ai_governance_dashboard, object.root_ancestor)

          response = ::Ai::Governance::MetricsService
            .new(object, current_user: current_user, timeframe: timeframe, agent_class: agent_class)
            .execute

          return unless response.success?

          response.payload
        end
      end
    end
  end
end
