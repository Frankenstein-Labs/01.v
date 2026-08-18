# frozen_string_literal: true

module Onboarding
  class StatusStepUpdateService
    def initialize(user, step_url)
      @user = user
      @step_url = step_url
    end

    def execute
      unless Onboarding.user_onboarding_in_progress?(user)
        return ServiceResponse.error(message: 'User is not onboarding.', payload: payload)
      end

      if user.update(onboarding_status_step_url: step_url)
        ServiceResponse.success(payload: payload)
      else
        ::Gitlab::ErrorTracking.track_exception(
          ::Onboarding::StepUrlError.new(
            "Failed to updated the step_url with #{step_url}: #{user.errors.full_messages}"
          ),
          onboarding_status: user.onboarding_status.to_json,
          user_id: user.id
        )

        ServiceResponse.error(message: user.errors.full_messages, payload: payload)
      end
    end

    private

    attr_reader :user, :step_url

    def payload
      { step_url: user.reset.onboarding_status_step_url }
    end
  end
end
