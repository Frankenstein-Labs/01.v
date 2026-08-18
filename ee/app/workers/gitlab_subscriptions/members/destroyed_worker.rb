# frozen_string_literal: true

module GitlabSubscriptions
  module Members
    class DestroyedWorker
      include Gitlab::EventStore::Subscriber

      data_consistency :delayed
      feature_category :seat_cost_management
      urgency :low
      idempotent!
      deduplicate :until_executed

      def handle_event(event)
        return unless ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)

        user = ::User.find_by_id(event.data[:user_id])
        namespace = ::Namespace.find_by_id(event.data[:root_namespace_id])

        return unless user && namespace&.group_namespace?

        seat = GitlabSubscriptions::SeatAssignment.find_by_namespace_and_user(namespace, user)

        return unless seat

        seat_type = ::GitlabSubscriptions::SeatTypeCalculator.execute(user, namespace)

        if seat_type
          seat.update!(seat_type: seat_type)
        else
          seat.destroy!
        end
      end
    end
  end
end
