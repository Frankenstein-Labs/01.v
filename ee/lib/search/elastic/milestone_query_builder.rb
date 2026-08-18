# frozen_string_literal: true

module Search
  module Elastic
    class MilestoneQueryBuilder < QueryBuilder
      extend ::Gitlab::Utils::Override

      DOC_TYPE = 'milestone'
      FIELDS = %w[title^2 description].freeze

      QUERY_COMPONENTS = {
        ::Search::Elastic::Filters => [
          :by_type,
          :by_search_level_and_membership,
          :by_archived
        ],
        ::Search::Elastic::Formats => %i[source_fields size]
      }.freeze

      private

      override :extra_options
      def extra_options
        {
          doc_type: DOC_TYPE,
          features: [:issues, :merge_requests]
        }
      end

      override :prepare_options
      def prepare_options
        options[:fields] = options[:fields].presence || FIELDS
      end

      override :build_initial_query_hash
      def build_initial_query_hash
        ::Search::Elastic::Queries.by_full_text(query: query, options: options)
      end
    end
  end
end
