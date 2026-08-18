# frozen_string_literal: true

module Arkose
  module TokenVerifiable
    extend ActiveSupport::Concern
    include ::Gitlab::Utils::StrongMemoize

    private

    def verify_arkose_labs_token(user: nil, email: nil)
      return true unless arkose_labs_enabled?(user: user)
      return true if arkose_labs_verify_response(user: user, email: email).present?

      if arkose_down?
        user&.assume_low_risk!(reason: 'Arkose is down')
        log_challenge_skipped
        return true
      end

      false
    end

    def arkose_labs_verify_response(user: nil, email: nil)
      strong_memoize_with(:arkose_labs_verify_response, [user, email]) do
        result = Arkose::TokenVerificationService.new(
          session_token: token,
          user: user,
          email: email
        ).execute
        result.success? ? result.payload[:response] : nil
      end
    end

    def log_challenge_skipped
      ::Gitlab::AppLogger.info(
        message: 'Arkose challenge skipped',
        reason: 'Arkose is experiencing an outage',
        username: username
      )
    end

    def token
      @token ||= params[:arkose_labs_token].to_s
    end

    def arkose_down?
      Arkose::StatusService.new.execute.error?
    end
  end
end
