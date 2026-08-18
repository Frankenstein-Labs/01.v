# frozen_string_literal: true

module Groups
  module VirtualRegistries
    module Maven
      class RegistriesAndUpstreamsController < Groups::VirtualRegistries::BaseController
        before_action :verify_read_virtual_registry!, only: [:index]

        before_action :push_update_ability, only: [:index]
        before_action :push_admin_ability, only: [:index]

        feature_category :virtual_registry
        urgency :low

        def index; end

        private

        def push_update_ability
          push_frontend_ability(ability: :update_virtual_registry,
            resource: group.virtual_registry_policy_subject, user: current_user)
        end

        def push_admin_ability
          push_frontend_ability(ability: :admin_virtual_registry,
            resource: group.virtual_registry_policy_subject, user: current_user)
        end
      end
    end
  end
end
