# frozen_string_literal: true

module Arkose
  class TokenVerificationService
    attr_reader :session_token, :user, :email, :response

    ARKOSE_LABS_DEFAULT_NAMESPACE = 'client'
    ARKOSE_LABS_DEFAULT_SUBDOMAIN = 'verify-api'

    def initialize(session_token:, user: nil, email: nil)
      @session_token = session_token
      @user = user
      @email = email
    end

    def execute
      parsed_response = Gitlab::HTTP.perform_request(
        Net::HTTP::Post,
        arkose_verify_url,
        headers: { 'Content-Type': 'application/json' },
        body: body
      ).parsed_response

      @response = ::Arkose::VerifyResponse.new(parsed_response)

      if response.invalid_token?
        logger.log_invalid_token
        AntiAbuse::IdentityVerification::ArkoseFailOpen.track_token_verification_result(success: false)
        return error
      end

      RecordUserDataService.new(response: response, user: user).execute if user
      AntiAbuse::IdentityVerification::ArkoseFailOpen.track_token_verification_result(success: true)

      if response.allowlisted? || response.challenge_solved?
        logger.log_successful_token_verification
        return success
      end

      logger.log_unsolved_challenge
      error
    rescue StandardError => error
      Gitlab::ErrorTracking.track_exception(error)
      logger.log_failed_token_verification
      AntiAbuse::IdentityVerification::ArkoseFailOpen.track_token_verification_result(success: false)

      # Allow user to proceed when we can't verify the token for some
      # unexpected reason (e.g. ArkoseLabs is down)
      user&.assume_low_risk!(reason: 'Unrecoverable Arkose error')
      success
    end

    private

    def body
      data = {
        private_key: AntiAbuse::IdentityVerification::Settings.arkose_private_api_key,
        session_token: session_token
      }

      if user
        data[:log_data] = user.id.to_s
        data[:email_address] = user.email
      elsif email
        data[:email_address] = email
      end

      Gitlab::Json.generate(data)
    end

    def logger
      @logger ||= ::Arkose::Logger.new(
        session_token: session_token,
        user: user,
        verify_response: response
      )
    end

    def arkose_verify_url
      arkose_labs_namespace = ::Gitlab::CurrentSettings.arkose_labs_namespace
      subdomain = if arkose_labs_namespace == ARKOSE_LABS_DEFAULT_NAMESPACE
                    ARKOSE_LABS_DEFAULT_SUBDOMAIN
                  else
                    "#{arkose_labs_namespace}-verify"
                  end

      "https://#{subdomain}.arkoselabs.com/api/v4/verify/"
    end

    def success
      verify_response = response || ::Arkose::VerifyResponse.new({})

      ServiceResponse.success(payload: { response: verify_response })
    end

    def error
      ServiceResponse.error(message: 'Captcha was not solved')
    end
  end
end
