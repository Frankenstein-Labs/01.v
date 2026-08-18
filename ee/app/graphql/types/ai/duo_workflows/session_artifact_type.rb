# frozen_string_literal: true

# rubocop:disable Graphql/AuthorizeTypes -- Authorization is enforced upstream by
# `SessionArtifactsFinder#allowed?` which gates on `:read_agent_artifacts`.
module Types
  module Ai
    module DuoWorkflows
      class SessionArtifactType < ::Types::BaseObject
        graphql_name 'DuoWorkflowSessionArtifact'
        description 'A Duo Agent Platform session artifact.'

        # Dispatches `count` to a ClickHouse COUNT query when the underlying
        # collection is a QueryBuilder, and falls back to AR `size` on the PG path.
        class SessionArtifactConnectionType < ::Types::CountableConnectionType
          graphql_name 'DuoWorkflowSessionArtifactConnection'

          def count(limit: nil)
            conn_items = object.items
            if conn_items.is_a?(::ClickHouse::Client::QueryBuilder)
              base = conn_items.dup.tap { |q| q.manager.ast.orders = [] }

              inner_sql = if limit
                            base.select(Arel.sql('1')).limit(limit + 1).to_sql
                          else
                            base.to_sql
                          end

              outer = ::ClickHouse::Client::QueryBuilder
                        .new(Arel.sql("(#{inner_sql})"))
                        .select(Arel.sql('count()'))

              total = ::ClickHouse::Client.select(outer, :main).first&.fetch('count()', 0).to_i
              limit ? [total, limit + 1].min : total
            else
              super
            end
          end
        end

        connection_type_class SessionArtifactConnectionType

        field :id, GraphQL::Types::ID,
          null: false,
          description: 'Global ID of the session, as an `Ai::DuoWorkflows::Workflow`.'

        field :workflow_definition, GraphQL::Types::String,
          null: false,
          description: 'Workflow definition type of the session.'

        field :web_path, GraphQL::Types::String,
          null: true,
          description: 'Path of the session.'

        field :download_path, GraphQL::Types::String,
          null: true,
          description: 'Path to download the session artifact as a JSON file.'

        # rubocop:disable GraphQL/ExtractType -- audit_events_count and audit_events are distinct
        # views (count vs. connection) of the same session metadata and belong directly on this type.
        field :audit_events_count, GraphQL::Types::Int,
          null: false,
          description: 'Number of audit events recorded for the session.'

        field :audit_events, ::Types::AuditEvents::AiAuditEventType.connection_type,
          null: true,
          description: 'Audit events recorded for the session. Readable with ' \
            '`read_agent_artifacts` on the parent group or project; does not require ' \
            'access to the underlying workflow.'
        # rubocop:enable GraphQL/ExtractType

        # `project` is eager-loaded by `PostgresqlFinder` via `.with_project`.
        # On the ClickHouse path, projects are batch-loaded by `project_id`.
        field :project, ::Types::ProjectType,
          null: true,
          description: 'Project the session belongs to.'

        # The initiating user is eager-loaded by `PostgresqlFinder` via
        # `.with_user`. On the ClickHouse path, users are batch-loaded by `user_id`.
        field :triggered_by, ::Types::UserType,
          null: true,
          description: 'User who initiated the session.'

        # rubocop:disable GraphQL/ExtractType -- workflow_definition and workflow_created_at are
        # denormalized session metadata that belong directly on this type, not in a nested type.
        field :workflow_created_at, Types::TimeType,
          null: false,
          description: 'Timestamp of when the session was created.'
        # rubocop:enable GraphQL/ExtractType

        def id
          ::Gitlab::GlobalId.build(model_name: 'Ai::DuoWorkflows::Workflow', id: workflow_id_value).to_s
        end

        def workflow_definition
          object.is_a?(Hash) ? object['workflow_definition'] : object.workflow_definition
        end

        def workflow_created_at
          workflow_created_at_value
        end

        def project
          if object.is_a?(Hash)
            ::Gitlab::Graphql::Loaders::BatchModelLoader.new(::Project, object['project_id']).find
          else
            object.project
          end
        end

        def triggered_by
          if object.is_a?(Hash)
            ::Gitlab::Graphql::Loaders::BatchModelLoader.new(::User, object['user_id']).find
          else
            object.user
          end
        end

        # Batches a single COUNT GROUP BY query across the full page of artifacts,
        # avoiding N+1 count queries. Includes workflow_created_at in the batch key
        # to enable partition pruning on the CH audit events table.
        def audit_events_count
          BatchLoader::GraphQL.for({ workflow_id: workflow_id_value, created_at: workflow_created_at_value })
            .batch(key: 'session-artifact-audit-events-count') do |pairs, loader|
            counts = fetch_audit_event_counts(pairs)
            pairs.each { |pair| loader.call(pair, counts[pair[:workflow_id]] || 0) }
          end
        end

        def web_path
          return object.web_path unless object.is_a?(Hash)

          project_id = object['project_id']
          return unless project_id.present?

          BatchLoader::GraphQL.for({ project_id: project_id, workflow_id: workflow_id_value })
            .batch(key: 'ch-session-artifact-web-path') do |pairs, loader|
              batch_load_paths(pairs, loader) { |project, pair| "#{::Gitlab::Routing.url_helpers.project_automate_agent_sessions_path(project)}/#{pair[:workflow_id]}" }
            end
        end

        def download_path
          return object.download_path unless object.is_a?(Hash)

          project_id = object['project_id']
          return unless project_id.present?

          BatchLoader::GraphQL.for({ project_id: project_id, workflow_id: workflow_id_value })
            .batch(key: 'ch-session-artifact-download-path') do |pairs, loader|
              batch_load_paths(pairs, loader) { |project, pair| ::Gitlab::Routing.url_helpers.download_project_security_agent_artifact_path(project, pair[:workflow_id]) }
            end
        end

        def audit_events
          workflow = ::Ai::DuoWorkflows::Workflow.find_by_id(workflow_id_value)
          return ::AuditEvents::AiAuditEvent.none unless workflow

          ::AuditEvents::AiAuditEvents::Finder.new(workflow: workflow).execute
        end

        private

        # rubocop:disable Rails/Pluck -- pairs is an Array, not an ActiveRecord relation
        def fetch_audit_event_counts(pairs)
          min_created_at = pairs.map { |p| p[:created_at] }.min
          workflow_ids = pairs.map { |p| p[:workflow_id] }

          if ::Gitlab::ClickHouse.globally_enabled_for_analytics?
            ::AuditEvents::AiAuditEvents::ClickHouseFinder.counts_for_workflows(
              workflow_ids, min_created_at: min_created_at
            )
          else
            ::AuditEvents::AiAuditEvent.counts_for_workflows(
              workflow_ids, min_created_at: min_created_at
            )
          end
        end
        # rubocop:enable Rails/Pluck

        def workflow_id_value
          object.is_a?(Hash) ? object['id'] : object.workflow_id
        end

        def workflow_created_at_value
          value = object.is_a?(Hash) ? object['created_at'] : object.workflow_created_at
          value.is_a?(String) ? Time.zone.parse(value) : value
        end

        def batch_load_paths(pairs, loader)
          projects = ::Project.id_in(pairs.map { |p| p[:project_id] }.uniq).index_by(&:id) # rubocop:disable Rails/Pluck -- pairs is an Array, not an ActiveRecord relation

          pairs.each do |pair|
            project = projects[pair[:project_id]]
            next unless project

            loader.call(pair, yield(project, pair))
          end
        end
      end
    end
  end
end
# rubocop:enable Graphql/AuthorizeTypes
