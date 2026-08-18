# frozen_string_literal: true

module Ai
  module DuoWorkflows
    module SessionArtifacts
      class PostgresqlFinder
        def initialize(namespace:, params: {})
          @namespace = namespace
          @params = params
        end

        def execute
          # Scopes to the namespace hierarchy via a single `namespace_id IN (...)`
          # lookup, optimized with the in-operator technique so keyset/offset
          # pagination reads close to one page worth of rows instead of
          # materializing the whole hierarchy.
          # See https://docs.gitlab.com/development/database/efficient_in_operator_queries
          # `with_project` is applied to the result, not the input scope: the
          # in-operator builder returns a fresh `SELECT * FROM (cte)` relation, so
          # a preload set on the input scope would be dropped.
          artifact_scope = ::Ai::DuoWorkflows::SessionArtifact
          artifact_scope = artifact_scope.for_workflow(params[:workflow_id]) if params[:workflow_id].present?
          ::Gitlab::Pagination::Keyset::InOperatorOptimization::QueryBuilder.new(
            scope: artifact_scope.with_keyset_order,
            array_scope: array_scope,
            array_mapping_scope: ::Ai::DuoWorkflows::SessionArtifact.method(:in_optimization_array_mapping_scope),
            finder_query: ::Ai::DuoWorkflows::SessionArtifact.method(:in_optimization_finder_query)
          ).execute.with_project.with_user
        end

        private

        attr_reader :namespace, :params

        # All namespace ids in the hierarchy. `skope: ::Namespace` is required so
        # the result includes project namespaces (whose `traversal_ids` contain
        # the group id); the default `skope` would restrict to `Group` and miss
        # every project-scoped artifact.
        def array_scope
          namespace.self_and_descendants(skope: ::Namespace).select(:id)
        end
      end
    end
  end
end
