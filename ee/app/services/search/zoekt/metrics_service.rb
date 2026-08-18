# frozen_string_literal: true

module Search
  module Zoekt
    class MetricsService
      include Gitlab::Loggable

      METRICS = %i[
        indices_metrics
        node_metrics
      ].freeze

      def self.execute(metric)
        instance = new(metric)

        instance.execute
      end

      def initialize(metric)
        @metric = metric.to_sym
      end

      def execute
        raise ArgumentError, "Unknown metric: #{metric.inspect}" unless METRICS.include?(metric)
        raise NotImplementedError unless respond_to?(metric, true)

        send(metric) # rubocop:disable GitlabSecurity/PublicSend -- We control the list of metrics in the source code
      end

      private

      attr_reader :metric

      def node_metrics
        ::Search::Zoekt::Node.for_search.online.find_each do |node|
          log_data = build_structured_payload(
            meta: node.metadata_json,
            enabled_namespaces_count: node.enabled_namespaces.count,
            indices_count: node.indices.count,
            task_count_pending: node.tasks.pending.count,
            task_count_failed: node.tasks.failed.count,
            task_count_processing_queue: node.tasks.processing_queue.count,
            task_count_orphaned: node.tasks.orphaned.count,
            task_count_done: node.tasks.done.count,
            message: 'Reporting metrics',
            metric: :node_metrics
          )

          logger.info(log_data)
        end
      end

      def indices_metrics
        log_data = build_structured_payload(
          'meta.zoekt.with_stale_used_storage_bytes_updated_at' => Index.with_stale_used_storage_bytes_updated_at.count,
          message: 'Reporting metrics',
          metric: :indices_metrics
        )

        logger.info(log_data)
      end

      def logger
        @logger ||= ::Search::Zoekt::Logger.build
      end
    end
  end
end
