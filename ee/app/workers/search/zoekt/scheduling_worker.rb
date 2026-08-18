# frozen_string_literal: true

module Search
  module Zoekt
    class SchedulingWorker
      include ApplicationWorker
      include Search::Worker
      include CronjobQueue
      prepend ::Geo::SkipSecondary

      deduplicate :until_executed
      data_consistency :always
      idempotent!
      urgency :low

      defer_on_database_health_signal :gitlab_main,
        [:zoekt_nodes, :zoekt_enabled_namespaces, :zoekt_replicas, :zoekt_indices, :zoekt_repositories, :zoekt_tasks],
        10.minutes

      def perform(task = nil)
        return false unless Search::Zoekt.licensed_and_indexing_enabled?
        return false if Gitlab::CurrentSettings.zoekt_indexing_paused?

        return initiate if task.nil?

        SchedulingService.execute(task)
      end

      private

      def initiate
        SchedulingService::TASKS.each do |task|
          with_context(related_class: self.class) { self.class.perform_async(task.to_s) }
        end
      end
    end
  end
end
