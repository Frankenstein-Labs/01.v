# frozen_string_literal: true

module Search
  module Zoekt
    class ReplicaStateService
      def self.execute
        new.execute
      end

      def execute
        pending_replicas_with_all_ready_indices.update_all(state: :ready) if Replica.pending.exists?

        return unless Replica.ready.exists?

        ready_replicas_with_non_ready_indices.update_all(state: :pending)
      end

      private

      def pending_replicas_with_all_ready_indices
        Replica.pending.with_all_ready_indices
      end

      def ready_replicas_with_non_ready_indices
        Replica.ready.with_non_ready_indices
      end
    end
  end
end
