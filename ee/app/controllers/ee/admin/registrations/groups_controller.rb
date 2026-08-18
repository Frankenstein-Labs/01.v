# frozen_string_literal: true

module EE
  module Admin
    module Registrations
      module GroupsController
        extend ::Gitlab::Utils::Override

        private

        override :verify_available!
        def verify_available!
          return render_404 if ::Gitlab::Saas.feature_available?(:subscriptions_trials)

          super
        end
      end
    end
  end
end
