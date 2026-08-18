# frozen_string_literal: true

module EE
  module API
    module Mcp
      module Base
        extend ActiveSupport::Concern

        prepended do
          helpers do
            extend ::Gitlab::Utils::Override
            include ::Gitlab::Utils::StrongMemoize

            override :mcp_denial_reason
            def mcp_denial_reason
              # On SaaS the instance setting does not gate access; the namespace-level
              # check is the authority.
              if ::Gitlab::Saas.feature_available?(:mcp_server_saas_only)
                return :no_enabled_namespace unless current_user.any_group_with_mcp_server_enabled?

                nil
              else
                super
              end
            end
            strong_memoize_attr :mcp_denial_reason
          end
        end
      end
    end
  end
end
