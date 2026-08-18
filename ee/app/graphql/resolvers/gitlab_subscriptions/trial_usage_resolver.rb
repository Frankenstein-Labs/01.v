# frozen_string_literal: true

module Resolvers
  module GitlabSubscriptions
    class TrialUsageResolver < BaseResolver
      type Types::GitlabSubscriptions::TrialUsageType, null: true

      argument :namespace_path, GraphQL::Types::ID,
        required: false,
        description: "Path of the top-level namespace. Leave it blank if querying the instance subscription."

      def resolve(**args)
        subscription_target = args[:namespace_path] ? :namespace : :instance
        namespace = find_namespace(args[:namespace_path])

        authorize!(subscription_target, namespace)

        license_key = License.current&.data if subscription_target == :instance

        subscription_usage_client = ::Gitlab::SubscriptionPortal::SubscriptionUsageClient.new(**{
          license_key: license_key,
          namespace_id: namespace&.id
        }.compact)

        context[:subscription_usage_client] = subscription_usage_client

        ::GitlabSubscriptions::TrialsUsage::Base.new(
          subscription_target: subscription_target,
          namespace: namespace,
          subscription_usage_client: subscription_usage_client
        )
      end

      private

      def authorize!(subscription_target, namespace)
        return authorize_for_instance! if subscription_target == :instance

        raise_resource_not_available_error! unless namespace

        unless namespace.root? && namespace.group_namespace?
          raise_resource_not_available_error!("Trial usage can only be queried on a root namespace")
        end

        raise_resource_not_available_error! unless Ability.allowed?(current_user, :read_subscription_usage, namespace)
      end

      def authorize_for_instance!
        raise_resource_not_available_error! unless Ability.allowed?(current_user, :read_subscription_usage)
      end

      def find_namespace(namespace_path)
        return unless namespace_path

        Namespace.find_by_full_path(namespace_path)
      end
    end
  end
end
