# frozen_string_literal: true

module Types
  module Analytics
    # rubocop:disable Graphql/AuthorizeTypes -- every requested source is authorized
    # per-engine via resource_ability in the engine resolver.
    class AnalyticsType < BaseObject
      graphql_name 'Analytics'
      description 'ClickHouse-based analytics endpoints aggregating data across groups and projects. ' \
        'Data can be delayed by 10 minutes.'

      extend ::Gitlab::Database::Aggregation::Graphql::Mounter

      mount_aggregation_engine ::Analytics::AggregationEngines::AgentPlatformSessions,
        field_name: :agent_platform_sessions,
        description: 'Aggregation engine for GitLab Duo Agent Platform sessions usage' do
        self.resource_ability = :read_pro_ai_analytics
      end

      mount_aggregation_engine ::Analytics::AggregationEngines::CodeSuggestions,
        field_name: :duo_code_suggestions,
        description: 'Aggregation engine for GitLab Duo Code Suggestions usage' do
        self.resource_ability = :read_pro_ai_analytics
      end

      mount_aggregation_engine ::Analytics::AggregationEngines::AiUsageEvents,
        field_name: :duo_usage_events,
        description: 'Aggregation engine for GitLab Duo AI usage events' do
        self.resource_ability = :read_pro_ai_analytics
      end

      mount_aggregation_engine ::Analytics::AggregationEngines::Pipelines,
        field_name: :pipelines,
        description: 'Aggregation engine for CI pipeline analytics',
        experiment: { milestone: '19.2' } do
        self.resource_ability = :read_ci_cd_analytics
      end

      mount_aggregation_engine ::Analytics::AggregationEngines::FinishedPipelines,
        field_name: :finished_pipelines,
        description: 'Aggregation engine for finished pipelines analytics',
        experiment: { milestone: '19.0' } do
        self.resource_ability = :read_ci_cd_analytics
      end

      mount_aggregation_engine ::Analytics::AggregationEngines::Contributions,
        field_name: :contributions,
        description: 'Aggregation engine for contribution analytics',
        experiment: { milestone: '19.0' } do
        self.resource_ability = :read_contribution_analytics
      end

      mount_aggregation_engine ::Analytics::AggregationEngines::Deployments,
        field_name: :deployments,
        description: 'Aggregation engine for deployment analytics',
        experiment: { milestone: '19.0' } do
        self.resource_ability = :read_dora4_analytics
      end

      mount_aggregation_engine ::Analytics::AggregationEngines::MergeRequests,
        field_name: :merge_requests,
        description: 'Aggregation engine for merge request analytics',
        experiment: { milestone: '19.2' },
        granular_authorization_opts: {
          permissions: :read_cycle_analytics,
          boundaries: [
            { boundary: :itself, boundary_type: :project },
            { boundary: :itself, boundary_type: :group }
          ]
        } do
        self.resource_ability = :read_cycle_analytics
      end
    end
    # rubocop:enable Graphql/AuthorizeTypes
  end
end
