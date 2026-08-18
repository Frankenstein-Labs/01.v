# frozen_string_literal: true

module GitlabSubscriptions
  module Members
    class AddedWorker
      include Gitlab::EventStore::Subscriber

      feature_category :seat_cost_management
      data_consistency :sticky
      urgency :low

      idempotent!
      deduplicate :until_executed

      def handle_event(event)
        source = event.data[:source_type].constantize.find_by_id(event.data[:source_id])
        invited_user_ids = event.data[:invited_user_ids]

        return unless source && invited_user_ids.present?

        GitlabSubscriptions::Members::AddedService.new(source, invited_user_ids.compact).execute
      end
    end
  end
end
