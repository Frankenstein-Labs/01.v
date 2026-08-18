# frozen_string_literal: true

module EE
  module Admin
    module UserActionsHelper
      extend ::Gitlab::Utils::Override

      override :admin_actions
      def admin_actions(user)
        return super if can?(current_user, :admin_all_resources)

        []
      end
    end
  end
end
