# frozen_string_literal: true

module EE
  module WebHooks
    module AdminDestroyService
      extend ::Gitlab::Utils::Override

      private

      override :log_audit_event
      def log_audit_event(web_hook)
        audit_context = {
          name: "webhook_destroyed",
          author: ::Gitlab::Audit::UnauthenticatedAuthor.new(name: '(System)'),
          scope: web_hook.parent || ::Gitlab::Audit::InstanceScope.new,
          target: web_hook,
          message: "Deleted #{web_hook.model_name.human.downcase} via rake task (#{rake_task.name})",
          target_details: "Hook #{web_hook.id}"
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end
    end
  end
end
