# frozen_string_literal: true

module Onboarding
  # This worker should not be invoked by .perform_async unless it is in a place where
  # the worker is unreachable by SaaS instances.
  # By following that constraint, we will ensure we do not needlessly enqueue an async
  # job for non SaaS instances.
  # If you need to invoke this worker from a place where it is reachable by non SaaS instances,
  # use the Onboarding::ProgressService.async method instead.
  class ProgressTrackingWorker
    include ApplicationWorker

    data_consistency :always

    sidekiq_options retry: 3

    feature_category :onboarding
    worker_resource_boundary :cpu
    urgency :low

    deduplicate :until_executed
    idempotent!

    def perform(namespace_id, action)
      namespace = Namespace.find_by_id(namespace_id)
      return unless namespace && action

      Onboarding::ProgressService.new(namespace).execute(action: action.to_sym)
    end
  end
end
