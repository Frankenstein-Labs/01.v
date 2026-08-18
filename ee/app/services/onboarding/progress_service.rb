# frozen_string_literal: true

module Onboarding
  class ProgressService
    # This method helps us keep non SaaS instances from needlessly enqueueing a async job.
    def self.async(namespace_id, action)
      return unless ::Onboarding.enabled?

      ::Onboarding::ProgressTrackingWorker.perform_async(namespace_id, action.to_s)
    end

    def initialize(namespace)
      @namespace = namespace&.root_ancestor
    end

    def execute(action:)
      return unless @namespace

      Onboarding::Progress.register(@namespace, action)
    end
  end
end
