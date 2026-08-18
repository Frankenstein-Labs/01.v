# frozen_string_literal: true

module Ai
  module ToolRules
    # Single source of truth for the tool-rule permission values. Shared by the
    # ToolRule model enum, the tool-rule resolution domain, and the GraphQL
    # ToolPermissionEnum so the allow/ask/deny strings are defined in one place
    # instead of repeated as bare literals.
    module Permissions
      ALLOW = 'allow'
      ASK = 'ask'
      DENY = 'deny'

      # A background flow has no human to answer an `ask`, so `ask` becomes `allow`; any other
      # value passes through unchanged. Both the enforcement and display paths call
      # this on the group default, so the shown and enforced values stay in step.
      def self.background_effective(permission)
        permission.to_s == ASK ? ALLOW : permission
      end
    end
  end
end
