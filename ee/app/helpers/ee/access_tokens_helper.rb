# frozen_string_literal: true

module EE
  module AccessTokensHelper
    extend ::Gitlab::Utils::Override

    override :personal_access_token_data
    def personal_access_token_data(token, user = current_user)
      super.deep_merge(
        access_token: {
          agentic_available: user.foundational_agent_available?('duo_permissions_assistant').to_s
        }
      )
    end

    private

    override :max_date_allowed
    def max_date_allowed
      return super unless personal_access_token_expiration_policy_enabled?

      personal_access_token_max_expiry_date&.iso8601
    end

    override :max_expiration_days
    def max_expiration_days
      return super unless personal_access_token_expiration_policy_enabled?

      personal_access_token_max_expiry_days
    end
  end
end
