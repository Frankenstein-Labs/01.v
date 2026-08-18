# frozen_string_literal: true

module Search
  module Zoekt
    class SelectionService
      attr_reader :max_batch_size

      ResourcePool = Struct.new(:enabled_namespaces, :nodes)

      def self.execute(**kwargs)
        new(**kwargs).execute
      end

      def initialize(max_batch_size: 128)
        @max_batch_size = max_batch_size
      end

      def execute
        namespaces = fetch_enabled_namespace_for_indexing
        nodes = fetch_available_nodes

        ResourcePool.new(namespaces, nodes)
      end

      private

      def fetch_enabled_namespace_for_indexing
        [].tap do |batch|
          ::Search::Zoekt::EnabledNamespace.with_rollout_allowed.each_batch_with_mismatched_replicas do |ns|
            batch << ns
            break if batch.count >= max_batch_size
          end
        end
      end

      def fetch_available_nodes
        ::Search::Zoekt::Node.available_for_search_indexing
      end
    end
  end
end
