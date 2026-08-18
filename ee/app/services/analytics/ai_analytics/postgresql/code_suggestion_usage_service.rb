# frozen_string_literal: true

module Analytics
  module AiAnalytics
    module Postgresql
      class CodeSuggestionUsageService
        FIELD_TO_ENUM_MAP = {
          shown_count: Ai::EventsCount.events[:code_suggestion_shown_in_ide],
          accepted_count: Ai::EventsCount.events[:code_suggestion_accepted_in_ide]
        }.freeze

        FIELDS = FIELD_TO_ENUM_MAP.keys.freeze

        def initialize(namespace:, from:, to:, fields:)
          @namespace = namespace
          @from = from
          @to = to
          @fields = fields
          @payload = {}
        end

        def execute
          return ServiceResponse.success(payload: payload) unless fields.present?

          fields.each do |field|
            payload[field] = event_count_for(field)
          end

          ServiceResponse.success(payload:)
        end

        private

        attr_reader :namespace, :from, :to, :fields, :payload

        def event_count_for(field)
          Ai::EventsCount.total_occurrences_for(
            namespace: namespace,
            event: FIELD_TO_ENUM_MAP[field],
            from: from,
            to: to
          )
        end
      end
    end
  end
end
