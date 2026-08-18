# frozen_string_literal: true

module Gitlab
  module Metrics
    module ZoektTasksSlis
      include Gitlab::Metrics::SliConfig

      puma_enabled!
      sidekiq_enabled!

      APDEX_THRESHOLD_S = 3600 # 1 hour

      class << self
        def initialize_slis!
          Gitlab::Metrics::Sli::Apdex.initialize_sli(:search_zoekt_tasks, [])
          Gitlab::Metrics::Sli::ErrorRate.initialize_sli(:search_zoekt_tasks, [])
        end

        def increment_request_count(zoekt_node_id:, task_type:, count: 1)
          labels = { zoekt_node: zoekt_node_id.to_s, task_type: task_type.to_s }
          request_counter.increment(labels, count)
        end

        def increment_error_count(zoekt_node_id:, task_type:)
          labels = { zoekt_node: zoekt_node_id.to_s, task_type: task_type.to_s }
          Gitlab::Metrics::Sli::ErrorRate[:search_zoekt_tasks].increment(
            labels: labels,
            error: true
          )
        end

        def increment_apdex(zoekt_node_id:, task_type:, duration:)
          labels = { zoekt_node: zoekt_node_id.to_s, task_type: task_type.to_s }
          Gitlab::Metrics::Sli::Apdex[:search_zoekt_tasks].increment(
            labels: labels,
            success: duration <= APDEX_THRESHOLD_S
          )
        end

        private

        def request_counter
          @request_counter ||= Gitlab::Metrics.counter(
            :gitlab_sli_search_zoekt_tasks_requests_total,
            'Total number of Zoekt tasks added to the queue'
          )
        end
      end
    end
  end
end
