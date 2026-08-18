# frozen_string_literal: true

module Search
  module Zoekt
    class RolloutWorker
      include ApplicationWorker
      include Search::Worker
      include CronjobQueue # rubocop:disable Scalability/CronWorkerContext -- there is no relevant metadata
      include Gitlab::ExclusiveLeaseHelpers
      prepend ::Geo::SkipSecondary
      include Gitlab::Loggable

      deduplicate :until_executed, if_deduplicated: :reschedule_once
      data_consistency :sticky
      idempotent!
      urgency :low

      defer_on_database_health_signal :gitlab_main,
        [:zoekt_nodes, :zoekt_enabled_namespaces, :zoekt_replicas, :zoekt_indices, :zoekt_repositories, :zoekt_tasks],
        10.minutes

      MAX_RETRIES = 5
      INITIAL_BACKOFF = 5.minutes

      def perform(retry_count = 0)
        return false if Gitlab::CurrentSettings.zoekt_indexing_paused?
        return false unless Search::Zoekt.licensed_and_indexing_enabled?

        in_lock(self.class.name.underscore, ttl: 10.minutes, retries: 10, sleep_sec: 1) do
          result = RolloutService.execute(dry_run: false, batch_size: Gitlab::CurrentSettings.zoekt_rollout_batch_size)
          logger.info(build_structured_payload(**{ message: result.message, changes: result.changes }))

          if result.re_enqueue
            self.class.perform_async
          elsif retry_count < MAX_RETRIES
            backoff_time = INITIAL_BACKOFF * (2**retry_count)
            self.class.perform_in(backoff_time, retry_count + 1)
          else
            log_data = { message: "RolloutWorker exceeded max back off interval: #{result.message}" }
            logger.info(build_structured_payload(**log_data))
          end
        end
      end

      private

      def logger
        @logger ||= ::Search::Zoekt::Logger.build
      end
    end
  end
end
