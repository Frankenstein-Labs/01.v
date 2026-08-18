# frozen_string_literal: true

module Resolvers
  module Search
    module Blob
      class BlobSearchResolver < BaseResolver
        calls_gitaly!
        include Gitlab::Graphql::Authorize::AuthorizeResource
        include ::Search::SearchRateLimitable

        type Types::Search::Blob::BlobSearchType, null: true
        argument :chunk_count, type: GraphQL::Types::Int, required: false, experiment: { milestone: '17.2' },
          default_value: ::Search::Zoekt::MultiMatch::DEFAULT_REQUESTED_CHUNK_SIZE,
          description: 'Maximum chunks per file.'
        argument :exclude_forks, GraphQL::Types::Boolean, required: false, default_value: true,
          experiment: { milestone: '17.11' },
          description: 'Excludes forked projects in the search. Always false for project search. Default is true.'
        argument :group_id, ::Types::GlobalIDType[::Group], required: false, experiment: { milestone: '17.2' },
          description: 'Group to search in.'
        argument :include_archived, GraphQL::Types::Boolean, required: false, default_value: false,
          experiment: { milestone: '17.7' },
          description: 'Includes archived projects in the search. Always true for project search. Default is false.'
        argument :language, [GraphQL::Types::String], required: false, experiment: { milestone: '19.3' },
          validates: { length: { maximum: Types::BaseArgument::MAX_ARRAY_SIZE } },
          description: 'Filter results to the given detected languages (for example, `["Ruby", "Go"]`). Requires the ' \
            '`zoekt_language_aggregations` feature flag.'
        argument :page, type: GraphQL::Types::Int, required: false, default_value: 1, experiment: { milestone: '17.2' },
          description: 'Page number to fetch the results.'
        argument :per_page, type: GraphQL::Types::Int, required: false, experiment: { milestone: '17.2' },
          default_value: ::Search::Zoekt::SearchResults::DEFAULT_PER_PAGE, description: 'Number of results per page.'
        argument :project_id, ::Types::GlobalIDType[::Project], required: false, experiment: { milestone: '17.2' },
          description: 'Project to search in.'
        argument :regex, GraphQL::Types::Boolean, required: false, default_value: false,
          experiment: { milestone: '17.3' },
          description: 'Uses the regular expression search mode. Default is false.'
        argument :repository_ref, type: GraphQL::Types::String, required: false, experiment: { milestone: '17.2' },
          description: 'Repository reference to search in.'
        argument :search, GraphQL::Types::String, required: true, description: 'Searched term.'

        def ready?(**args)
          verify_search_rate_limit!(**args)
          verify_repository_ref!(args[:project_id]&.model_id, args[:repository_ref])
          @search_service = SearchService.new(current_user, search_params(**args))
          verify_global_search_is_allowed!
          verify_search_is_zoekt!
          super
        end

        def resolve(**args)
          start_time = Time.current
          results(**args)
        ensure
          if ::Gitlab::SafeRequestStore.active?
            duration = Time.current - start_time - ::Gitlab::Instrumentation::Zoekt.zoekt_call_duration
            ::Gitlab::Instrumentation::Zoekt.add_call_details(
              duration: duration,
              method: context[:request].method,
              path: context[:request].path,
              body: context.query.provided_variables
            )
            ::Gitlab::Instrumentation::Zoekt.add_graphql_duration(duration)
          end
        end

        private

        def verify_repository_ref!(project_id, ref)
          project = Project.find_by_id(project_id)
          return if project.nil? || ref.blank? || (project.default_branch == ref)

          raise Gitlab::Graphql::Errors::ArgumentError, 'Search is only allowed in project default branch'
        end

        def verify_global_search_is_allowed!
          return unless @search_service.level == 'global'
          return if @search_service.global_search_enabled_for_scope?

          raise Gitlab::Graphql::Errors::ArgumentError, 'Global search is not enabled for this scope'
        end

        def verify_search_is_zoekt!
          return if @search_service.search_type == 'zoekt'

          raise Gitlab::Graphql::Errors::ArgumentError, 'Zoekt search is not available for this request'
        end

        def results(**args)
          match_count = 0
          global_search_duration_s = Benchmark.realtime do
            @results = @search_service.search_objects unless count_only_operation?
            @search_results = @search_service.search_results
            match_count = @search_results.blobs_count
          end

          if @search_results.failed?
            if @search_results.server_error?
              Gitlab::Metrics::GlobalSearchSlis.record_error_rate(
                error: true,
                search_type: @search_service.search_type,
                search_level: @search_service.level,
                search_scope: @search_service.scope
              )
            end

            raise Gitlab::Graphql::Errors::BaseError.new(
              @search_results.error,
              extensions: { error_type: @search_results.error_type&.name&.demodulize }
            )
          end

          Gitlab::Metrics::GlobalSearchSlis.record_apdex(
            elapsed: global_search_duration_s,
            search_type: @search_service.search_type,
            search_level: @search_service.level,
            search_scope: @search_service.scope
          )

          {
            duration_s: global_search_duration_s,
            match_count: match_count,
            file_count: @search_results.file_count,
            search_level: @search_service.level,
            search_type: @search_service.search_type,
            per_page: args[:per_page],
            files: @results
          }
        end

        def search_params(**args)
          {
            group_id: args[:group_id]&.model_id,
            project_id: args[:project_id]&.model_id,
            search: args[:search],
            page: args[:page],
            per_page: args[:per_page],
            chunk_count: args[:chunk_count],
            scope: scope,
            regex: args[:regex],
            include_archived: args[:include_archived],
            exclude_forks: args[:exclude_forks],
            language: args[:language]
          }
        end

        def scope
          'blobs'
        end

        def count_only_operation?
          context.query.operation_name == 'getBlobSearchCountQuery'
        end
      end
    end
  end
end
