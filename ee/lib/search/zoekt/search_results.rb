# frozen_string_literal: true

module Search
  module Zoekt
    class SearchResults
      include ActionView::Helpers::NumberHelper
      include Gitlab::Utils::StrongMemoize
      include Gitlab::Loggable
      include Search::Zoekt::ResponseParser

      ZOEKT_COUNT_LIMIT = 5_000
      DEFAULT_PER_PAGE = Gitlab::SearchResults::DEFAULT_PER_PAGE
      ZOEKT_TARGETS_CACHE_EXPIRES_IN = 10.minutes
      LANGUAGE_AGGREGATION_NAME = 'language'

      attr_accessor :file_count

      def initialize(current_user, query, projects = nil, **options)
        if options[:search_level].present?
          raise 'Specifying search level is not supported. Pass group_id or project_id instead.'
        end

        @current_user = current_user
        @query = query
        @source = options[:source]&.to_sym
        @filters = options.fetch(:filters, {}.with_indifferent_access)
        @filters[:exclude_forks] = false if @filters[:exclude_forks].nil? && source != :api
        @projects = filtered_projects(projects)
        @node_id = options[:node_id]
        @modes = options.fetch(:modes, {})
        @multi_match = MultiMatch.new(options[:chunk_count]) unless source == :api
        @options = options
      end

      def limit_project_ids
        @limit_project_ids ||= projects.pluck_primary_key
      end

      def objects(_scope = 'blobs', page: 1, per_page: DEFAULT_PER_PAGE, preload_method: nil)
        @blobs, @file_count = blobs_and_file_count(page: page, per_page: per_page, preload_method: preload_method)
        @blobs
      end

      def formatted_count(_scope = 'blobs')
        limited_counter_with_delimiter(blobs_count)
      end

      def blobs_count
        @blobs_count ||= @blobs&.total_count || blobs_and_file_count(count_only: true)[0].total_count
      end

      # These aliases act as an adapter to the Gitlab::SearchResults
      # interface, which is mostly implemented by this class.
      alias_method :limited_blobs_count, :blobs_count

      # Serving path:
      #   1. Cache hit  -> return buckets immediately, no Zoekt call.
      #   2. Cache miss -> issue a dedicated aggregation-mode Zoekt call (language filter stripped, per-file
      #      line-match cap lifted) and cache its untruncated tally. Amortised by the AggregationCache TTL,
      #      so subsequent renders reuse the cached buckets.
      def aggregations(scope)
        return [] unless scope.to_s == 'blobs'
        return [] unless language_aggregations_enabled?

        buckets = language_aggregation_buckets
        return [] if buckets.empty?

        [::Gitlab::Search::Aggregation.new(LANGUAGE_AGGREGATION_NAME, buckets)]
      end

      def parse_zoekt_search_result(result, project)
        ref = project.default_branch_or_main
        return multi_match.blobs_for_project(result, project, ref) if multi_match

        path = result[:path]
        basename = File.join(File.dirname(path), File.basename(path, '.*'))
        content = result[:content]
        project_id = project.id

        ::Gitlab::Search::FoundBlob.new(
          path: path,
          basename: basename,
          ref: ref,
          startline: [result[:line] - 1, 0].max,
          highlight_line: result[:line],
          data: content,
          project: project,
          project_id: project_id
        )
      end

      def failed?(*)
        error.present?
      end

      def error(*)
        error_message
      end

      def server_error?
        is_server_error.present?
      end

      attr_reader :error_type

      private

      attr_reader :current_user, :query, :filters, :modes, :source, :projects, :node_id, :multi_match, :options,
        :error_message, :is_server_error

      def blobs_and_file_count(page: 1, per_page: DEFAULT_PER_PAGE, count_only: false, preload_method: nil)
        if empty_results_preflight_check?
          empty_results = Search::EmptySearchResults.new
          return empty_results.objects, empty_results.file_count
        end

        strong_memoize(memoize_key(:blobs_and_file_count, page: page, per_page: per_page, count_only: count_only)) do
          search_as_found_blob(
            query,
            count_only: count_only,
            page: (page || 1).to_i,
            per_page: per_page,
            preload_method: preload_method
          )
        end
      end

      def memoize_key(scope, page:, per_page:, count_only:)
        count_only ? :"#{scope}_results_count" : :"#{scope}_#{page}_#{per_page}"
      end

      def limited_counter_with_delimiter(count)
        if count.nil?
          number_with_delimiter(0)
        elsif count >= ZOEKT_COUNT_LIMIT
          "#{number_with_delimiter(ZOEKT_COUNT_LIMIT)}+"
        else
          number_with_delimiter(count)
        end
      end

      def search_as_found_blob(query, count_only:, page:, per_page:, preload_method:)
        zoekt_search_and_wrap(
          query,
          page: page,
          count_only: count_only,
          per_page: per_page,
          preload_method: preload_method
        ) do |result, project|
          parse_zoekt_search_result(result, project)
        end
      end

      # Performs zoekt search and parses the response
      #
      # @param query [String] search query
      # @param per_page [Integer] how many documents per page
      # @param options [Hash] additional options
      # @param page_limit [Integer] maximum number of pages we parse
      # @return [Array<Hash, Integer>] the results and total count
      def zoekt_search(query, count_only:, page:, per_page:, page_limit:)
        response = ::Gitlab::Search::Zoekt::Client.search(
          query,
          num: ZOEKT_COUNT_LIMIT,
          search_mode: search_mode,
          current_user: current_user,
          targets: use_traversal_id_queries? ? nil : zoekt_targets,
          multi_match: multi_match,
          page: page,
          per_page: per_page,
          **options
        )

        if response.failure?
          @blobs_count = 0
          @error_message = response.error_message
          @error_type = ::Search::Zoekt::Errors::BaseError
          @is_server_error = response.server_error?
          return [{}, @blobs_count, 0]
        end

        total_count = response.match_count.clamp(0, ZOEKT_COUNT_LIMIT)

        return [{}, total_count, 0] if count_only

        results = zoekt_extract_result_pages(response, per_page: per_page, page_limit: page_limit)
        [results, total_count, response.file_count]
      rescue ::Search::Zoekt::Errors::ClientConnectionError => e
        @is_server_error = true
        @blobs_count = 0
        @error_message = e.message
        @error_type = e.class
        [{}, @blobs_count, 0]
      end

      def aggregation_cache
        @aggregation_cache ||= ::Search::Zoekt::AggregationCache.new(
          query,
          current_user: current_user,
          filters: filters,
          group_id: options[:group_id],
          project_id: options[:project_id],
          search_mode: search_mode
        )
      end

      # Tallies match counts per language. Must only be called on a response from a Zoekt request issued
      # with `aggregation_mode: true`, which lifts the per-file line-match cap so `line_matches.size` is
      # the untruncated total. Files with no detected language are skipped.
      def tally_language_matches(response)
        tally = Hash.new(0)

        response.each_file do |file|
          language = file[:Language].presence
          next unless language

          line_matches = file[:LineMatches] || []
          tally[language] += line_matches.size if line_matches.any?
        end

        tally
      end

      def language_aggregations_enabled?
        ::Feature.enabled?(:zoekt_language_aggregations, current_user)
      end
      strong_memoize_attr :language_aggregations_enabled?

      def language_aggregation_buckets
        tally = aggregation_cache.read
        tally ||= fetch_language_tally

        return [] if tally.blank?

        tally.sort_by { |_, count| -count }.map { |lang, count| { 'key' => lang, 'doc_count' => count } }
      end

      # On cache miss, issue a dedicated aggregation-mode Zoekt call. The display query cannot warm the
      # cache because it caps line matches per file (see Params#max_line_match_results_per_file), so a
      # tally derived from it would undercount any file with more than max_chunks_size * 10 matches.
      # aggregation_mode: true lifts that cap, and stripping :language keeps bucket counts stable across
      # language ticks.
      def fetch_language_tally
        aggregation_options = options.merge(
          filters: filters.except(:language, 'language'),
          page: 1,
          per_page: DEFAULT_PER_PAGE,
          aggregation_mode: true
        )

        response = ::Gitlab::Search::Zoekt::Client.search(
          query,
          num: ZOEKT_COUNT_LIMIT,
          search_mode: search_mode,
          current_user: current_user,
          targets: use_traversal_id_queries? ? nil : zoekt_targets,
          multi_match: multi_match,
          **aggregation_options
        )

        return {} if response.failure?

        tally = tally_language_matches(response)
        aggregation_cache.write(tally)
        tally
      end

      # Extracts results from the Zoekt response
      #
      # @param response [Hash] JSON response converted to hash
      # @param per_page [Integer] how many documents per page
      # @param page_limit [Integer] maximum number of pages we parse
      # @return [Hash<Integer, Array<Hash>>] results hash with pages as keys (zero-based)
      def zoekt_extract_result_pages(response, per_page:, page_limit:)
        return multi_match.zoekt_extract_result_pages_multi_match(response, per_page, page_limit) if multi_match

        results = {}
        page = 0
        response.each_file do |file|
          project_id = extract_project_id(file)

          if file[:LineMatches].nil?
            parsed_response = response.parsed_response
            logger.error(
              build_structured_payload(
                message: 'LineMatches is missing',
                error: parsed_response[:Error],
                failures: parsed_response[:Failures],
                timed_out: parsed_response[:TimedOut],
                file: file
              )
            )
          end

          file[:LineMatches].each do |match|
            current_page = page / per_page
            break if current_page == page_limit

            results[current_page] ||= []
            results[current_page] << build_result(file, match, project_id)
            page += 1
          end

          break if page / per_page == page_limit
        end

        results
      end

      def build_result(file, match, project_id)
        {
          project_id: project_id,
          content: decode_content(match),
          line: match[:LineNumber],
          path: file[:FileName]
        }
      end

      def decode_content(match)
        [:Before, :Line, :After].filter_map do |part|
          Base64.decode64(match[part]) if match[part]
        end.join
      end

      def zoekt_search_and_wrap(query, per_page:, count_only:, page: 1, preload_method: nil, &blk)
        zoekt_cache = ::Search::Zoekt::Cache.new(
          query,
          current_user: current_user,
          page: page,
          per_page: per_page,
          project_id: options[:project_id],
          group_id: options[:group_id],
          max_per_page: DEFAULT_PER_PAGE * 2,
          search_mode: search_mode,
          filters: filters,
          chunk_size: multi_match&.max_chunks_size,
          count_only: count_only
        )

        search_results, total_count, file_count = zoekt_cache.fetch do |page_limit|
          zoekt_search(query, count_only: count_only, page: page, per_page: per_page, page_limit: page_limit)
        end

        result_page_index = result_page_index_for(page)

        items, total_count = yield_each_zoekt_search_result(
          search_results[result_page_index],
          preload_method,
          total_count,
          &blk
        )

        offset = (page - 1) * per_page
        [Kaminari.paginate_array(items, total_count: total_count, limit: per_page, offset: offset), file_count]
      end

      def yield_each_zoekt_search_result(response, preload_method, total_count)
        return [[], total_count] if total_count == 0 || response.blank?

        project_ids = response.pluck(:project_id).uniq # rubocop:disable CodeReuse/ActiveRecord -- Array#pluck
        projects = Project.id_in(project_ids).include_project_feature.inc_routes
        projects = projects.public_send(preload_method) if preload_method # rubocop:disable GitlabSecurity/PublicSend -- Method calls are forwarded
        projects = projects.index_by(&:id)

        items = response.map do |result|
          project_id = result[:project_id]
          project = projects[project_id]

          if project.nil? || project.pending_delete?
            total_count -= multi_match ? result[:match_count_total] : 1

            next
          end

          yield(result, project)
        end

        # Remove results for deleted projects
        items.compact!

        [items, [total_count, 0].max] # count can never be lower than 0
      end

      def search_mode
        return :regex if modes[:regex].nil? && source == :api

        Gitlab::Utils.to_boolean(modes[:regex]) ? :regex : :exact
      end

      def filtered_projects(projects)
        return Project.none if projects.blank?
        return Project.all if projects == :any

        filtered_projects = projects.without_order
        filtered_projects = filtered_projects.self_and_ancestors_non_archived unless filters[:include_archived]

        # default behavior is to exclude forks
        if filters[:exclude_forks].nil? || (filters[:exclude_forks] == true)
          filtered_projects = filtered_projects.not_a_fork
        end

        Project.filter_out_public_projects_with_unauthorized_private_repos(filtered_projects, current_user)
      end

      def zoekt_targets
        sha = OpenSSL::Digest.hexdigest('SHA256', limit_project_ids.sort.join(','))
        cache_key = [self.class.name, :zoekt_targets, current_user&.id, sha]

        Rails.cache.fetch(cache_key, expires_in: ZOEKT_TARGETS_CACHE_EXPIRES_IN) do
          ::Search::Zoekt::RoutingService.execute(projects)
        end
      end

      def empty_results_preflight_check?
        return true if query.blank? || (!use_traversal_id_queries? && limit_project_ids.empty?)

        if node_id.nil? && search_level == :project
          project = Project.find_by_id(options[:project_id])

          # Trigger async indexing if repository exists and isn't empty
          unless project&.empty_repo?
            logger.info(build_structured_payload(
              message: 'zoekt repository is not found for this search',
              project_id: project&.id,
              query: query
            ))
            Search::Zoekt.index_async(project&.id)
          end

          return true
        end

        false
      end

      # When offset pagination is active and we're beyond the cache window, Zoekt returns
      # only the requested page slice starting at index 0. Otherwise, results are batched
      # and stored by page index as usual.
      def result_page_index_for(page)
        page > ::Search::Zoekt::Cache::MAX_PAGES && ::Search::Zoekt::OffsetPagination.active? ? 0 : page - 1
      end

      def use_traversal_id_queries?
        ::Search::Zoekt.feature_available?(
          :traversal_id_search, current_user, group_id: options[:group_id], project_id: options[:project_id]
        )
      end

      def logger
        @logger ||= ::Search::Zoekt::Logger.build
      end

      def search_level
        @search_level ||= if options[:group_id].present?
                            :group
                          elsif options[:project_id].present?
                            :project
                          else
                            :global
                          end
      end
    end
  end
end
