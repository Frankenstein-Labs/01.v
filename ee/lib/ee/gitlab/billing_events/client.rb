# frozen_string_literal: true

module EE
  module Gitlab
    module BillingEvents
      module Client
        extend ::Gitlab::Utils::Override

        private

        override :realm
        def realm
          raw = ::CloudConnector.gitlab_realm
          ::Gitlab::BillingEvents::Client::REALM_MAP.fetch(raw)
        end

        override :deployment_type
        def deployment_type
          ::CloudConnector.deployment_type
        end
      end
    end
  end
end
