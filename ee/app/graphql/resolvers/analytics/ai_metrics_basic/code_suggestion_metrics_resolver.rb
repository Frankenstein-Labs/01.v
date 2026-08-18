# frozen_string_literal: true

module Resolvers
  module Analytics
    module AiMetricsBasic
      class CodeSuggestionMetricsResolver < BaseResolver
        include LooksAhead

        type ::Types::Analytics::AiMetricsBasic::CodeSuggestionMetricsType, null: true

        def resolve_with_lookahead
          usage = ::Analytics::AiAnalytics::Postgresql::CodeSuggestionUsageService.new(
            namespace: context[:ai_metrics_namespace],
            from: context[:ai_metrics_params][:start_date],
            to: context[:ai_metrics_params][:end_date],
            fields: selected_fields
          ).execute

          return unless usage.success?

          usage.payload
        end

        private

        def selected_fields
          lookahead.selections.map(&:name)
        end
      end
    end
  end
end
