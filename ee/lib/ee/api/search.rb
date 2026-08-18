# frozen_string_literal: true

module EE
  module API
    module Search
      ADVANCED_SEARCH_TYPE = 'advanced'
      EXACT_CODE_SEARCH_TYPE = 'zoekt'
      ADVANCED_SEARCH_SCOPES = %w[blobs commits notes wiki_blobs].freeze
      FIELDS_SUPPORTED_SCOPES = %w[issues merge_requests].freeze
      BLOB_SEARCH_TYPES = %W[#{ADVANCED_SEARCH_TYPE} #{EXACT_CODE_SEARCH_TYPE}].freeze
      BLOB_SEARCH_PARAM_RULES = {
        regex:
          { valid_types: %W[#{EXACT_CODE_SEARCH_TYPE}],
            message: 'regex supported only with exact code search' },
        exclude_forks:
          { valid_types: %W[#{EXACT_CODE_SEARCH_TYPE}],
            message: 'exclude_forks supported only with exact code search' },
        num_context_lines:
          { valid_types: BLOB_SEARCH_TYPES,
            message: 'num_context_lines supported only with advanced and exact code search' }
      }.freeze

      extend ActiveSupport::Concern

      prepended do
        helpers do
          include ::API::Helpers::SearchHelpers
          include Helpers::McpHelpers
          extend ::Gitlab::Utils::Override

          params :ee_param_fields do
            optional :fields, type: Array[String], coerce_with: ::API::Validations::Types::CommaSeparatedToArray.coerce,
              values: %w[title], desc: 'Array of fields you wish to search. Available with advanced search.'
          end

          params :ee_param_exclude_forks do
            optional :exclude_forks, type: Grape::API::Boolean,
              desc: 'Excludes forked projects in the search. Available with exact code search. Introduced in GitLab 18.9.' # rubocop:disable Layout/LineLength,Lint/RedundantCopDisableDirective -- keep readability
          end

          params :ee_param_num_context_lines do
            optional :num_context_lines, type: Integer,
              values: 0..::Gitlab::Elastic::SearchResults::MAX_NUM_CONTEXT_LINES,
              desc: 'Number of context lines around each match. Available with advanced and exact code search. Introduced in GitLab 18.11.' # rubocop:disable Layout/LineLength,Lint/RedundantCopDisableDirective -- keep readability
          end

          params :ee_param_regex do
            optional :regex, type: Grape::API::Boolean,
              desc: 'Performs a regex code search. Available with exact code search. Introduced in GitLab 18.9'
          end

          override :search
          def search(additional_params = {})
            # For MCP requests, gracefully return empty results when all types unavailable
            # For non-MCP requests, fall through to CE which returns bad_request
            return Kaminari.paginate_array([]) if unavailable_work_item_types? && mcp_request?

            super
          rescue ::Gitlab::Search::Client::ConnectionError, ::Gitlab::Search::Client::AuthorizationError => e
            render_api_error!(e.message, 503)
          end

          override :scope_preload_method
          def scope_preload_method
            super.merge(blobs: :with_api_blob_entity_associations).freeze
          end

          # do not use this method for project search API
          # all search scopes allowed for project level search
          override :verify_search_scope_for_ee!
          def verify_search_scope_for_ee!(search_type)
            scope = user_requested_search_scope
            return if scope == 'blobs' && BLOB_SEARCH_TYPES.include?(search_type)
            return if ADVANCED_SEARCH_SCOPES.exclude?(scope) || search_type == ADVANCED_SEARCH_TYPE

            render_api_error!(scope_error_message(scope), 400)
          end

          def scope_error_message(scope)
            return 'Scope supported only with advanced search or exact code search' if scope == 'blobs'

            'Scope supported only with advanced search'
          end

          override :verify_ee_blob_search_params!
          def verify_ee_blob_search_params!(search_type)
            return if mcp_request?

            BLOB_SEARCH_PARAM_RULES.each do |param, rule|
              next unless params.key?(param)
              next if rule[:valid_types].include?(search_type)

              render_api_error!(rule[:message], 400)
            end
          end

          override :verify_ee_param_fields!
          def verify_ee_param_fields!(search_type)
            return unless params.key?(:fields)
            return if mcp_request?

            if FIELDS_SUPPORTED_SCOPES.exclude?(user_requested_search_scope)
              render_api_error!("fields is supported only for #{FIELDS_SUPPORTED_SCOPES.join(', ')}", 400)
            end

            return if search_type == ADVANCED_SEARCH_TYPE

            render_api_error!("fields is supported only for #{ADVANCED_SEARCH_TYPE} search", 400)
          end
        end
      end
    end
  end
end
