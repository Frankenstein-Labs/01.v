# frozen_string_literal: true

module SecretsManagement
  module EntitlementHelper
    def secrets_manager_entitlement_root_namespace(root_namespace, user)
      return unless root_namespace.is_a?(::Group) && root_namespace.root?

      SecretsManagement::Entitlement.for(root_namespace, user: user)
    end
  end
end
