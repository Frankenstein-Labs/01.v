# frozen_string_literal: true

module DuoChatPanel
  class StartTrialComponent < ViewComponent::Base
    include DuoChatPanel::LegacyCallout
    include DuoChatPanel::StartTrial

    DEFAULT_TRIAL_DURATION = 30

    def initialize(container:, user:)
      @container = container
      @user = user
    end

    private

    attr_reader :container, :user

    def data
      path = trial_path(@user, source: @container.record)

      trial_duration =
        if path.nil?
          nil
        elsif ::Gitlab::Saas.feature_available?(:subscriptions_trials)
          GitlabSubscriptions::TrialDurationService.new.execute
        else
          DEFAULT_TRIAL_DURATION
        end

      {
        new_trial_path: path,
        trial_duration: trial_duration,
        can_start_trial: path.present?.to_s,
        auto_expand: auto_expanded?(user).to_s
      }.compact
    end
  end
end
