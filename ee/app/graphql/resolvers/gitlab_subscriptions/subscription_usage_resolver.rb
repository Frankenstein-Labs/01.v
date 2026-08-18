# frozen_string_literal: true

module Resolvers
  module GitlabSubscriptions
    class SubscriptionUsageResolver < BaseResolver
      type Types::GitlabSubscriptions::SubscriptionUsageType, null: true

      argument :namespace_path, GraphQL::Types::ID,
        required: false,
        description: "Path of the top-level namespace. Leave it blank if querying the instance subscription."

      argument :start_date, GraphQL::Types::ISO8601Date,
        required: false,
        description: "Start date of the usage period to query. Defaults to the beginning of the current month."

      argument :end_date, GraphQL::Types::ISO8601Date,
        required: false,
        description: "End date of the usage period to query. Defaults to the end of the current month."

      argument :flow_types, [GraphQL::Types::String],
        required: false,
        description: 'Filter usage data by flow type identifiers (e.g. ["chat", "code_review"]). ' \
          'Only applies to event-backed fields (creditsUsed, dailyUsage, dailyAverage, ' \
          'totalActiveUsers, totalCreditsUsed). Wallet-backed fields (monthlyWaiver, ' \
          'monthlyCommitment, overage) are not affected by this filter.'

      MAX_DATE_RANGE = 1.year

      def resolve(**args)
        start_date = args[:start_date] || Date.current.beginning_of_month
        end_date = args[:end_date] || Date.current.end_of_month

        validate_date_range!(start_date, end_date)

        subscription_target = args[:namespace_path] ? :namespace : :instance
        namespace = find_namespace(args[:namespace_path])

        authorize!(subscription_target, namespace)

        license_key = License.billable_license&.data if subscription_target == :instance

        effective_start = clamp_start_date(start_date, subscription_target, namespace)
        effective_end = [end_date, Date.current].min

        subscription_usage_client = ::Gitlab::SubscriptionPortal::SubscriptionUsageClient.new(**{
          license_key: license_key,
          namespace_id: namespace&.id,
          start_date: effective_start.iso8601,
          end_date: effective_end.iso8601
        }.compact)

        context[:flow_types] = args[:flow_types].presence
        context[:subscription_usage_client] = subscription_usage_client

        ::GitlabSubscriptions::SubscriptionUsage.new(
          subscription_target: subscription_target,
          namespace: namespace,
          subscription_usage_client: subscription_usage_client,
          flow_types: args[:flow_types].presence
        )
      end

      private

      def authorize!(subscription_target, namespace)
        return authorize_for_instance! if subscription_target == :instance

        raise_resource_not_available_error! unless namespace
        raise_resource_not_available_error! unless Ability.allowed?(current_user, :read_subscription_usage, namespace)

        return if namespace.root? && namespace.group_namespace?

        raise_resource_not_available_error!("Subscription usage can only be queried on a root namespace")
      end

      def authorize_for_instance!
        raise_resource_not_available_error! unless Ability.allowed?(current_user, :read_subscription_usage)
      end

      def validate_date_range!(start_date, end_date)
        if end_date < start_date
          raise Gitlab::Graphql::Errors::ArgumentError,
            "end_date must be after or equal to start_date"
        end

        return unless end_date > start_date + MAX_DATE_RANGE

        raise Gitlab::Graphql::Errors::ArgumentError,
          "Date range cannot exceed 1 year"
      end

      def find_namespace(namespace_path)
        return unless namespace_path

        Namespace.find_by_full_path(namespace_path)
      end

      def clamp_start_date(start_date, subscription_target, namespace)
        subscription_start =
          if subscription_target == :namespace
            namespace&.gitlab_subscription&.start_date
          else
            License.billable_license&.starts_at
          end

        return start_date unless subscription_start

        [start_date, subscription_start].max
      end
    end
  end
end
