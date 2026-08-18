# frozen_string_literal: true

module EE
  module Groups # rubocop:disable Gitlab/BoundedContexts -- Extending existing module
    module RestoreService
      extend ::Gitlab::Utils::Override

      override :post_success
      def post_success
        super

        ::GitlabSubscriptions::FreeGroupUpgradeLinkCache.invalidate(current_user.id)
      end
    end
  end
end
