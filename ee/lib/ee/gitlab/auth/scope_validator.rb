# frozen_string_literal: true

module EE
  module Gitlab
    module Auth
      module ScopeValidator
        def permit_quick_actions?
          request_authenticator.current_token_scopes.exclude?("ai_workflows")
        end
      end
    end
  end
end
