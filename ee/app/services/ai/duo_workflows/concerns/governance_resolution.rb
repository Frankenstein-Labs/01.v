# frozen_string_literal: true

module Ai
  module DuoWorkflows
    module Concerns
      # Shared retry wrapper around Ai::ToolRules::ResolutionService so every
      # governance clamp site tolerates the same transient failures before its
      # caller decides how to fail.
      module GovernanceResolution
        MAX_GOVERNANCE_RETRIES = 3

        private

        # Executes the resolution service, retrying transient failures.
        # Returns the last ServiceResponse; a failed response is returned
        # as-is so the caller chooses its own failure mode.
        def resolve_governance_with_retry(service, **log_context)
          result = nil

          MAX_GOVERNANCE_RETRIES.times do |attempt|
            result = service.execute
            break if result.success?

            Gitlab::AppLogger.warn(
              message: "Governance resolution failed, retrying (attempt #{attempt + 1}/#{MAX_GOVERNANCE_RETRIES})",
              **log_context
            )
          end

          result
        end
      end
    end
  end
end
