# frozen_string_literal: true

module GitlabSubscriptions
  module GitlabCom
    class DuoCoreTodoNotificationWorker
      include ApplicationWorker

      deduplicate :until_executed
      data_consistency :delayed
      idempotent!

      feature_category :acquisition

      def perform(namespace_id)
        namespace = Namespace.find_by_id(namespace_id)

        return unless namespace&.duo_core_features_enabled?

        todo_service = TodoService.new

        # This is inline with how the group settings area filters eligible users for other types of duo on the
        # seat utilization page.
        users = GitlabSubscriptions::AddOnEligibleUsersFinder.new(namespace, add_on_type: :duo_core).execute

        users.find_in_batches do |batch|
          todo_service.duo_core_access_granted(batch)
        end
      end
    end
  end
end
