# frozen_string_literal: true

module EE
  module Organizations
    module Transfer
      module TopLevelGroupService
        extend ::Gitlab::Utils::Override

        override :execute
        def execute
          result = super

          log_audit_events if result.success?

          result
        end

        private

        def log_audit_events
          groups.each do |group|
            log_audit_event(group)
          end
        end

        def log_audit_event(group)
          audit_context = {
            name: 'group_transferred_to_organization',
            author: current_user,
            scope: group,
            target: new_organization,
            message: "Transferred group to organization #{new_organization.name}"
          }

          ::Gitlab::Audit::Auditor.audit(audit_context)
        end
      end
    end
  end
end
