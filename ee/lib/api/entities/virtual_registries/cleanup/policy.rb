# frozen_string_literal: true

module API
  module Entities
    module VirtualRegistries
      module Cleanup
        class Policy < Grape::Entity
          expose :group_id, :next_run_at, :last_run_at, :last_run_deleted_size, :last_run_deleted_entries_count,
            :keep_n_days_after_download, :status, :cadence, :enabled, :failure_message, :last_run_detailed_metrics,
            :notify_on_success, :notify_on_failure, :created_at, :updated_at
        end
      end
    end
  end
end
