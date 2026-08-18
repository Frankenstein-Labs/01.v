# frozen_string_literal: true

module EE
  module Gitlab
    module PersonalAccessTokens
      class ExpiryDateCalculator
        def initialize(target_user)
          @target_user = target_user
        end

        attr_accessor :target_user

        def max_expiry_date
          return group_level_max_expiry_date if target_user.group_managed_account?

          instance_level_max_expiry_date
        end

        def instance_level_max_expiry_date
          ::Gitlab::CurrentSettings.max_personal_access_token_lifetime_from_now
        end

        def group_level_max_expiry_date
          target_user.managing_group&.max_personal_access_token_lifetime_from_now
        end
      end
    end
  end
end
