# frozen_string_literal: true

module Analytics
  module AiAnalytics
    class DuoChatUsageService
      include CommonUsageService
      include Gitlab::Utils::StrongMemoize

      # TODO - Replace with namespace_traversal_path filter
      # after https://gitlab.com/gitlab-org/gitlab/-/issues/531491
      QUERY = <<~SQL
        -- cte to load code contributors
        WITH contributors AS (
          SELECT DISTINCT author_id
          FROM "contributions"
          WHERE startsWith(path, {traversal_path:String})
          AND "contributions"."created_at" >= {from:Date}
          AND "contributions"."created_at" <= {to:Date}
        )
        SELECT %{fields}
      SQL

      NEW_QUERY = <<~SQL
        -- cte to load contributors
        WITH contributors AS (
          SELECT DISTINCT author_id
          FROM (
            SELECT
              argMax(author_id, "contributions_new".version) AS author_id,
              argMax(deleted, "contributions_new".version) AS deleted
            FROM contributions_new
            WHERE startsWith(path, {traversal_path:String})
            AND "contributions_new"."created_at" >= {from:Date}
            AND "contributions_new"."created_at" <= {to:Date}
            GROUP BY id
          ) contributions_new
          WHERE deleted = false
        )
        SELECT %{fields}
      SQL

      CONTRIBUTORS_COUNT_QUERY = "SELECT count(*) FROM contributors"
      private_constant :CONTRIBUTORS_COUNT_QUERY

      DUO_CHAT_CONTRIBUTORS_COUNT_QUERY = <<~SQL.freeze
        SELECT COUNT(DISTINCT user_id)
          FROM duo_chat_events_daily
          WHERE user_id IN (SELECT author_id FROM contributors)
          AND date >= {from:Date}
          AND date <= {to:Date}
          AND event = #{Ai::UsageEvent.events[:request_duo_chat_response]}
      SQL
      private_constant :DUO_CHAT_CONTRIBUTORS_COUNT_QUERY

      FIELDS_SUBQUERIES = {
        contributors_count: CONTRIBUTORS_COUNT_QUERY,
        duo_chat_contributors_count: DUO_CHAT_CONTRIBUTORS_COUNT_QUERY
      }.freeze

      FIELDS = FIELDS_SUBQUERIES.keys

      CONTRIBUTORS_FILTER_REGEX_PATTERN = /where user_id in \(select author_id from contributors\)/i
      NAMESPACE_PATH_FILTER = 'WHERE startsWith(namespace_path, {traversal_path:String})'

      def filter_by_namespace_path_enabled?
        # for Duo Chat we don't want to use the namespace filter. See https://gitlab.com/gitlab-org/gitlab/-/issues/578538
        Feature.enabled?(:use_duo_chat_namespace_path_filter, namespace)
      end

      private

      def placeholders
        {
          traversal_path: namespace.traversal_path(with_organization: fetch_contributions_from_new_table?),
          from: from.to_date.iso8601,
          to: to.to_date.iso8601
        }
      end

      def raw_query
        raw_fields = fields.map do |field|
          "(#{self.class::FIELDS_SUBQUERIES[field]}) as #{field}"
        end.join(',')

        query = format(base_query, fields: raw_fields)
        filter_by_namespace_path_enabled? ? replace_contributors_filter(query) : query
      end

      def base_query
        fetch_contributions_from_new_table? ? NEW_QUERY : QUERY
      end

      def replace_contributors_filter(old_query)
        old_query.gsub(CONTRIBUTORS_FILTER_REGEX_PATTERN, NAMESPACE_PATH_FILTER)
      end

      def fetch_contributions_from_new_table?
        Feature.enabled?(:fetch_contributions_data_from_new_tables, namespace)
      end
      strong_memoize_attr :fetch_contributions_from_new_table?
    end
  end
end
