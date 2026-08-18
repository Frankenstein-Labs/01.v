# frozen_string_literal: true

module Elastic
  module Latest
    class MilestoneClassProxy < ApplicationClassProxy
      def elastic_search(query, options: {})
        query_hash = ::Search::Elastic::MilestoneQueryBuilder.build(query: query, options: options)

        search(query_hash, options)
      end

      def preload_indexing_data(relation)
        relation.preload_for_indexing
      end
    end
  end
end
