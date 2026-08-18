# frozen_string_literal: true

module Analytics
  module AiAnalytics
    class CodeSuggestionUsageService
      include CommonUsageService

      QUERY = <<~SQL
        SELECT %{fields}
      SQL

      CODE_CONTRIBUTORS_COUNT_QUERY = <<~SQL
        SELECT COUNT(DISTINCT author_id)
        FROM "contributions"
        WHERE startsWith(path, {traversal_path:String})
        AND "contributions"."created_at" >= {from:Date}
        AND "contributions"."created_at" <= {to:Date}
        AND "contributions"."action" = 5
      SQL
      private_constant :CODE_CONTRIBUTORS_COUNT_QUERY

      code_suggestion_usage_events = ::Ai::UsageEvent.events.values_at(
        'code_suggestions_requested',
        'code_suggestion_shown_in_ide',
        'code_suggestion_direct_access_token_refresh'
      ).join(', ')

      # Can be removed with deprecated fields from GraphQL aiMetrics endpoint
      # more information at https://gitlab.com/gitlab-org/gitlab/-/issues/536606
      CODE_SUGGESTIONS_CONTRIBUTORS_COUNT_QUERY = <<~SQL.freeze
        SELECT COUNT(DISTINCT user_id)
          FROM code_suggestion_events_daily
          WHERE startsWith(namespace_path, {traversal_path:String})
          AND date >= {from:Date}
          AND date <= {to:Date}
          AND event IN (#{code_suggestion_usage_events})
      SQL
      private_constant :CODE_SUGGESTIONS_CONTRIBUTORS_COUNT_QUERY

      # Can be removed with deprecated fields from GraphQL aiMetrics endpoint
      # more information at https://gitlab.com/gitlab-org/gitlab/-/issues/536606
      CODE_SUGGESTIONS_SHOWN_COUNT_QUERY = <<~SQL.freeze
        SELECT SUM(occurrences)
        FROM code_suggestion_events_daily
        WHERE startsWith(namespace_path, {traversal_path:String})
        AND date >= {from:Date}
        AND date <= {to:Date}
        AND event = #{::Ai::UsageEvent.events['code_suggestion_shown_in_ide']}
      SQL
      private_constant :CODE_SUGGESTIONS_SHOWN_COUNT_QUERY

      # Can be removed with deprecated fields from GraphQL aiMetrics endpoint
      # more information at https://gitlab.com/gitlab-org/gitlab/-/issues/536606
      CODE_SUGGESTIONS_ACCEPTED_COUNT_QUERY = <<~SQL.freeze
        SELECT SUM(occurrences)
        FROM code_suggestion_events_daily
        WHERE startsWith(namespace_path, {traversal_path:String})
        AND date >= {from:Date}
        AND date <= {to:Date}
        AND event = #{::Ai::UsageEvent.events['code_suggestion_accepted_in_ide']}
      SQL
      private_constant :CODE_SUGGESTIONS_ACCEPTED_COUNT_QUERY

      private_class_method def self.build_query(field_select_sql:, event_types_filter:)
        <<~SQL.freeze
          SELECT #{field_select_sql}
          FROM code_suggestion_events_daily
          WHERE startsWith(namespace_path, {traversal_path:String})
          AND date >= {from:Date}
          AND date <= {to:Date}
          AND event IN (#{event_types_filter})
          AND (
            length({languages:Array(String)}) = 0
            OR language IN {languages:Array(String)}
          )
          AND (
            length({ide_names:Array(String)}) = 0
            OR ide_name IN {ide_names:Array(String)}
          )
        SQL
      end

      CONTRIBUTORS_COUNT_QUERY = build_query(
        field_select_sql: 'COUNT(DISTINCT user_id)',
        event_types_filter: code_suggestion_usage_events
      ).freeze
      private_constant :CONTRIBUTORS_COUNT_QUERY

      SHOWN_COUNT_QUERY = build_query(
        field_select_sql: 'SUM(occurrences)',
        event_types_filter: ::Ai::UsageEvent.events['code_suggestion_shown_in_ide']
      ).freeze
      private_constant :SHOWN_COUNT_QUERY

      SUGGESTIONS_SHOWN_LOC_QUERY = build_query(
        field_select_sql: 'SUM(suggestions_size_sum)',
        event_types_filter: ::Ai::UsageEvent.events['code_suggestion_shown_in_ide']
      ).freeze
      private_constant :SUGGESTIONS_SHOWN_LOC_QUERY

      ACCEPTED_COUNT_QUERY = build_query(
        field_select_sql: 'SUM(occurrences)',
        event_types_filter: ::Ai::UsageEvent.events['code_suggestion_accepted_in_ide']
      ).freeze
      private_constant :ACCEPTED_COUNT_QUERY

      SUGGESTIONS_ACCEPTED_LOC_QUERY = build_query(
        field_select_sql: 'SUM(suggestions_size_sum)',
        event_types_filter: ::Ai::UsageEvent.events['code_suggestion_accepted_in_ide']
      ).freeze
      private_constant :SUGGESTIONS_ACCEPTED_LOC_QUERY

      LANGUAGES_QUERY = build_query(
        field_select_sql: 'groupArray(DISTINCT language)',
        event_types_filter: [
          ::Ai::UsageEvent.events['code_suggestion_accepted_in_ide'],
          ::Ai::UsageEvent.events['code_suggestion_shown_in_ide']
        ]
      ).freeze
      private_constant :LANGUAGES_QUERY

      IDE_NAMES_QUERY = build_query(
        field_select_sql: 'groupArray(DISTINCT ide_name)',
        event_types_filter: [
          ::Ai::UsageEvent.events['code_suggestion_accepted_in_ide'],
          ::Ai::UsageEvent.events['code_suggestion_shown_in_ide']
        ]
      ).freeze
      private_constant :IDE_NAMES_QUERY

      FIELDS_SUBQUERIES = {
        # Legacy queries, can be removed with deprecated fields from GraphQL aiMetrics endpoint
        code_contributors_count: CODE_CONTRIBUTORS_COUNT_QUERY,
        code_suggestions_contributors_count: CODE_SUGGESTIONS_CONTRIBUTORS_COUNT_QUERY,
        code_suggestions_shown_count: CODE_SUGGESTIONS_SHOWN_COUNT_QUERY,
        code_suggestions_accepted_count: CODE_SUGGESTIONS_ACCEPTED_COUNT_QUERY,
        # New queries
        contributors_count: CONTRIBUTORS_COUNT_QUERY,
        shown_count: SHOWN_COUNT_QUERY,
        accepted_count: ACCEPTED_COUNT_QUERY,
        ide_names: IDE_NAMES_QUERY,
        languages: LANGUAGES_QUERY,
        shown_lines_of_code: SUGGESTIONS_SHOWN_LOC_QUERY,
        accepted_lines_of_code: SUGGESTIONS_ACCEPTED_LOC_QUERY
      }.freeze

      FIELDS = FIELDS_SUBQUERIES.keys

      attr_reader :languages, :ide_names

      def initialize(current_user, namespace:, from:, to:, languages: [], ide_names: [], fields: nil)
        @languages = languages || []
        @ide_names = ide_names || []
        super(current_user, namespace:, from:, to:, fields:)
      end

      private

      def placeholders
        super.merge(
          languages: languages,
          ide_names: ide_names
        )
      end
    end
  end
end
