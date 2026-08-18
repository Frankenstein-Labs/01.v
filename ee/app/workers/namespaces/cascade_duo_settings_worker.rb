# frozen_string_literal: true

module Namespaces
  class CascadeDuoSettingsWorker
    include ApplicationWorker

    feature_category :ai_abstraction_layer

    idempotent!
    deduplicate :until_executed, if_deduplicated: :reschedule_once
    urgency :low
    data_consistency :delayed
    loggable_arguments 0
    worker_resource_boundary :memory
    defer_on_database_health_signal :gitlab_main,
      [:namespace_settings, :project_settings, :namespaces, :projects], 1.minute

    def perform(group_id, setting_attributes, user_id = nil)
      group = Group.find_by_id(group_id)
      user = user_id ? User.find_by_id(user_id) : nil
      ::Ai::CascadeDuoSettingsService.new(setting_attributes, current_user: user).cascade_for_group(group)
    end
  end
end
