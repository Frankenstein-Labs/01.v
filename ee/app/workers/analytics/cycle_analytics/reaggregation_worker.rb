# frozen_string_literal: true

module Analytics
  module CycleAnalytics
    class ReaggregationWorker
      include ApplicationWorker
      include LoopWithRuntimeLimit
      include CronjobQueue # rubocop:disable Scalability/CronWorkerContext -- worker does not perform work scoped to a context

      MAX_RUNTIME = 270.seconds

      idempotent!

      data_consistency :always
      feature_category :value_stream_management

      def perform
        current_time = Time.current

        loop_with_runtime_limit(MAX_RUNTIME) do |runtime_limiter|
          batch = Analytics::CycleAnalytics::Aggregation.load_batch(current_time, :last_full_run_at)
          break if batch.empty?

          batch.each do |aggregation|
            Analytics::CycleAnalytics::NamespaceAggregatorService.new(aggregation: aggregation, mode: :full,
              runtime_limiter: runtime_limiter).execute

            break if runtime_limiter.over_time?
          end
        end
      end
    end
  end
end
