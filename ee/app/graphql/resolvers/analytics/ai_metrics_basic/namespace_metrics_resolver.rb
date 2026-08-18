# frozen_string_literal: true

module Resolvers
  module Analytics
    module AiMetricsBasic
      # rubocop:disable Graphql/ResolverType -- false positive
      class NamespaceMetricsResolver < ::Resolvers::Analytics::AiMetrics::NamespaceMetricsResolver
        type ::Types::Analytics::AiMetricsBasic::NamespaceMetricsType, null: true
      end
      # rubocop:enable Graphql/ResolverType
    end
  end
end
