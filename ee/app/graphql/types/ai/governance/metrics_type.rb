# frozen_string_literal: true

module Types
  module Ai
    module Governance
      # Reachable only through fields that already authorize against the
      # group or project, so no object-level authorization is needed here.
      class MetricsType < BaseObject # rubocop:disable Graphql/AuthorizeTypes -- parent field authorizes
        graphql_name 'AiGovernanceMetrics'
        description 'Aggregated AI governance dashboard metrics.'

        authorize_granular_token skip_reason: :parent_authorizes

        field :agents, Types::Ai::Governance::KpiType, null: true,
          description: 'Distinct AI agents with sessions in the timeframe.'
        field :sessions, Types::Ai::Governance::KpiType, null: true,
          description: 'AI agent sessions in the timeframe.'
      end
    end
  end
end
