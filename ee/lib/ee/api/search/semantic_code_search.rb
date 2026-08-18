# frozen_string_literal: true

module EE
  module API
    module Search
      class SemanticCodeSearch < ::API::Base # rubocop:disable Gitlab/EeOnlyClass -- standalone EE-only endpoint
        include ::API::APIGuard
        include ::API::Concerns::McpAccess

        helpers ::Ai::ActiveContext::Concerns::CodePostProcessing

        feature_category :global_search
        urgency :low

        allow_access_with_scope :ai_workflows, if: ->(request) { request.get? || request.head? }
        allow_mcp_access_read

        before do
          authenticate!
          check_rate_limit!(
            :semantic_search_rate_limit,
            scope: [current_user]
          )
        end

        rescue_from ::Ai::ActiveContext::Queries::Code::NotAvailable do
          not_found!('Semantic code search is not available')
        end

        resource :projects, requirements: ::API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
          route_setting :lifecycle, :beta
          route_setting :authorization, permissions: :read_code, boundary_type: :project
          route_setting :mcp,
            tool_name: :semantic_code_search,
            params: [:id, :q, :directory_path, :knn, :limit],
            annotations: { readOnlyHint: true },
            resource_name: "project"
          desc 'Search project code using natural language' do
            detail <<~DETAIL
              Introduced in GitLab 18.11.

              Searches indexed project code using semantic (meaning-based) similarity rather than
              keyword matching. Use this when you do not know the exact symbol or file name, or
              to discover how a behavior is implemented across the codebase.

              Primary use cases:
              - When you do not know the exact symbol or file path
              - To see how a behavior or feature is implemented across the codebase
              - To discover related implementations (clients, jobs, workers)

              How to use:
              - Provide a concise, specific query with concrete keywords
              - Use directory_path to narrow scope (e.g. "app/services/")
              - Prefer precise intent over broad terms

              Results are grouped by file. Each file includes merged line ranges with content
              and a relevance score (0.0-1.0). The response includes an overall confidence
              level (high/medium/low/unknown) based on score distribution. Results are
              filtered by Duo context exclusion settings.

              Requires semantic code search to be enabled and indexed for the project namespace.
            DETAIL
            tags %w[search]
            success code: 200, model: ::API::Entities::Ai::SemanticCode::Response
            failure [
              { code: 401, message: 'Unauthorized' },
              { code: 403, message: 'Forbidden' },
              { code: 404, message: 'Not found - project not found or semantic code search unavailable' },
              { code: 422, message: 'Unprocessable entity - project has no embeddings' },
              { code: 429, message: 'Too many requests' }
            ]
          end
          params do
            requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the project'
            requires :q, type: String, limit: 1000, allow_blank: false,
              desc: 'Natural language search query (e.g. "authentication middleware", "rate limiting logic")'
            optional :directory_path, type: String, limit: 100,
              desc: 'Restrict search to files under this directory path (e.g. "app/services/"). ' \
                'Must be a relative path — no leading slash, no .. segments.'
            optional :knn, type: Integer, values: 1..100,
              default: ::Ai::ActiveContext::Queries::Code::KNN_COUNT,
              desc: 'Number of nearest neighbours to retrieve internally ' \
                "(default: #{::Ai::ActiveContext::Queries::Code::KNN_COUNT}). " \
                'Higher values improve recall at the cost of latency.'
            optional :limit, type: Integer, values: 1..100,
              default: ::Ai::ActiveContext::Queries::Code::SEARCH_RESULTS_LIMIT,
              desc: 'Maximum number of results to return ' \
                "(default: #{::Ai::ActiveContext::Queries::Code::SEARCH_RESULTS_LIMIT})."
          end
          get ':id/(-/)search/semantic' do
            authorize! :read_code, user_project

            dir_path = params[:directory_path]
            if dir_path && (dir_path.start_with?('/') || dir_path.split('/').include?('..'))
              bad_request!('directory_path must not start with / or contain .. segments')
            end

            result = ::Ai::ActiveContext::Queries::Code
              .new(search_term: params[:q], user: current_user)
              .filter(
                project_or_id: user_project,
                path: params[:directory_path],
                knn_count: params[:knn],
                limit: params[:limit],
                exclude_fields: %w[id source type embeddings_v1 reindexing],
                extract_source_segments: true,
                build_file_url: true
              )

            unless result.success?
              unprocessable_entity!(
                result.error_message(target_class: 'Project', target_id: user_project.id)
              )
            end

            ::Gitlab::InternalEvents.track_event(
              'search_code_with_semantic_search',
              user: current_user,
              project: user_project,
              namespace: user_project.root_namespace
            )

            filtered = filter_excluded_results(result.to_a, user_project)
            grouped  = group_results_by_file(filtered)
            confidence = compute_confidence_level(extract_scores(filtered))

            present(
              { confidence: confidence.to_s, results: grouped },
              with: ::API::Entities::Ai::SemanticCode::Response
            )
          end
        end
      end
    end
  end
end
