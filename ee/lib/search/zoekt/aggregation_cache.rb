# frozen_string_literal: true

module Search
  module Zoekt
    # Redis cache for language-aggregation buckets, keyed without pagination or
    # language-filter params so counts stay stable as the user ticks checkboxes.
    # Populated only via a dedicated aggregation-mode Zoekt call (see
    # SearchResults#fetch_language_tally), which lifts the per-file line-match
    # cap so cached counts are untruncated.
    class AggregationCache
      # Longer TTL than Search::Zoekt::Cache because buckets are stable across
      # pagination and language ticks, amortising the cost of a full Zoekt call.
      EXPIRES_IN = 30.minutes

      # Normalise nil/absent (REST) and explicit false (GraphQL) to share one cache entry.
      BOOLEAN_FILTERS = %i[exclude_forks include_archived].freeze

      def initialize(query, current_user:, filters:, group_id:, project_id:, search_mode: :exact)
        @query = query
        @current_user = current_user
        @filters = normalize_filters(filters || {})
        @group_id = group_id
        @project_id = project_id
        @search_mode = search_mode.to_sym
      end

      def read
        raw = with_redis { |redis| redis.get(cache_key) }
        return unless raw

        Marshal.load(raw) # rubocop:disable Security/MarshalLoad -- we wrote this ourselves in #write
      end

      def write(tally)
        return if tally.blank?

        with_redis do |redis|
          # nx: true prevents concurrent calls from overwriting the same value.
          redis.set(cache_key, Marshal.dump(tally), ex: EXPIRES_IN, nx: true)
        end
      end

      private

      attr_reader :query, :current_user, :filters, :group_id, :project_id, :search_mode

      def cache_key
        user_id = current_user&.id || 0
        # Braces pin the key to a single Redis Cluster slot (same convention as Search::Zoekt::Cache).
        "cache:zoekt:{#{user_id}}/language_aggregation/#{fingerprint}"
      end

      def fingerprint
        scope_key = "g#{group_id}-p#{project_id}"
        data = "#{query}-#{scope_key}-#{search_mode}-#{Gitlab::Json.generate(filters.sort)}"
        OpenSSL::Digest.hexdigest('SHA256', data)
      end

      def with_redis(&block)
        Gitlab::Redis::Cache.with(&block) # rubocop:disable CodeReuse/ActiveRecord -- not ActiveRecord
      end

      def normalize_filters(input)
        without_language = input.with_indifferent_access.except(:language)

        BOOLEAN_FILTERS.each_with_object(without_language) do |key, hash|
          hash[key] = Gitlab::Utils.to_boolean(hash[key], default: false)
        end
      end
    end
  end
end
