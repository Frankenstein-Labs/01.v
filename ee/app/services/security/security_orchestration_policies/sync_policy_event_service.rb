# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class SyncPolicyEventService < BaseProjectPolicyService
      def initialize(project:, security_policy:, event:)
        super(project: project, security_policy: security_policy)
        @event = event
      end

      def execute
        if policy_disabled_or_scope_inapplicable?
          unlink_policy
        else
          case event
          when Projects::ComplianceFrameworkChangedEvent,
            ::Repositories::ProtectedBranchCreatedEvent,
            ::Repositories::ProtectedBranchDestroyedEvent,
            ::Repositories::DefaultBranchChangedEvent
            converge_policy
          when Projects::SecurityAttributeChangedEvent
            sync_policy_for_security_attribute(event)
          when Security::PolicyResyncEvent
            resync_policy
          end
        end
      end

      private

      def resync_policy
        unlink_policy(skip_delete_worker: true)
        link_policy
      end

      def converge_policy
        link_policy
        sync_approval_policy_rules
      end

      def sync_policy_for_security_attribute(event)
        unless security_policy.policy_scope.references_any_security_attribute?(event.data[:security_attribute_id])
          return
        end

        if scope_applicable?
          link_policy
        else
          unlink_policy
        end
      end

      attr_reader :event
    end
  end
end
