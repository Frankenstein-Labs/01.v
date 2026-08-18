# frozen_string_literal: true

module SecretsManagement
  class DeprovisionProjectSecretsManagerWorker
    include ApplicationWorker

    data_consistency :sticky

    urgency :high

    idempotent!

    feature_category :secrets_management

    def perform(maintenance_task_id)
      task = ProjectSecretsManagerMaintenanceTask.find_by_id(maintenance_task_id)
      return unless task

      # `user_id` can be NULL for tasks created by the post-DELETE
      # trigger on `project_secrets_managers`, where no current_user is
      # available. Downstream code (BaseDeprovisionService +
      # GlobalSecretsManagerJwt) treats a nil user as a system context.
      user = task.user_id ? User.find_by_id(task.user_id) : nil

      ProjectSecretsManagers::DeprovisionService.new(task, user).execute
    end
  end
end
