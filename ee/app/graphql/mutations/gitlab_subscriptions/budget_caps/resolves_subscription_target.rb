# frozen_string_literal: true

module Mutations
  module GitlabSubscriptions
    module BudgetCaps
      module ResolvesSubscriptionTarget
        extend ActiveSupport::Concern

        private

        def resolve_target(namespace_path)
          if namespace_path
            namespace = ::Namespace.find_by_full_path(namespace_path)
            raise_resource_not_available_error! unless namespace
            raise_resource_not_available_error! unless namespace.root? && namespace.group_namespace?

            [:namespace, namespace]
          else
            [:instance, nil]
          end
        end

        def authorize_mutation!(subscription_target, namespace)
          allowed = if subscription_target == :instance
                      Ability.allowed?(
                        current_user, :update_subscription_usage_cap
                      )
                    else
                      Ability.allowed?(
                        current_user, :update_subscription_usage_cap, namespace
                      )
                    end

          raise_resource_not_available_error! unless allowed
        end

        def build_subscription_usage_client(subscription_target, namespace)
          if subscription_target == :instance
            billable_license = License.billable_license || License.current
            raise_resource_not_available_error! unless billable_license

            license_key = billable_license.data
          end

          ::Gitlab::SubscriptionPortal::SubscriptionUsageClient.new(
            license_key: license_key,
            namespace_id: namespace&.id
          )
        end
      end
    end
  end
end
