# frozen_string_literal: true

module Sbom
  class BuildDependencyGraph
    include Gitlab::Utils::StrongMemoize

    BATCH_SIZE = 250

    def self.execute(project)
      new(project).execute
    end

    def initialize(project)
      @project = project
      @cache_key_service = Sbom::LatestGraphTimestampCacheKey.new(project: project)
      @all_paths = {}
      # This cache tracks a list of top-level nodes reachable from a given ancestor and the respective distance.
      # Any node in the graph could reach multiple top-level nodes, hence why this is a Set.
      # It is shared between all traversals so later traversals benefit from earlier searching, removing
      # significant repeated work.
      @cache = Hash.new { |hash, key| hash[key] = Set.new }
      @stats = { cache_hit: 0, cache_miss: 0 }
      # Memo used in fast mode: node_id => { top_level_ancestor_id => shortest_path_length }.
      @top_ancestor_path_lengths = {}
    end

    def timestamp
      Time.zone.now
    end
    strong_memoize_attr :timestamp

    def execute
      new_graph = fast_mode? ? build_fast_dependency_graph : build_exhaustive_dependency_graph

      # This can raise ActiveRecord::RecordInvalid because another Ci::Pipeline can start removing Sbom::Occurrence
      # rows which will prevent this job from finishing successfully.
      #
      # This actually works in our favour since it's a clear indication we can leave the graph processing to the
      # newest job.
      bulk_insert_paths(new_graph)

      @cache_key_service.store(new_graph.first.created_at) unless new_graph.empty?

      # Schedule removal, this job is idempotent and deduplicated so we can schedule it many times
      Sbom::RemoveOldDependencyGraphsWorker.perform_async(project.id)
    end

    private

    attr_reader :project, :all_paths, :cache, :stats

    def build_exhaustive_dependency_graph
      graph, leaf_nodes = build_adjacency_list

      # Let's get buildin' the graph!
      leaf_nodes.each do |leaf|
        graph[leaf].each do |ancestor|
          iterate_path(graph, ancestor)
        end
      end

      stats_total = stats[:cache_hit] + stats[:cache_miss]

      log_graph_complete(mode: :exhaustive, stats_total: stats_total)
      all_paths.values
    end

    # Fast mode: records one transitive path per (descendant, top-level-ancestor) pair instead of
    # enumerating every possible path. Dramatically reduces path counts and traversal work for
    # highly interconnected monorepo graphs at the cost of showing only one path per top-level
    # ancestor in the UI.
    #
    # A descendant reachable from multiple top-level ancestors keeps one example path to each
    # (preserving per-package attribution); redundant alternate paths to the *same* top-level
    # ancestor are collapsed to the shortest one.
    #
    # Implementation: for each node we memoize `top_ancestor_path_lengths` - the map of every
    # top-level ancestor it reaches to the shortest path_length to that top. A node's map is derived
    # from its parents' maps (each parent path_length + 1), merged keeping the minimum per top.
    # Because each node is resolved exactly once and reused by everything below it, work is bounded
    # by O(edges * distinct-tops-per-node) rather than the exponential route enumeration of
    # exhaustive mode. We then emit one transitive GraphPath row per (node, reachable-top) pair.
    #
    # The project setting `fast_dependency_paths_enabled` (default false) opts into this mode.
    # The existing `dependency_paths` feature flag remains as an instance-level kill switch.
    def build_fast_dependency_graph
      graph, = build_adjacency_list

      # Resolve every node's reachable top-level ancestors, then emit a transitive path row for
      # each (node, top) pair. Direct (length-1) edges are already recorded by create_graph_edges.
      # Snapshot the keys first: resolving a node reads graph[parent_id] for its parents, and the
      # adjacency list's default proc would insert new keys (mutating during iteration) otherwise.
      graph.keys.each do |node_id| # rubocop:disable Style/HashEachMethods -- iterating a snapshot of keys, not the live hash
        top_ancestor_path_lengths(graph, node_id).each do |top_id, path_length|
          collect(top_id, node_id, path_length, true)
        end
      end

      log_graph_complete(mode: :fast, stats_total: 0)
      all_paths.values
    end

    # Builds the adjacency list shared by both traversal modes.
    #
    # `graph` is an adjacency list of descendant->parent edges keyed by descendant.
    # Leaf nodes are all descendants (graph.keys) that are never found as an ancestor;
    # they are the starting points for traversal.
    #
    # @return [Array(Hash, Array)] the adjacency list and its leaf nodes
    def build_adjacency_list
      create_graph_edges

      graph = Hash.new { |hash, key| hash[key] = [] }
      all_ancestors = []

      all_paths.each_value do |path|
        graph[path[:descendant_id]] << path
        all_ancestors << path[:ancestor_id]
      end

      leaf_nodes = graph.keys - all_ancestors

      [graph, leaf_nodes]
    end

    # Entry point for resolving a node's reachable top-level ancestors. Returns the map
    # { top_id => shortest_path_length } for `node_id`. See #resolve_path_lengths for the algorithm.
    def top_ancestor_path_lengths(graph, node_id)
      resolve_path_lengths(graph, node_id, []).first
    end

    # Returns the map of every top-level ancestor reachable from `node_id` to the shortest
    # path_length to that ancestor: { top_id => min_path_length }, alongside a boolean indicating
    # whether the result depended on a node still being resolved higher up the stack (a cycle).
    #
    # The map is built from the node's direct parents: each parent that is itself a top-level
    # ancestor contributes itself at path_length 1; each parent contributes its own resolved tops at
    # their path_length + 1. Entries are merged keeping the minimum path_length per top, which
    # collapses redundant routes to the same top down to the shortest one.
    #
    # `stack` holds the nodes currently being resolved. An edge back into the stack is a cycle: it
    # is skipped (mirroring exhaustive mode's simple-path semantics) and flagged. A result computed
    # while a cycle was open is only partial - it may miss tops reachable through the not-yet-
    # resolved stack node - so it is NOT memoized. Only results free of open-cycle dependencies are
    # cached, which keeps the memo sound while still resolving every node correctly on a clean pass.
    def resolve_path_lengths(graph, node_id, stack)
      memoized = @top_ancestor_path_lengths[node_id]
      return [memoized, false] if memoized

      return [{}, true] if stack.include?(node_id)

      stack.push(node_id)

      path_lengths = {}
      depends_on_open_cycle = false

      graph[node_id].each do |edge|
        parent_id = edge.ancestor_id

        # A top-level node can itself be a descendant of another top-level node, so we still walk
        # upward below to capture those higher ancestors too.
        merge_path_length(path_lengths, parent_id, 1) if edge.top_level_ancestor

        parent_path_lengths, parent_hit_cycle = resolve_path_lengths(graph, parent_id, stack)
        depends_on_open_cycle ||= parent_hit_cycle

        parent_path_lengths.each do |top_id, path_length|
          merge_path_length(path_lengths, top_id, path_length + 1)
        end
      end

      stack.pop

      @top_ancestor_path_lengths[node_id] = path_lengths unless depends_on_open_cycle

      [path_lengths, depends_on_open_cycle]
    end

    # Records `top_id` in `path_lengths` at `path_length`, keeping the smaller value when the top is
    # already present so the retained path to each top is the shortest one.
    def merge_path_length(path_lengths, top_id, path_length)
      current = path_lengths[top_id]
      path_lengths[top_id] = path_length if current.nil? || path_length < current
    end

    def create_graph_edges
      sbom_occurrences.each do |occurrence|
        next if occurrence.ancestors.empty?

        occurrence.ancestors.each do |ancestor|
          next if ancestor.empty?

          ancestor_name = ancestor['name']
          ancestor_version = ancestor['version']

          parent_occurrence = find_parent_sbom_occurrence(
            ancestor_name,
            ancestor_version,
            occurrence.input_file_path
          )

          next unless parent_occurrence

          # Create a direct path
          collect(parent_occurrence.id, occurrence.id, 1, parent_occurrence.top_level?)
        end
      end
    end

    def iterate_path(graph, current_node, current_path = [], depth = 1)
      collect_path(current_path, current_node, depth, false) if current_node.top_level_ancestor
      # We don't stop processing if we find a top_level_ancestor. A node can be a top_level node which is also
      # a descendant of another top_level node. We must keep searching.
      ancestors = graph[current_node.ancestor_id]
      return unless ancestors

      current_path << current_node

      ancestors.each do |ancestor|
        # Check for a cycle. If we find one we can safely stop processing this step.
        next if current_path.any? { |path| path.ancestor_id == ancestor.ancestor_id }

        # Have we already traversed this path?
        if cache[ancestor.descendant_id].present? && cache[ancestor.ancestor_id].present?
          # For each top_level_ancestor we've already found from this descendant:
          cache[ancestor.descendant_id].each do |top_level_ancestor|
            collect_path(current_path, top_level_ancestor[:top_level], depth + top_level_ancestor[:depth], true)
          end
        else
          iterate_path(graph, ancestor, current_path.clone, depth + 1)
        end
      end
    end

    def collect_path(current_path, top_level_ancestor, depth, cache_hit)
      current_path.each do |partial|
        collect(top_level_ancestor.ancestor_id, partial.descendant_id, depth, true)
        # Cache that this path partial can reach this top_level_ancestor.
        cache[partial.descendant_id] << { top_level: top_level_ancestor, depth: depth }
        stats[cache_hit ? :cache_hit : :cache_miss] += 1
        depth -= 1
      end
    end

    def collect(ancestor_id, descendant_id, path_length, top_level)
      key = "#{ancestor_id}-#{descendant_id}-#{path_length}"
      return if all_paths.has_key?(key)

      all_paths[key] = Sbom::GraphPath.new(
        ancestor_id: ancestor_id,
        descendant_id: descendant_id,
        project_id: project.id,
        path_length: path_length,
        created_at: timestamp,
        updated_at: timestamp,
        top_level_ancestor: top_level
      )
    end

    def bulk_insert_paths(paths)
      paths.each_slice(BATCH_SIZE) do |slice|
        Sbom::GraphPath.bulk_insert!(slice)
      end
    end

    def sbom_occurrences
      Sbom::Occurrence.by_project_ids(project.id).with_version.order_by_id
    end
    strong_memoize_attr :sbom_occurrences

    # This is convoluted *but*:
    # `Sbom::Occurrence#ancestors` is `Array[Hash]`.
    # Every Hash is { "name": "something", "version": "something" }.
    # We need to find corresponding Sbom::Occurrence for that particular pair (Node, for example, allows two
    # versions of the same package in a single project)
    # This, usually, should give you exactly one record except it doesn't because monorepos are a thing
    # (it's perfectly fine to have two Rails applications depending on `activesupport`).
    def find_parent_sbom_occurrence(ancestor_name, ancestor_version, child_input_file_path)
      sbom_occurrences
        .find do |occurrence|
          occurrence.component_name.eql?(ancestor_name) &&
            occurrence.input_file_path.eql?(child_input_file_path) &&
            occurrence.version.eql?(ancestor_version)
        end
    end

    def fast_mode?
      project.security_setting&.fast_dependency_paths_enabled?
    end
    strong_memoize_attr :fast_mode?

    def log_graph_complete(mode:, stats_total:)
      ::Gitlab::AppLogger.info(
        message: "New graph creation complete",
        project: project.name,
        project_id: project.id,
        namespace: project.namespace&.name,
        namespace_id: project.namespace&.id,
        count_path_nodes: all_paths.count,
        mode: mode,
        cache_hit: stats[:cache_hit],
        cache_miss: stats[:cache_miss],
        cache_hit_rate: stats_total > 0 ? stats[:cache_hit].to_f / stats_total : 0,
        cache_miss_rate: stats_total > 0 ? stats[:cache_miss].to_f / stats_total : 0
      )
    end
  end
end
