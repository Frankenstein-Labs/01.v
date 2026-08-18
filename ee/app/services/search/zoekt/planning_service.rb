# frozen_string_literal: true

module Search
  module Zoekt
    class PlanningService
      attr_reader :enabled_namespaces, :nodes, :options

      def self.plan(**kwargs)
        new(**kwargs).plan
      end

      def initialize(enabled_namespaces:, nodes:, **options)
        @enabled_namespaces = Array(enabled_namespaces)
        @nodes = format_nodes(nodes)
        @options = options
      end

      def plan
        all_plans = enabled_namespaces.map do |enabled_namespace|
          Plan.new(enabled_namespace: enabled_namespace, nodes: nodes, **options).generate
        end
        failed_plans, successful_plans = all_plans.partition { |plan| plan[:errors].present? }
        grouped_plans = successful_plans.group_by { |plan| plan[:action] }
        create_plans = grouped_plans.fetch(:create, [])
        destroy_plans = grouped_plans.fetch(:destroy, [])
        unchanged_plans = grouped_plans.fetch(:unchanged, [])

        {
          total_required_storage_bytes: create_plans.sum { |plan| plan[:namespace_required_storage_bytes] },
          create: create_plans,
          destroy: destroy_plans,
          unchanged: unchanged_plans,
          nodes: build_node_change_plan,
          failures: failed_plans
        }
      end

      private

      def format_nodes(zoekt_nodes)
        zoekt_nodes.to_a.map do |node|
          {
            id: node[:id],
            name: node.metadata['name'],
            unclaimed_storage_bytes: node[:unclaimed_storage_bytes],
            unclaimed_storage_bytes_before: node[:unclaimed_storage_bytes],
            indices: [],
            namespace_ids: [],
            node: node
          }
        end
      end

      # presentation only
      def build_node_change_plan
        nodes.filter { |hsh| hsh[:indices].present? }.map do |hsh|
          {
            id: hsh[:id],
            name: hsh[:name],
            unclaimed_storage_bytes_before: hsh[:unclaimed_storage_bytes_before],
            unclaimed_storage_bytes_after: hsh[:unclaimed_storage_bytes],
            claimed_storage_bytes: hsh[:indices].sum { |hsh| hsh[:required_storage_bytes] },
            namespace_ids: hsh[:namespace_ids].sort,
            indices: hsh[:indices].sort_by { |hsh| hsh[:namespace_id] }
          }
        end
      end

      class Plan
        include Gitlab::Utils::StrongMemoize

        def initialize(enabled_namespace:, nodes:, max_indices_per_replica: MAX_INDICES_PER_REPLICA)
          @enabled_namespace = enabled_namespace
          @namespace = enabled_namespace.namespace
          @num_replicas = enabled_namespace.number_of_replicas
          @max_indices_per_replica = max_indices_per_replica
          @errors = []
          @replica_plans = []
          @nodes = nodes
          @exhausted_node_ids = Set.new
        end

        def generate
          existing_replicas_count = enabled_namespace.replicas.size
          desired_replicas_count = num_replicas

          result = {
            namespace_id: namespace.id,
            enabled_namespace_id: enabled_namespace.id,
            namespace_required_storage_bytes: 0,
            replicas: [],
            errors: [],
            action: determine_action(existing_replicas_count, desired_replicas_count)
          }

          case result[:action]
          when :create
            replicas_to_create = desired_replicas_count - existing_replicas_count

            if fetch_project_namespaces.exists?
              replicas_to_create.times { simulate_replica_plan }
            else
              replicas_to_create.times { create_empty_replica }
            end

            result[:replicas] = replica_plans
            result[:namespace_required_storage_bytes] = calculate_namespace_storage
          when :destroy
            # For destroy, we don't need to simulate - we'll include replica IDs to delete
            replicas_to_destroy_count = existing_replicas_count - desired_replicas_count
            replicas = enabled_namespace.replicas
            replica_ids = replicas.order(:state).order(id: :desc).limit(replicas_to_destroy_count).pluck_primary_key # rubocop:disable CodeReuse/ActiveRecord -- Just order
            result[:replicas_to_destroy] = replica_ids
          end

          # Update errors after all operations
          result[:errors] = errors.uniq
          result
        end

        private

        attr_reader :enabled_namespace, :namespace, :num_replicas, :max_indices_per_replica, :errors,
          :replica_plans, :nodes, :project_namespace_id

        def determine_action(existing_count, desired_count)
          if existing_count < desired_count
            :create
          elsif existing_count > desired_count
            :destroy
          else
            :unchanged
          end
        end

        def simulate_replica_plan
          replica_indices = []

          fetch_project_namespaces.find_each do |project_namespace|
            project = project_namespace.project
            stats = project&.statistics
            next unless stats

            if replica_indices.size >= max_indices_per_replica
              details = "Replica reached maximum index limit (#{max_indices_per_replica})"
              accumulate_error(replica_plans.size, :index_limit_exceeded, details)
              break
            end

            @project_namespace_id = project_namespace.id
            assign_to_node(stats, replica_indices)
          end

          add_replica_plan(replica_indices)
        end

        def create_empty_replica
          candidate_nodes = nodes.reject { |n| @exhausted_node_ids.include?(n[:id]) || n[:unclaimed_storage_bytes] < 0 }
          best_node = candidate_nodes.max_by { |node| node[:unclaimed_storage_bytes] }

          if best_node
            replica_indices = [simulate_index(best_node)]
            add_replica_plan(replica_indices)
          else
            accumulate_error(nil, :node_unavailable, "No nodes available to create an empty replica")
          end
        end

        def fetch_project_namespaces
          ::Namespace.by_root_id(namespace.id).project_namespaces.with_project_statistics
        end
        strong_memoize_attr :fetch_project_namespaces

        def assign_to_node(stats, replica_indices)
          best_node = find_best_node(stats)

          if best_node
            assign_project_to_index(best_node, stats, replica_indices)
          else
            details = "No node can accommodate project #{stats.project_id} with size #{scaled_size(stats)}"
            accumulate_error(replica_plans.size, :node_unavailable, details)
          end
        end

        def find_best_node(stats)
          nodes.find { |n| !@exhausted_node_ids.member?(n[:id]) && (n[:unclaimed_storage_bytes] >= scaled_size(stats)) }
        end

        def assign_project_to_index(node, stats, replica_indices)
          project_size = scaled_size(stats)
          last_index = replica_indices.last
          if last_index && (last_index[:required_storage_bytes] + project_size) <= last_index[:max_storage_bytes]
            index = last_index
            assigned_node_id = last_index[:node_id]
            assigned_node = nodes.find { |n| n[:id] == assigned_node_id }
          end

          unless index
            index = simulate_index(node)
            replica_indices << index
            node[:indices] ||= []
            node[:indices] << index
            node[:namespace_ids] << namespace.id unless node[:namespace_ids].include?(namespace.id)
            assigned_node = node
            @exhausted_node_ids.add(node[:id]) if last_index # If this is the first project of the replica then skip
          end

          add_project_to_index(index, stats, last_index: last_index)
          assigned_node[:unclaimed_storage_bytes] -= project_size
        end

        def simulate_index(node)
          {
            node_id: node[:id],
            node_name: node[:name],
            namespace_id: namespace.id,
            projects: { project_namespace_id_from: nil, project_namespace_id_to: nil },
            required_storage_bytes: 0,
            max_storage_bytes: node[:unclaimed_storage_bytes]
          }
        end

        def add_project_to_index(index, stats, last_index:)
          unless index == last_index || last_index.nil?
            index[:projects][:project_namespace_id_from] ||= last_index[:projects][:project_namespace_id_to].next
          end

          index[:projects][:project_namespace_id_to] = project_namespace_id
          index[:required_storage_bytes] += scaled_size(stats)
        end

        def add_replica_plan(replica_indices)
          replica_indices.last[:projects][:project_namespace_id_to] = nil if replica_indices.any?

          replica_plans << { indices: replica_indices.map { |index| format_index(index) } }
          # Add the node_id to Set from each index of a replica
          # to ensure indices of different replicas of a namespace does not get the same node
          @exhausted_node_ids.merge(replica_indices.pluck(:node_id)) # rubocop: disable CodeReuse/ActiveRecord, Database/AvoidUsingPluckWithoutLimit -- Just a plain Array
        end

        def format_index(index)
          index.slice(:node_id, :node_name, :projects, :required_storage_bytes, :max_storage_bytes)
        end

        def calculate_namespace_storage
          replica_plans.sum { |replica| replica[:indices].sum { |index| index[:required_storage_bytes] } }
        end

        def scaled_size(stats)
          stats.repository_size * buffer_factor
        end

        def buffer_factor
          ::Search::Zoekt::Index.global_buffer_factor
        end
        strong_memoize_attr :buffer_factor

        def accumulate_error(replica_idx, type, details)
          @errors << { namespace_id: namespace.id, replica_idx: replica_idx, type: type, details: details }
        end
      end
    end
  end
end
