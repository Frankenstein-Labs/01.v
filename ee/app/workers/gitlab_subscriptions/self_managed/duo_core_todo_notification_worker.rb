# frozen_string_literal: true

module GitlabSubscriptions
  module SelfManaged
    class DuoCoreTodoNotificationWorker
      include ApplicationWorker

      deduplicate :until_executed
      data_consistency :delayed
      idempotent!

      feature_category :acquisition

      def perform(organization_id = nil)
        # TODO: Remove the fallback after 19.3 when jobs enqueued without an organization ID have drained.
        # See https://gitlab.com/gitlab-org/gitlab/-/issues/606066.
        organization =
          if organization_id
            ::Organizations::Organization.find_by_id(organization_id)
          else
            ::Organizations::Organization.default_organization # rubocop:disable Gitlab/AvoidDefaultOrganization -- Compatibility for jobs enqueued before organization IDs were added
          end

        return unless organization
        return unless ::Ai::Setting.duo_core_features_enabled?(organization)

        todo_service = TodoService.new

        # This is inline with how the admin area filters eligible users for other types of duo on the
        # seat utilization page.
        users = GitlabSubscriptions::SelfManaged::AddOnEligibleUsersFinder.new(add_on_type: :duo_core).execute

        users.find_in_batches do |batch|
          # Short circuit this potentially long-running job if the setting is changed
          break unless ::Ai::Setting.duo_core_features_enabled_uncached?(organization)

          todo_service.duo_core_access_granted(batch)
        end
      end
    end
  end
end
