# frozen_string_literal: true

module Analytics
  module KnowledgeGraph
    class AuthorizationContext
      include Gitlab::Utils::StrongMemoize

      MAX_TRAVERSAL_IDS = 500

      def initialize(user)
        @user = user
      end

      def admin_user?
        return false unless user

        user.can_read_all_resources?
      end

      def anonymous_user?
        user.nil?
      end

      # `{ group_traversal_ids: [{path, access_levels}, ...] }` for the
      # Knowledge Graph service. Each path carries the user's effective role
      # set so GKG can enforce per-entity `required_role` checks.
      def reporter_plus_traversal_ids
        return { group_traversal_ids: [] } unless user

        { group_traversal_ids: traversal_ids_with_access_levels }
      end

      def has_enabled_namespaces?
        return true if admin_user?
        return false if anonymous_user?
        return false if reporter_plus_root_namespace_ids.empty?

        EnabledNamespace.for_root_namespace_id(reporter_plus_root_namespace_ids).exists?
      end
      strong_memoize_attr :has_enabled_namespaces?

      # Root namespace IDs for Reporter+ paths. Resolved via
      # `traversal_ids.first` so subgroup-only members map to their root.
      # Shared with OrbitLicense for entitlement checks.
      def reporter_plus_root_namespace_ids
        return [] if anonymous_user?

        reporter_plus_group_rows.filter_map { |row| row[:traversal_ids].first }.uniq
      end
      strong_memoize_attr :reporter_plus_root_namespace_ids

      attr_reader :user

      private

      def reporter_plus_group_rows
        ::Search::GroupsFinder
          .new(user: user, params: { min_access_level: ::Gitlab::Access::REPORTER })
          .execute_with_access_levels
      end
      strong_memoize_attr :reporter_plus_group_rows

      def enabled_root_namespace_ids
        return [] if reporter_plus_root_namespace_ids.empty?

        EnabledNamespace.root_namespace_ids_for(reporter_plus_root_namespace_ids, limit: MAX_TRAVERSAL_IDS)
      end
      strong_memoize_attr :enabled_root_namespace_ids

      # Buckets the reporter+ group set by each effective access level,
      # compacts each bucket through the trie separately, and publishes
      # `{path, access_levels}` tuples. When a path shows up in multiple buckets
      # because sibling compaction differs across access levels, the full role
      # set is retained. The safety cap is applied once to the final merged
      # payload so the JWT cannot grow by MAX_TRAVERSAL_IDS per access level.
      def traversal_ids_with_access_levels
        start = ::Gitlab::Metrics::System.monotonic_time
        enabled_roots = enabled_root_namespace_ids.to_set
        rows = reporter_plus_group_rows.select { |row| enabled_roots.include?(row[:traversal_ids].first) }

        rows_by_access_level = Hash.new { |h, k| h[k] = [] }
        rows.each do |row|
          row.fetch(:access_levels).each do |access_level|
            rows_by_access_level[access_level] << [row[:organization_id], row[:traversal_ids]]
          end
        end

        access_levels_per_path = Hash.new { |h, k| h[k] = [] }
        rows_by_access_level.each do |access_level, access_level_rows|
          compact_and_format_paths(access_level_rows).each do |path|
            access_levels_per_path[path] << access_level
          end
        end

        observe_auth_context_duration(start)

        entries = access_levels_per_path.sort.map do |path, levels|
          sorted_levels = levels.uniq.sort
          { 'path' => path, 'access_levels' => sorted_levels }
        end

        enforce_global_traversal_id_cap(entries)
      end
      strong_memoize_attr :traversal_ids_with_access_levels

      def log_threshold_exceeded(original_count, compacted_count)
        logger.warn(
          message: 'Traversal ID count exceeds threshold',
          Labkit::Fields::GL_USER_ID => user.id,
          traversal_ids_count: original_count,
          compacted_count: compacted_count,
          threshold: MAX_TRAVERSAL_IDS
        )
      end

      def observe_compaction_ratio(original_count, compacted_count)
        return if original_count == 0

        ratio = compacted_count.to_f / original_count
        metrics.observe_compaction_ratio(ratio)
      end

      def observe_auth_context_duration(start)
        duration = ::Gitlab::Metrics::System.monotonic_time - start
        ::Gitlab::Metrics::KnowledgeGraph::Request.observe_auth_context_duration(duration)
      end

      def logger
        @logger ||= ::Gitlab::KnowledgeGraph::Logger.build
      end

      def metrics
        ::Gitlab::Metrics::KnowledgeGraph::TraversalIds
      end

      def enforce_global_traversal_id_cap(entries)
        original_count = entries.size
        return entries if original_count <= MAX_TRAVERSAL_IDS

        metrics.increment_threshold_exceeded
        capped_entries = entries.first(MAX_TRAVERSAL_IDS)
        log_threshold_exceeded(original_count, capped_entries.size)
        observe_compaction_ratio(original_count, capped_entries.size)

        capped_entries
      end

      # Uses slash separator for ClickHouse startsWith prefix matching.
      # Search uses dash separator (see authorization_utils.rb).
      def format_traversal_ids(traversal_ids)
        traversal_ids.map { |id_array| "#{id_array.join('/')}/" }
      end

      # Compact a single tier's rows through the Trie. The final safety cap is
      # applied after all role buckets are merged.
      def compact_and_format_paths(rows)
        traversal_ids_with_org = rows.map { |org_id, t_ids| [org_id] + t_ids }
        return [] if traversal_ids_with_org.empty?

        trie = ::Namespaces::Traversal::TrieNode.build(traversal_ids_with_org)
        compacted_ids = trie.to_a
        original_count = compacted_ids.size

        metrics.observe_traversal_ids_count(original_count)

        observe_compaction_ratio(traversal_ids_with_org.size, compacted_ids.size)

        format_traversal_ids(compacted_ids)
      end
    end
  end
end
