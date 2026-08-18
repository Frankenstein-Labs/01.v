# frozen_string_literal: true

module Search
  module Zoekt
    class Params
      UNLIMITED = 0
      LINE_MATCHES_FACTOR = 10

      def initialize(options)
        @options = options
      end

      def max_file_match_window
        UNLIMITED
      end

      def max_file_match_results
        return search_limit if multi_match?
        return UNLIMITED unless use_offset_pagination?

        # For pages 1-MAX_PAGES: batch fetch all pages at once (cache-friendly).
        # For pages beyond MAX_PAGES: fetch only the single requested page.
        current_page > ::Search::Zoekt::Cache::MAX_PAGES ? per_page : ::Search::Zoekt::Cache::MAX_PAGES * per_page
      end

      def file_match_offset
        return 0 unless use_offset_pagination?
        return 0 if multi_match?
        return 0 if current_page <= ::Search::Zoekt::Cache::MAX_PAGES

        (current_page - 1) * per_page
      end

      def max_line_match_window
        ::Search::Zoekt::SearchResults::ZOEKT_COUNT_LIMIT
      end

      def max_line_match_results
        multi_match? ? UNLIMITED : search_limit
      end

      def max_line_match_results_per_file
        # Aggregation-only requests need untruncated per-file counts so language buckets add up to
        # the true total. Bumping to ZOEKT_COUNT_LIMIT effectively removes the per-file cap while
        # keeping the same absolute upper bound as the global line-match window.
        return ::Search::Zoekt::SearchResults::ZOEKT_COUNT_LIMIT if options[:aggregation_mode] == true

        (multi_match? ? options[:multi_match].max_chunks_size : MultiMatch::MAX_CHUNKS_PER_FILE) * LINE_MATCHES_FACTOR
      end

      private

      attr_reader :options

      def search_limit
        options.fetch(:limit)
      end

      def current_page
        options.fetch(:page, 1).to_i
      end

      def per_page
        options.fetch(:per_page, ::Search::Zoekt::SearchResults::DEFAULT_PER_PAGE).to_i
      end

      def multi_match?
        options[:multi_match].present?
      end

      def use_offset_pagination?
        ::Search::Zoekt::OffsetPagination.active?
      end
    end
  end
end
