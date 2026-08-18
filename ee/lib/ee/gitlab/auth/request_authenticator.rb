# frozen_string_literal: true

module EE
  module Gitlab
    module Auth
      module RequestAuthenticator
        extend ::Gitlab::Utils::Override

        private

        override :find_user_for_graphql_api_request
        def find_user_for_graphql_api_request
          find_user_from_geo_token || super
        end

        override :graphql_authorization_scopes
        def graphql_authorization_scopes
          super + [:ai_features, :ai_workflows]
        end
      end
    end
  end
end
