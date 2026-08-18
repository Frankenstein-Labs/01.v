# frozen_string_literal: true

module Search
  module Zoekt
    class NodeWithNegativeUnclaimedStorageEventWorker
      include Gitlab::EventStore::Subscriber
      include Search::Zoekt::EventWorker
      prepend ::Geo::SkipSecondary

      idempotent!

      defer_on_database_health_signal :gitlab_main, [:zoekt_nodes, :zoekt_indices], 10.minutes

      MAX_INDICES_TO_EVICT = 1_000

      def handle_event(event)
        return unless ::Search::Zoekt.licensed_and_indexing_enabled?

        node_ids = event.data[:node_ids]

        return if node_ids.empty?

        Search::Zoekt::Node.negative_unclaimed_storage_bytes.id_in(node_ids).find_each do |node|
          unclaimed_storage_bytes = node.unclaimed_storage_bytes
          next unless unclaimed_storage_bytes < 0

          logger.info(build_structured_payload(
            message: 'Processing node with negative unclaimed storage bytes',
            'zoekt.node_id': node.id,
            'zoekt.unclaimed_storage_bytes': unclaimed_storage_bytes))

          total_reserved_bytes = 0
          index_ids_to_evict = []

          node.indices.not_pending_eviction.find_each do |index|
            total_reserved_bytes += index.reserved_storage_bytes if index.reserved_storage_bytes > 0

            index_ids_to_evict << index.id

            if total_reserved_bytes >= unclaimed_storage_bytes.abs || index_ids_to_evict.size >= MAX_INDICES_TO_EVICT
              break
            end
          end

          indices = node.indices.id_in(index_ids_to_evict).limit(MAX_INDICES_TO_EVICT)
          updated_count = indices.update_all(state: :pending_eviction, updated_at: Time.current)

          log_extra_metadata_on_done(:indices_updated_count, updated_count)
        end
      end
    end
  end
end
